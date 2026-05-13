// provider_screen.dart
// Shows all three AI providers as cards.
// Highlights the recommended one from the quiz.
// User picks one and taps Continue.

import 'package:flutter/material.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';

class ProviderScreen extends StatefulWidget {
  final AiProvider recommended;
  const ProviderScreen({super.key, required this.recommended});

  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen> {
  late AiProvider _selected;

  @override
  void initState() {
    super.initState();
    // Pre-select the recommended provider
    _selected = widget.recommended;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.providerTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.providerSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Provider cards ──
              Expanded(
                child: ListView(
                  children: AiProvider.values.map((provider) {
                    final info = kProviderInfo[provider]!;
                    final isRecommended = provider == widget.recommended;
                    final isSelected = provider == _selected;

                    return Padding(
                      padding:
                      const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ProviderCard(
                        provider: provider,
                        info: info,
                        isRecommended: isRecommended,
                        isSelected: isSelected,
                        onTap: () =>
                            setState(() => _selected = provider),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Continue button ──
              ElevatedButton(
                onPressed: () =>
                    context.goKeySetup(_selected),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final AiProvider provider;
  final Map<String, dynamic> info;
  final bool isRecommended;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
    required this.info,
    required this.isRecommended,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(info['color'] as int);
    final badgeColor = Color(info['badgeColor'] as int);
    final strengths = info['strengths'] as List<dynamic>;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                // Provider color dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  info['name'] as String,
                  style: AppTextStyles.cardTitle,
                ),
                const Spacer(),

                // Recommended badge
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Recommended',
                      style: AppTextStyles.badge
                          .copyWith(color: AppColors.primary),
                    ),
                  ),

                // Free badge
                if (info['hasFree'] as bool) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      info['badge'] as String,
                      style: AppTextStyles.badge
                          .copyWith(color: badgeColor),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Tagline
            Text(
              info['tagline'] as String,
              style: AppTextStyles.cardSubtitle
                  .copyWith(color: color),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              info['description'] as String,
              style: AppTextStyles.cardSubtitle,
            ),

            const SizedBox(height: AppSpacing.md),

            // Strength tags
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: strengths.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s as String,
                    style: AppTextStyles.badge
                        .copyWith(color: AppColors.textSecondary),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Cost row
            Row(
              children: [
                const Icon(Icons.attach_money,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  info['monthlyEstimate'] as String,
                  style: AppTextStyles.cardSubtitle,
                ),
              ],
            ),

            // Selected checkmark
            if (isSelected) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Selected',
                    style: AppTextStyles.badge
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}