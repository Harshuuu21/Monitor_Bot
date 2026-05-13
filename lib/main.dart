// main.dart
// The entry point of the entire app.
// Flutter calls main() first — always.
// We use it to:
// 1. Initialize all services
// 2. Set up the theme
// 3. Connect the router
// 4. Hand control to Flutter's widget system

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';
import 'package:monitor_bot/services/background_service.dart';
import 'package:monitor_bot/services/notification_service.dart';
import 'package:monitor_bot/services/storage_service.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/providers/tasks_provider.dart';
import 'package:monitor_bot/providers/usage_provider.dart';
import 'package:monitor_bot/providers/settings_provider.dart';

// ─────────────────────────────────────────
// MAIN — APP ENTRY POINT
// The 'async' keyword means this function
// can do things that take time (like reading
// from storage) before the UI appears.
// ─────────────────────────────────────────
Future<void> main() async {
  // This MUST be called first in any Flutter app
  // that uses async code before runApp().
  // It initializes the Flutter engine binding
  // so plugins work correctly.
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lock screen orientation to portrait ──
  // Our app is designed for portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Set system UI style ──
  // Makes the status bar (time, battery, signal)
  // show light icons on our dark background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      navigationBarColor: Color(0xFF0F0F1A),
      navigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Initialize services ──
  // These must be ready before the UI loads
  // Order matters here — storage first,
  // then notification, then background service

  // 1. Database — must be first
  // Everything else depends on being able to read/write data
  await StorageService().init();

  // 2. Notifications — set up channels before background service
  await NotificationService().init();
  await NotificationService().requestPermissions();

  // 3. Background service — starts the monitoring loop
  await BackgroundService().init();

  // ── Launch the app ──
  runApp(const MonitorBotApp());
}

// ─────────────────────────────────────────
// MONITOR BOT APP — ROOT WIDGET
// This is the top-level widget of the entire app.
// Everything else is a child of this widget.
//
// What is a Widget?
// In Flutter, EVERYTHING is a widget.
// Widgets are building blocks — like LEGO pieces.
// You combine them to build screens.
//
// StatelessWidget = a widget that never changes.
// Our root app widget never changes — it just
// sets up the app shell. So it's StatelessWidget.
// ─────────────────────────────────────────
class MonitorBotApp extends StatelessWidget {
  const MonitorBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── MultiProvider ──
    // Provider is Flutter's state management solution.
    // It lets widgets share data without passing it
    // manually through every level of the widget tree.
    //
    // Think of providers as global data stores
    // that any widget can listen to and react to.
    //
    // MultiProvider lets us set up multiple providers
    // at once at the top of the widget tree.
    return MultiProvider(
      providers: [
        // TasksProvider — manages all monitor tasks
        // Any screen that needs the list of monitors
        // listens to this provider
        ChangeNotifierProvider(
          create: (_) => TasksProvider()..init(),
        ),

        // UsageProvider — manages API usage stats
        // The usage dashboard listens to this
        ChangeNotifierProvider(
          create: (_) => UsageProvider()..init(),
        ),

        // SettingsProvider — manages app settings
        // Theme, selected provider, etc.
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..init(),
        ),
      ],

      // ── MaterialApp.router ──
      // MaterialApp is Flutter's base app widget.
      // The '.router' version uses go_router for navigation.
      child: MaterialApp.router(
        // App title — shown in task switcher
        title: 'Monitor Bot',

        // Hide the DEBUG banner in top right corner
        debugShowCheckedModeBanner: false,

        // Connect our theme from theme.dart
        theme: AppTheme.darkTheme,

        // Connect our router from router.dart
        routerConfig: AppRouter.router,
      ),
    );
  }
}