// background_service.dart
// The heart of the entire app.
// Runs 24/7 even when app is closed.
// Every X minutes it:
// 1. Loads all active monitors from database
// 2. For each monitor — loads the webpage
// 3. Sends page content to AI
// 4. Checks if condition is met
// 5. Fires notification if yes
// 6. Updates usage stats
// 7. Warns user if approaching free tier limit

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/models/alert.dart';
import 'package:monitor_bot/models/monitor_task.dart';
import 'package:monitor_bot/services/ai_service.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/services/notification_service.dart';
import 'package:monitor_bot/services/storage_service.dart';

class BackgroundService {
  // ─────────────────────────────────────────
  // SINGLETON
  // ─────────────────────────────────────────
  static final BackgroundService _instance =
  BackgroundService._internal();

  factory BackgroundService() => _instance;

  BackgroundService._internal();

  // The flutter_background_service plugin instance
  final _service = FlutterBackgroundService();

  // Our other services — used inside the background loop
  final _storage = StorageService();
  final _aiService = AiService();
  final _notifService = NotificationService();
  final _keyService = KeyService();

  // ─────────────────────────────────────────
  // INITIALIZE
  // ─────────────────────────────────────────
  Future<void> init() async {
    await _service.configure(
      // ── Android configuration ──
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundStart,

        autoStart: true,

        isForegroundMode: true,

        notificationChannelId: 'monitor_status',
        initialNotificationTitle: 'Monitor Bot',
        initialNotificationContent: 'Starting monitors...',
        foregroundServiceNotificationId: 1,

        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),

      // ── iOS configuration ──
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onBackgroundStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  // ─────────────────────────────────────────
  // START MONITORING
  // ─────────────────────────────────────────
  Future<void> startMonitoring() async {
    final isRunning = await _service.isRunning();

    if (!isRunning) {
      await _service.startService();
    }
  }

  // ─────────────────────────────────────────
  // STOP MONITORING
  // ─────────────────────────────────────────
  Future<void> stopMonitoring() async {
    final isRunning = await _service.isRunning();

    if (isRunning) {
      _service.invoke('stop');
    }

    await _notifService.cancelBackgroundNotification();
  }

  // ─────────────────────────────────────────
  // IS RUNNING
  // ─────────────────────────────────────────
  Future<bool> isRunning() => _service.isRunning();
}

// ─────────────────────────────────────────
// BACKGROUND START — TOP LEVEL FUNCTION
// ─────────────────────────────────────────
@pragma('vm:entry-point')
void _onBackgroundStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all services in the background isolate
  final storage = StorageService();
  final aiService = AiService();
  final notifService = NotificationService();
  final keyService = KeyService();

  await storage.init();
  await notifService.init();

  // ServiceInstance doesn't have isRunning()
  // we use a flag instead
  bool _keepRunning = true;

  // Listen for stop command from main isolate
  service.on('stop').listen((_) {
    _keepRunning = false;
    service.stopSelf();
  });

  // ── MAIN MONITORING LOOP ──
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    if (!_keepRunning) {
      timer.cancel();
      return;
    }

    await _runMonitoringCycle(
      storage: storage,
      aiService: aiService,
      notifService: notifService,
      keyService: keyService,
      service: service,
    );
  });

  // Run immediately on start
  await _runMonitoringCycle(
    storage: storage,
    aiService: aiService,
    notifService: notifService,
    keyService: keyService,
    service: service,
  );
}

// ─────────────────────────────────────────
// iOS BACKGROUND HANDLER
// ─────────────────────────────────────────
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// ─────────────────────────────────────────
// RUN MONITORING CYCLE
// ─────────────────────────────────────────
Future<void> _runMonitoringCycle({
  required StorageService storage,
  required AiService aiService,
  required NotificationService notifService,
  required KeyService keyService,
  required ServiceInstance service,
}) async {
  try {
    // Get all active monitors from database
    final monitors = await storage.getActiveMonitors();

    if (monitors.isEmpty) return;

    // Update the persistent notification
    await notifService.showBackgroundServiceNotification(
      activeMonitors: monitors.length,
    );

    // Check usage limits before running
    final selectedProvider = await keyService.getSelectedProvider();

    await _checkUsageWarning(
      storage: storage,
      notifService: notifService,
      provider: selectedProvider,
    );

    // ── Process each monitor ──
    for (final monitor in monitors) {
      if (!_isDueForCheck(monitor)) continue;

      await _checkMonitor(
        monitor: monitor,
        storage: storage,
        aiService: aiService,
        notifService: notifService,
        keyService: keyService,
      );

      await Future.delayed(const Duration(seconds: 2));
    }
  } catch (e) {
    debugPrint('Background cycle error: $e');
  }
}

