// notification_service.dart
// Handles all push notifications in the app.
// Uses flutter_local_notifications — 100% on-device.
// No server, no Firebase, no cost, no internet needed.
// Works even in airplane mode.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:monitor_bot/core/constants.dart';

class NotificationService {
  // ─────────────────────────────────────────
  // SINGLETON
  // ─────────────────────────────────────────
  static final NotificationService _instance =
  NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // The main notifications plugin object
  final _plugin = FlutterLocalNotificationsPlugin();

  // Tracks whether we've initialized already
  bool _initialized = false;

  // ─────────────────────────────────────────
  // NOTIFICATION CHANNELS
  // Android groups notifications into "channels".
  // Each channel has its own sound/vibration settings.
  // Users can disable specific channels in phone settings.
  // We create two channels:
  // 1. Alerts — high priority, for condition-met alerts
  // 2. Status — low priority, for background service status
  // ─────────────────────────────────────────
  static const String _alertChannelId = 'monitor_alerts';
  static const String _alertChannelName = 'Monitor Alerts';
  static const String _alertChannelDesc =
      'Notifications when a monitored condition is met';

  static const String _statusChannelId = 'monitor_status';
  static const String _statusChannelName = 'Monitor Status';
  static const String _statusChannelDesc =
      'Background monitoring status notifications';

  // Notification IDs
  // Each notification needs a unique integer ID
  // We use these constants so we can update/cancel
  // specific notifications later
  static const int _backgroundServiceNotifId = 1;
  // Alert notifications start from ID 1000
  // and increment from there
  int _nextAlertId = 1000;

