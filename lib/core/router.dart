// router.dart
// Controls all navigation in the app.
// Every screen, every route, every redirect lives here.
// Uses go_router — Flutter's official navigation package.
//
// How navigation works in this app:
// - User opens app for first time → welcome screen
// - User has completed onboarding → home dashboard
// - User taps a notification → monitor detail screen
// - User taps back → previous screen
//
// To navigate from any screen:
// context.go('/home')          — go to home, clear history
// context.push('/add-monitor') — push on top, can go back

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/screens/onboarding/welcome_screen.dart';
import 'package:monitor_bot/screens/onboarding/quiz_screen.dart';
import 'package:monitor_bot/screens/onboarding/provider_screen.dart';
import 'package:monitor_bot/screens/onboarding/key_setup_screen.dart';
import 'package:monitor_bot/screens/dashboard/home_screen.dart';
import 'package:monitor_bot/screens/dashboard/alerts_screen.dart';
import 'package:monitor_bot/screens/dashboard/usage_screen.dart';
import 'package:monitor_bot/screens/monitor/add_monitor_screen.dart';
import 'package:monitor_bot/screens/monitor/monitor_detail_screen.dart';
import 'package:monitor_bot/screens/settings/settings_screen.dart';

// ─────────────────────────────────────────
// GLOBAL NAVIGATOR KEY
// This gives us access to the navigator
// from ANYWHERE in the app — even from
// background services and notification handlers
// that don't have a BuildContext.
//
// We use this in notification_service.dart
// to navigate when user taps a notification.
// ─────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// ─────────────────────────────────────────
// APP ROUTER
// The main router configuration.
// Call AppRouter.router and pass it to MaterialApp.
// ─────────────────────────────────────────
class AppRouter {
  // Private constructor — use AppRouter.router directly
  AppRouter._();

  // The key service used for onboarding check
  static final _keyService = KeyService();

  // ─────────────────────────────────────────
  // THE ROUTER
  // This is what you pass to MaterialApp.router()
  // It defines all routes and redirect logic.
  // ─────────────────────────────────────────
  static final router = GoRouter(
    // The global navigator key — enables navigation
    // from outside the widget tree
    navigatorKey: navigatorKey,

    // Where the app starts
    initialLocation: AppRoutes.welcome,

    // Redirect logic — runs before EVERY navigation
    // This is where we check onboarding status
    redirect: (BuildContext context, GoRouterState state) async {
      final currentPath = state.matchedLocation;

      // Check if user has completed onboarding
      final onboardingDone = await _keyService.isOnboardingDone();

      // ── Onboarding not done ──
      // If user hasn't finished setup and tries to
      // access the main app → send them to welcome
      if (!onboardingDone) {
        // Allow onboarding screens to load normally
        final isOnboardingRoute = currentPath == AppRoutes.welcome ||
            currentPath == AppRoutes.quiz ||
            currentPath == AppRoutes.providerSelect ||
            currentPath.startsWith('/key-setup');

        if (!isOnboardingRoute) {
          return AppRoutes.welcome;
        }
        return null; // No redirect — load the requested route
      }

      // ── Onboarding done ──
      // If user tries to access onboarding screens
      // after already completing setup → send to home
      if (onboardingDone && currentPath == AppRoutes.welcome) {
        return AppRoutes.home;
      }

      return null; // No redirect needed
    },

    // ─────────────────────────────────────────
    // ROUTES
    // Each GoRoute defines one screen.
    // 'path' is the URL-like identifier.
    // 'builder' returns the screen widget.
    // ─────────────────────────────────────────
    routes: [
      // ── ONBOARDING ROUTES ──

      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      GoRoute(
        path: AppRoutes.quiz,
        builder: (context, state) => const QuizScreen(),
      ),

      GoRoute(
        path: AppRoutes.providerSelect,
        // 'extra' passes data between screens
        // Here we pass which providers the quiz recommended
        builder: (context, state) {
          final recommended =
              state.extra as AiProvider? ?? AiProvider.gemini;
          return ProviderScreen(recommended: recommended);
        },
      ),

      GoRoute(
        path: AppRoutes.keySetup,
        builder: (context, state) {
          // Which provider's key setup to show
          final provider =
              state.extra as AiProvider? ?? AiProvider.gemini;
          return KeySetupScreen(provider: provider);
        },
      ),

      // ── MAIN APP ROUTES ──

      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: AppRoutes.addMonitor,
        // pageBuilder gives us control over the
        // transition animation
        pageBuilder: (context, state) => CustomTransitionPage(
          // Slide up from bottom — feels like a modal
          transitionsBuilder: (context, animation, secondary, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1), // Start off-screen below
                end: Offset.zero,          // End at normal position
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
          child: const AddMonitorScreen(),
        ),
      ),

      GoRoute(
        path: '${AppRoutes.monitorDetail}/:id',
        builder: (context, state) {
          // Extract the monitor ID from the URL
          // e.g. /monitor-detail/abc123 → id = 'abc123'
          final id = state.pathParameters['id']!;
          return MonitorDetailScreen(monitorId: id);
        },
      ),

      GoRoute(
        path: AppRoutes.alerts,
        builder: (context, state) => const AlertsScreen(),
      ),

      GoRoute(
        path: AppRoutes.usage,
        builder: (context, state) => const UsageScreen(),
      ),

      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // ─────────────────────────────────────────
    // ERROR PAGE
    // Shown if user navigates to a route that
    // doesn't exist. Rarely happens but good to handle.
    // ─────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFF6C63FF),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Unknown error',
              style: const TextStyle(color: Color(0xFFB0B0C8)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text(
                'Go home',
                style: TextStyle(color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────
// NAVIGATION HELPERS
// Extension methods on BuildContext.
// Instead of writing GoRouter.of(context).go('/home')
// you can write context.go('/home') — much cleaner.
// These are already provided by go_router itself
// but we add our own named helpers here for
// the most common navigation actions in our app.
// ─────────────────────────────────────────
extension AppNavigation on BuildContext {
  // Go to home, clear all history
  void goHome() => go(AppRoutes.home);

  // Open add monitor screen (slides up)
  void goAddMonitor() => push(AppRoutes.addMonitor);

  // Open a specific monitor's detail screen
  void goMonitorDetail(String monitorId) =>
      push('${AppRoutes.monitorDetail}/$monitorId');

  // Open alerts screen
  void goAlerts() => push(AppRoutes.alerts);

  // Open usage dashboard
  void goUsage() => push(AppRoutes.usage);

  // Open settings
  void goSettings() => push(AppRoutes.settings);

  // Move to next onboarding step
  void goQuiz() => go(AppRoutes.quiz);

  void goProviderSelect({AiProvider? recommended}) =>
      go(AppRoutes.providerSelect, extra: recommended);

  void goKeySetup(AiProvider provider) =>
      go(AppRoutes.keySetup, extra: provider);
}