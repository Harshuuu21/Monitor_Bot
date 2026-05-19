// notification_service.dart
// Fixed version — all generic calls on single lines

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:monitor_bot/core/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _alertChannelId = 'monitor_alerts';
  static const String _alertChannelName = 'Monitor Alerts';
  static const String _statusChannelId = 'monitor_status';
  static const String _statusChannelName = 'Monitor Status';
  static const int _bgNotifId = 1;
  int _nextAlertId = 1000;
  String? _pendingMonitorId;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings, onDidReceiveNotificationResponse: _onTapped);
    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _alertChannelId, _alertChannelName,
      description: 'Notifications when a monitored condition is met',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _statusChannelId, _statusChannelName,
      description: 'Background monitoring status',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ));
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return true;
  }

  Future<void> showAlertNotification({
    required String monitorName,
    required String message,
    required String monitorId,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId, _alertChannelName,
      channelDescription: 'Notifications when a monitored condition is met',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
    await _plugin.show(_nextAlertId++, '🔔 $monitorName', message, details, payload: monitorId);
  }

  Future<void> showBackgroundServiceNotification({
    required int activeMonitors,
    String? lastCheckTime,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      _statusChannelId, _statusChannelName,
      channelDescription: 'Background monitoring status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      silent: true,
    );
    const details = NotificationDetails(android: androidDetails);
    final subtitle = lastCheckTime ?? 'Watching for changes...';
    await _plugin.show(
      _bgNotifId,
      'Monitor Bot is running',
      '$activeMonitors monitor${activeMonitors == 1 ? '' : 's'} active · $subtitle',
      details,
    );
  }

  Future<void> showUsageWarning({
    required AiProvider provider,
    required int usedRequests,
    required int limitRequests,
  }) async {
    if (!_initialized) await init();
    final providerName = kProviderInfo[provider]!['name'] as String;
    final percent = ((usedRequests / limitRequests) * 100).round();
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId, _alertChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(999, '⚠️ Approaching API limit',
        '$providerName: $usedRequests/$limitRequests requests today ($percent%)', details);
  }

  Future<void> cancelBackgroundNotification() async => _plugin.cancel(_bgNotifId);
  Future<void> cancelAll() async => _plugin.cancelAll();

  void _onTapped(NotificationResponse response) {
    _pendingMonitorId = response.payload;
  }

  String? consumePendingNavigation() {
    final id = _pendingMonitorId;
    _pendingMonitorId = null;
    return id;
  }
}