// ─────────────────────────────────────────
// IS DUE FOR CHECK
// ─────────────────────────────────────────
bool _isDueForCheck(MonitorTask monitor) {
  if (monitor.lastChecked == null) return true;

  final now = DateTime.now();

  final nextCheckDue = monitor.lastChecked!.add(
    Duration(minutes: monitor.intervalMinutes),
  );

  return now.isAfter(nextCheckDue);
}

// ─────────────────────────────────────────
// CHECK MONITOR
// ─────────────────────────────────────────
Future<void> _checkMonitor({
  required MonitorTask monitor,
  required StorageService storage,
  required AiService aiService,
  required NotificationService notifService,
  required KeyService keyService,
}) async {
  try {
    // ── Step 1: Check usage limits ──
    final provider = monitor.provider;
    final info = kProviderInfo[provider]!;
    final freeLimit = info['freeLimit'] as int;

    if (freeLimit > 0) {
      final todayRequests = await storage.getTodayRequests(provider);

      if (todayRequests >= freeLimit) {
        await storage.updateMonitorStatus(
          monitor.id,
          MonitorStatus.limitHit,
        );
        return;
      }
    }

    // ── Step 2: Load the webpage ──
    final pageContent = await _fetchPageContent(monitor.url);

    if (pageContent == null) {
      await storage.updateMonitorStatus(
        monitor.id,
        MonitorStatus.error,
      );
      return;
    }

    // ── Step 3: Ask AI to check the condition ──
    final result = await aiService.checkCondition(
      provider: provider,
      pageContent: pageContent,
      condition: monitor.condition,
    );

    // ── Step 4: Update snapshot ──
    await storage.updateSnapshot(monitor.id, pageContent);

    if (result.hasError) {
      await storage.updateMonitorStatus(
        monitor.id,
        MonitorStatus.error,
      );
      return;
    }

    // Reset status if previously errored
    if (monitor.status == MonitorStatus.error) {
      await storage.updateMonitorStatus(
        monitor.id,
        MonitorStatus.active,
      );
    }

    // ── Step 5: Fire notification ──
    if (result.conditionMet) {
      final alertMessage =
          result.alertMessage ?? '${monitor.name}: Condition met!';

      await notifService.showAlertNotification(
        monitorName: monitor.name,
        message: alertMessage,
        monitorId: monitor.id,
      );

      final alert = Alert(
        id: '${monitor.id}_${DateTime.now().millisecondsSinceEpoch}',
        monitorId: monitor.id,
        monitorName: monitor.name,
        message: alertMessage,
        triggeredAt: DateTime.now(),
      );

      await storage.insertAlert(alert);
    }
  } catch (e) {
    debugPrint('Error checking monitor ${monitor.name}: $e');
  }
}

// ─────────────────────────────────────────
// FETCH PAGE CONTENT
// ─────────────────────────────────────────
Future<String?> _fetchPageContent(String url) async {
  try {
    final uri = Uri.parse(url);

    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('Page load failed: ${response.statusCode} for $url');
      return null;
    }

    final rawHtml = response.body;
    final cleanText = _extractTextFromHtml(rawHtml);

    if (cleanText.length > 8000) {
      return cleanText.substring(0, 8000);
    }

    return cleanText;
  } catch (e) {
    debugPrint('Failed to fetch $url: $e');
    return null;
  }
}

// ─────────────────────────────────────────
// EXTRACT TEXT FROM HTML
// ─────────────────────────────────────────
String _extractTextFromHtml(String html) {
  String text = html;

  text = text.replaceAll(
    RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
    ' ',
  );

  text = text.replaceAll(
    RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
    ' ',
  );

  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

  text = text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&rsquo;', "'")
      .replaceAll('&ldquo;', '"')
      .replaceAll('&rdquo;', '"');

  text = text.replaceAll(RegExp(r'\s+'), ' ');

  return text.trim();
}

// ─────────────────────────────────────────
// CHECK USAGE WARNING
// ─────────────────────────────────────────
Future<void> _checkUsageWarning({
  required StorageService storage,
  required NotificationService notifService,
  required AiProvider provider,
}) async {
  final info = kProviderInfo[provider]!;
  final freeLimit = info['freeLimit'] as int;

  if (freeLimit == 0) return;

  final todayRequests = await storage.getTodayRequests(provider);
  final usagePercent = todayRequests / freeLimit;

  // 80% warning threshold
  if (usagePercent >= AppLimits.warningThreshold &&
      usagePercent < AppLimits.pauseThreshold) {
    await notifService.showUsageWarning(
      provider: provider,
      usedRequests: todayRequests,
      limitRequests: freeLimit,
    );
  }

  // 100% — pause all active monitors
  if (usagePercent >= AppLimits.pauseThreshold) {
    final monitors = await storage.getActiveMonitors();

    for (final monitor in monitors) {
      if (monitor.provider == provider) {
        await storage.updateMonitorStatus(
          monitor.id,
          MonitorStatus.limitHit,
        );
      }
    }
  }
}