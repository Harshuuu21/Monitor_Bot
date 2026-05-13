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
  // Sets up the background service configuration.
  // Called ONCE when the app first starts.
  // This tells Android/iOS how to run our
  // background process.
  // ─────────────────────────────────────────
  Future<void> init() async {
    await _service.configure(
      // ── Android configuration ──
      androidConfiguration: AndroidConfiguration(
        // onStart is the function that runs in the background
        // It MUST be a top-level function (not inside a class)
        // because Android runs it in a separate isolate
        // (an isolate is like a separate thread in Dart)
        onStart: _onBackgroundStart,

        // autoStart: true means start monitoring immediately
        // when the phone boots up
        autoStart: true,

        // isForegroundMode: true means run as a foreground service
        // This keeps Android from killing our process
        // Cost: must show a persistent notification
        isForegroundMode: true,

        // The notification channel for the persistent
        // "Monitor Bot is running" notification
        notificationChannelId: 'monitor_status',
        initialNotificationTitle: 'Monitor Bot',
        initialNotificationContent: 'Starting monitors...',
        foregroundServiceNotificationId: 1,

        // foregroundServiceType tells Android what kind
        // of work we're doing — dataSync is correct for
        // fetching and processing web data
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),

      // ── iOS configuration ──
      iosConfiguration: IosConfiguration(
        // autoStart on iOS
        autoStart: true,

        // onForeground: runs when app is open
        onForeground: _onBackgroundStart,

        // onBackground: runs when app is closed
        // iOS is more restrictive — this runs less frequently
        onBackground: _onIosBackground,
      ),
    );
  }

  // ─────────────────────────────────────────
  // START MONITORING
  // Called when user has set up monitors
  // and wants monitoring to begin.
  // ─────────────────────────────────────────
  Future<void> startMonitoring() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
  }

  // ─────────────────────────────────────────
  // STOP MONITORING
  // Called when user pauses all monitors
  // or from settings.
  // ─────────────────────────────────────────
  Future<void> stopMonitoring() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      // Send a stop event to the background isolate
      _service.invoke('stop');
    }
    await _notifService.cancelBackgroundNotification();
  }

  // ─────────────────────────────────────────
  // IS RUNNING
  // Returns true if background service is active
  // Used by UI to show running/stopped status
  // ─────────────────────────────────────────
  Future<bool> isRunning() => _service.isRunning();
}

// ─────────────────────────────────────────
// BACKGROUND START — TOP LEVEL FUNCTION
// This MUST be a top-level function (outside any class).
// Flutter's background service runs this in a
// separate Dart isolate — a completely isolated
// execution environment with its own memory.
//
// Think of it like a second mini-app running
// independently alongside your main app.
// It can't directly access your main app's state
// but it CAN use the same services (storage, AI, etc.)
// because those read/write to the same device storage.
// ─────────────────────────────────────────
@pragma('vm:entry-point')
void _onBackgroundStart(ServiceInstance service) async {
  // Required for background isolate to use Flutter plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all services in the background isolate
  // Each isolate needs its own service instances
  final storage = StorageService();
  final aiService = AiService();
  final notifService = NotificationService();
  final keyService = KeyService();

  await storage.init();
  await notifService.init();

  // Listen for stop command from main isolate
  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // ── MAIN MONITORING LOOP ──
  // This timer runs every 60 seconds.
  // Each tick it checks all active monitors
  // and runs any that are due for a check.
  //
  // Why 60 seconds and not the user's interval?
  // Because different monitors have different intervals.
  // One might check every 15 min, another every 2 hours.
  // We check every minute and run monitors that are DUE.
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    // If service was stopped, cancel the timer
    final isRunning = await service.isRunning();
    if (!isRunning) {
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

  // Run immediately on start — don't wait 60 seconds
  // for the first check
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
// iOS calls this periodically when app is closed.
// Must return true to keep the service alive.
// iOS gives us less control than Android —
// it decides when to call this, not us.
// ─────────────────────────────────────────
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true; // Return true = keep service alive
}

// ─────────────────────────────────────────
// RUN MONITORING CYCLE
// The actual monitoring logic.
// Called every 60 seconds by the timer.
// Goes through each active monitor and decides
// whether it's time to run a check.
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

    // Update the persistent notification with current count
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
      // Is it time to check this monitor?
      if (!_isDueForCheck(monitor)) continue;

      // Run the check for this monitor
      await _checkMonitor(
        monitor: monitor,
        storage: storage,
        aiService: aiService,
        notifService: notifService,
        keyService: keyService,
      );

      // Small delay between monitors to avoid
      // hammering the AI API with simultaneous requests
      await Future.delayed(const Duration(seconds: 2));
    }
  } catch (e) {
    // Never let the monitoring cycle crash —
    // log the error and continue
    debugPrint('Background cycle error: $e');
  }
}

