// quiz_screen.dart
// 2-question quiz that figures out which
// AI provider is best for the user.
// Question 1: Free or paid?
// Question 2: Simple or complex conditions?

import 'package:flutter/material.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Which question we're on (0 or 1)
  int _currentQuestion = 0;

  // User's answers
  // null = not answered yet
  bool? _wantsFree;
  bool? _wantsComplex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Custom back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_currentQuestion > 0) {
              setState(() => _currentQuestion--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress indicator ──
              // Shows which question user is on
              _ProgressBar(
                current: _currentQuestion + 1,
                total: 2,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Question ──
              AnimatedSwitcher(
                // Smooth transition between questions
                duration: const Duration(milliseconds: 300),
                child: _currentQuestion == 0
                    ? _buildQuestion1()
                    : _buildQuestion2(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Question 1: Free or paid? ──
  Widget _buildQuestion1() {
    return Column(
      key: const ValueKey('q1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Do you want to start\ncompletely free?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Google Gemini offers 1,500 free checks per day.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        _QuizOption(
          title: 'Yes, start for free',
          subtitle: 'Use Google Gemini — 1,500 checks/day at no cost',
          icon: Icons.celebration_outlined,
          badge: 'FREE',
          badgeColor: AppColors.success,
          selected: _wantsFree == true,
          onTap: () {
            setState(() {
              _wantsFree = true;
              _currentQuestion = 1;
            });
          },
        ),

        const SizedBox(height: AppSpacing.md),

        _QuizOption(
          title: 'I\'m okay with paying',
          subtitle: 'Unlock more powerful AI options (~₹1–5/month)',
          icon: Icons.diamond_outlined,
          badge: 'PREMIUM',
          badgeColor: AppColors.primary,
          selected: _wantsFree == false,
          onTap: () {
            setState(() {
              _wantsFree = false;
              _currentQuestion = 1;
            });
          },
        ),
      ],
    );
  }

  // ── Question 2: Simple or complex conditions? ──
  Widget _buildQuestion2() {
    return Column(
      key: const ValueKey('q2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How complex are your\nmonitoring conditions?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This helps us pick the right AI for your needs.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        _QuizOption(
          title: 'Simple conditions',
          subtitle:
          '"Notify me when price drops" or "alert me on new items"',
          icon: Icons.flash_on_outlined,
          badge: 'EASY',
          badgeColor: AppColors.info,
          selected: _wantsComplex == false,
          onTap: () {
            setState(() => _wantsComplex = false);
            _finishQuiz();
          },
        ),

        const SizedBox(height: AppSpacing.md),

        _QuizOption(
          title: 'Complex conditions',
          subtitle:
          '"Notify only if price drops AND rating stays above 4 stars AND official seller"',
          icon: Icons.psychology_outlined,
          badge: 'ADVANCED',
          badgeColor: AppColors.warning,
          selected: _wantsComplex == true,
          onTap: () {
            setState(() => _wantsComplex = true);
            _finishQuiz();
          },
        ),
      ],
    );
  }

  // Decide which provider to recommend
  // based on quiz answers and navigate there
  void _finishQuiz() {
    AiProvider recommended;

    if (_wantsFree == true) {
      // Free → always Gemini
      recommended = AiProvider.gemini;
    } else if (_wantsComplex == true) {
      // Paid + complex → Claude (best reasoning)
      recommended = AiProvider.claude;
    } else {
      // Paid + simple → OpenAI (most popular)
      recommended = AiProvider.openai;
    }

    // Small delay so user sees their selection
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.goProviderSelect(recommended: recommended);
      }
    });
  }
}

// ─────────────────────────────────────────
// PROGRESS BAR WIDGET
// ─────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question $current of $total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: current / total,
            backgroundColor: AppColors.surfaceLight,
            valueColor:
            const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// QUIZ OPTION CARD
// Tappable card for each quiz answer
// ─────────────────────────────────────────
class _QuizOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final bool selected;
  final VoidCallback onTap;

  const _QuizOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: AppTextStyles.cardTitle),
                      const SizedBox(width: AppSpacing.sm),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: AppTextStyles.badge.copyWith(
                              color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTextStyles.cardSubtitle),
                ],
              ),
            ),

            // Selected checkmark
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}