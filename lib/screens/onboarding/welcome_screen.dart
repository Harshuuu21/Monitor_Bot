// welcome_screen.dart
// First screen new users see.
// Sets the tone for the whole app —
// clean, trustworthy, no pressure.

import 'package:flutter/material.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for the fade-in effect
  // when screen first appears
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade from 0 (invisible) to 1 (fully visible)
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Slide from slightly below to normal position
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));

    // Start animation when screen loads
    _controller.forward();
  }

  @override
  void dispose() {
    // Always dispose animation controllers
    // to free up memory
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea ensures content doesn't go behind
      // the camera notch or system navigation bar
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // ── App icon / logo ──
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Headline ──
                  Text(
                    AppStrings.welcomeTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Subtitle ──
                  Text(
                    AppStrings.welcomeSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Feature bullets ──
                  _FeatureBullet(
                    icon: Icons.notifications_active_outlined,
                    text: 'Get notified the moment prices drop',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FeatureBullet(
                    icon: Icons.all_inclusive,
                    text: 'Monitor unlimited websites simultaneously',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FeatureBullet(
                    icon: Icons.lock_outline,
                    text: 'Your data stays on your device only',
                  ),

                  const Spacer(flex: 3),

                  // ── Start Free button ──
                  // Routes to quiz → Gemini (free tier)
                  ElevatedButton(
                    onPressed: () => context.goQuiz(),
                    child: const Text('Get started — it\'s free'),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Already have a key button ──
                  // Routes directly to provider selection
                  OutlinedButton(
                    onPressed: () => context.goProviderSelect(),
                    child: const Text('I already have an API key'),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Privacy note ──
                  Center(
                    child: Text(
                      'No account needed · No data collected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// FEATURE BULLET WIDGET
// Reusable row with icon + text
// Used to show the 3 key features
// ─────────────────────────────────────────
class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}