// ─────────────────────────────────────────
// IS DUE FOR CHECK
// Decides whether a monitor should run now.
// Compares last check time + interval
// against current time.
//
// Example:
// Monitor interval = 30 minutes
// Last checked = 25 minutes ago → NOT due
// Last checked = 31 minutes ago → DUE ✓
// Never checked → DUE ✓
// ─────────────────────────────────────────
bool _isDueForCheck(MonitorTask monitor) {
  // Never been checked — run immediately
  if (monitor.lastChecked == null) return true;

  final now = DateTime.now();
  final nextCheckDue = monitor.lastChecked!.add(
    Duration(minutes: monitor.intervalMinutes),
  );

  // Is current time past the next due time?
  return now.isAfter(nextCheckDue);
}

// ─────────────────────────────────────────
// CHECK MONITOR
// The core function — runs one full check
// cycle for a single monitor:
// 1. Load the webpage
// 2. Extract page content
// 3. Send to AI
// 4. Check result
// 5. Fire notification if condition met
// 6. Save snapshot to database
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
    // Don't run if user has hit their free tier limit
    final provider = monitor.provider;
    final info = kProviderInfo[provider]!;
    final freeLimit = info['freeLimit'] as int;

    if (freeLimit > 0) {
      // This provider has a free tier
      final todayRequests = await storage.getTodayRequests(provider);
      if (todayRequests >= freeLimit) {
        // Hit the limit — pause this monitor
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
      // Page failed to load — mark error but keep monitor active
      // It will try again next cycle
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
      // screenshot: null for now
      // We'll add screenshot support in a future update
    );

    // ── Step 4: Update the snapshot in database ──
    // This records that we ran a check
    await storage.updateSnapshot(monitor.id, pageContent);

    // If there was an AI error, mark the monitor
    if (result.hasError) {
      await storage.updateMonitorStatus(
        monitor.id,
        MonitorStatus.error,
      );
      return;
    }

    // Reset status to active if it was previously errored
    if (monitor.status == MonitorStatus.error) {
      await storage.updateMonitorStatus(
        monitor.id,
        MonitorStatus.active,
      );
    }

    // ── Step 5: Fire notification if condition met ──
    if (result.conditionMet) {
      final alertMessage =
          result.alertMessage ?? '${monitor.name}: Condition met!';

      // Show push notification
      await notifService.showAlertNotification(
        monitorName: monitor.name,
        message: alertMessage,
        monitorId: monitor.id,
      );

      // Save alert to database
      // so it shows up in the alerts history screen
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
    // Log error but don't crash the whole cycle
    debugPrint('Error checking monitor ${monitor.name}: $e');
  }
}

// ─────────────────────────────────────────
// FETCH PAGE CONTENT
// Loads a webpage and extracts its text content.
// We use a simple HTTP GET request here.
//
// Why not use WebView?
// WebView needs a UI context — it can't run in
// a background isolate without a screen attached.
// For most pages, a direct HTTP request works fine.
// JavaScript-heavy pages (like SPAs) need extra handling
// which we flag for future enhancement.
//
// Returns the page text, or null if it failed.
// ─────────────────────────────────────────
Future<String?> _fetchPageContent(String url) async {
  try {
    final uri = Uri.parse(url);

    // Make HTTP GET request with browser-like headers
    // Some sites block requests without a User-Agent
    final response = await http.get(
      uri,
      headers: {
        // Pretend to be a real browser
        // This helps with sites that block bots
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

    // Extract readable text from HTML
    // Remove all HTML tags to get clean text
    final rawHtml = response.body;
    final cleanText = _extractTextFromHtml(rawHtml);

    // Limit to 8000 characters — AI context window limit
    // Most important content is in the first 8000 chars
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
// Removes HTML tags to get clean readable text.
// We use regex (pattern matching) to strip tags.
//
// Example:
// Input:  <h1>Price: <span class="price">₹1,299</span></h1>
// Output: Price: ₹1,299
// ─────────────────────────────────────────
String _extractTextFromHtml(String html) {
  String text = html;

  // Remove script tags and their content entirely
  // (JavaScript code is not useful for AI reading)
  text = text.replaceAll(
    RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
    ' ',
  );

  // Remove style tags and their content
  text = text.replaceAll(
    RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
    ' ',
  );

  // Remove all remaining HTML tags
  // e.g. <div class="price"> → (removed)
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

  // Decode common HTML entities
  // &amp; → & , &lt; → < , &gt; → > , etc.
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

  // Collapse multiple whitespace/newlines into single spaces
  text = text.replaceAll(RegExp(r'\s+'), ' ');

  return text.trim();
}

// ─────────────────────────────────────────
// CHECK USAGE WARNING
// Checks if user is approaching their free tier limit.
// If 80%+ used → fires a warning notification.
// If 100% used → pauses all monitors.
// ─────────────────────────────────────────
Future<void> _checkUsageWarning({
  required StorageService storage,
  required NotificationService notifService,
  required AiProvider provider,
}) async {
  final info = kProviderInfo[provider]!;
  final freeLimit = info['freeLimit'] as int;

  // Only check for providers with a free tier
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