  // ─────────────────────────────────────────
  // INITIALIZE
  // Must be called once when the app starts.
  // Sets up Android channels and iOS permissions.
  // ─────────────────────────────────────────
  Future<void> init() async {
    // Only initialize once
    if (_initialized) return;

    // ── Android settings ──
    // The icon shown in the notification bar.
    // '@mipmap/ic_launcher' uses your app icon.
    // For a custom icon, add it to android/app/src/main/res/drawable/
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ── iOS settings ──
    // requestAlertPermission: show the notification text
    // requestBadgePermission: show number badge on app icon
    // requestSoundPermission: play notification sound
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine platform settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _plugin.initialize(
      initSettings,
      // Called when user TAPS a notification
      // Use this to navigate to the right screen
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    await _createChannels();

    _initialized = true;
  }

  // ─────────────────────────────────────────
  // CREATE ANDROID CHANNELS
  // Channels must be created before any
  // notification can be shown on Android 8+.
  // ─────────────────────────────────────────
  Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation
    AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // ── Alert channel — HIGH IMPORTANCE ──
    // High importance = makes sound + pops up on screen
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: _alertChannelDesc,
        // High importance = heads-up notification
        // (pops up even when phone is in use)
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        // LED light flashes on supported phones
        enableLights: true,
        ledColor: Color(0xFF6C63FF), // Our brand purple
      ),
    );

    // ── Status channel — LOW IMPORTANCE ──
    // Low importance = silent, just shows in notification tray
    // Used for the "Monitor Bot is running" persistent notification
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _statusChannelId,
        _statusChannelName,
        description: _statusChannelDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  // ─────────────────────────────────────────
  // REQUEST PERMISSIONS
  // On Android 13+ and iOS, we must explicitly
  // ask the user for notification permission.
  // Shows a system dialog asking "Allow notifications?"
  // ─────────────────────────────────────────
  Future<bool> requestPermissions() async {
    // ── Android 13+ ──
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation
    AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted =
          await androidPlugin.requestNotificationsPermission() ?? false;
      return granted;
    }

    // ── iOS ──
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation
    IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ??
          false;
      return granted;
    }

    return true;
  }

  // ─────────────────────────────────────────
  // SHOW ALERT NOTIFICATION
  // Called when a monitor condition is met.
  // This is the important one — high priority,
  // makes sound, pops up on screen.
  //
  // Parameters:
  // - monitorName: e.g. "Amazon Backpack"
  // - message: e.g. "Price dropped to ₹1,299!"
  // - monitorId: used so tapping notification
  //   opens the right monitor detail screen
  // ─────────────────────────────────────────
  Future<void> showAlertNotification({
    required String monitorName,
    required String message,
    required String monitorId,
  }) async {
    if (!_initialized) await init();

    // Android-specific notification details
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: _alertChannelDesc,
      importance: Importance.high,
      priority: Priority.high,

      // Heads-up notification — pops up even when
      // user is using another app
      fullScreenIntent: false,

      // Show notification even when Do Not Disturb is on
      // (only for truly important alerts)
      category: AndroidNotificationCategory.alarm,

      // Icon shown in notification
      icon: '@mipmap/ic_launcher',

      // Color of the notification icon
      color: Color(0xFF6C63FF),

      // Keep notification visible until user dismisses it
      autoCancel: true,

      // Show timestamp on notification
      when: null,
      showWhen: true,

      // Style for long messages — shows full text
      styleInformation: BigTextStyleInformation(''),
    );

    // iOS-specific notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Increment badge count on app icon
      badgeNumber: 1,
    );

    final details = const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Each alert gets a unique ID so multiple
    // alerts can stack in the notification tray
    final notifId = _nextAlertId++;

    await _plugin.show(
      notifId,
      // Title: "🔔 Amazon Backpack"
      '🔔 $monitorName',
      // Body: the actual alert message
      message,
      details,
      // Payload is passed to _onNotificationTapped
      // when the user taps the notification.
      // We store the monitorId so we can navigate
      // to the right screen.
      payload: monitorId,
    );
  }

  // ─────────────────────────────────────────
  // SHOW BACKGROUND SERVICE NOTIFICATION
  // Android requires a persistent notification
  // while a foreground service is running.
  // This is the "Monitor Bot is running" notification
  // that stays in the notification tray.
  // It's low priority so it doesn't bother the user.
  // ─────────────────────────────────────────
  Future<void> showBackgroundServiceNotification({
    required int activeMonitors,
    String? lastCheckTime,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _statusChannelId,
      _statusChannelName,
      channelDescription: _statusChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,       // Can't be dismissed by swipe — stays persistent
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF6C63FF),
      // Show in notification tray but not as heads-up
      silent: true,
    );

    final details = NotificationDetails(android: androidDetails);

    final subtitle = lastCheckTime != null
        ? 'Last check: $lastCheckTime'
        : 'Watching for changes...';

    await _plugin.show(
      _backgroundServiceNotifId,
      'Monitor Bot is running',
      '$activeMonitors monitor${activeMonitors == 1 ? '' : 's'} active · $subtitle',
      details,
    );
  }

  // ─────────────────────────────────────────
  // SHOW USAGE WARNING NOTIFICATION
  // Fires when user is approaching their
  // daily free tier limit.
  // ─────────────────────────────────────────
  Future<void> showUsageWarning({
    required AiProvider provider,
    required int usedRequests,
    required int limitRequests,
  }) async {
    if (!_initialized) await init();

    final providerName =
    kProviderInfo[provider]!['name'] as String;
    final percent =
    ((usedRequests / limitRequests) * 100).round();

    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFF59E0B), // Amber warning color
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      999, // Fixed ID so warning doesn't stack — updates in place
      '⚠️ Approaching API limit',
      '$providerName: $usedRequests/$limitRequests requests used today ($percent%)',
      details,
    );
  }

  // ─────────────────────────────────────────
  // CANCEL NOTIFICATIONS
  // ─────────────────────────────────────────

  // Cancel the background service notification
  // Called when monitoring is stopped
  Future<void> cancelBackgroundNotification() async {
    await _plugin.cancel(_backgroundServiceNotifId);
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─────────────────────────────────────────
  // ON NOTIFICATION TAPPED
  // Called when user taps a notification.
  // The payload contains the monitorId.
  // We use this to navigate to the right screen.
  //
  // Navigation from here is tricky because we're
  // outside the widget tree — we use a global
  // navigator key for this (set up in main.dart).
  // ─────────────────────────────────────────
  void _onNotificationTapped(NotificationResponse response) {
    final monitorId = response.payload;
    if (monitorId == null) return;

    // We'll connect this to go_router navigation in main.dart
    // For now we store the pending navigation
    _pendingMonitorId = monitorId;
  }

  // Stores a monitorId to navigate to after app opens
  String? _pendingMonitorId;

  // Called from main.dart after app is ready
  // Returns the pending monitorId if any
  String? consumePendingNavigation() {
    final id = _pendingMonitorId;
    _pendingMonitorId = null;
    return id;
  }
}