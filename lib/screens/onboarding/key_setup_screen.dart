// key_setup_screen.dart
// Guides user through getting and pasting their API key.
// Shows step-by-step instructions for the chosen provider.
// Validates the key before saving.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/services/ai_service.dart';
import 'package:monitor_bot/services/background_service.dart';

class KeySetupScreen extends StatefulWidget {
  final AiProvider provider;
  const KeySetupScreen({super.key, required this.provider});

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  final _keyController = TextEditingController();
  final _keyService = KeyService();
  final _aiService = AiService();

  bool _keyVisible = false;
  bool _validating = false;
  bool _keyValid = false;
  String? _validationError;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = kProviderInfo[widget.provider]!;
    final color = Color(info['color'] as int);
    final steps = info['keySteps'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Set up ${info['name']}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Security banner ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Your key is encrypted and stored only on this device. '
                            'We cannot access it — ever.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Step by step guide ──
              Text(
                'How to get your API key:',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppSpacing.md),

              ...steps.asMap().entries.map((entry) {
                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step number circle
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: AppTextStyles.badge
                                .copyWith(color: color),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          entry.value as String,
                          style: AppTextStyles.cardSubtitle
                              .copyWith(
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.md),

              // ── Get key link ──
              GestureDetector(
                onTap: () async {
                  final url =
                  Uri.parse(info['keyUrl'] as String);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new,
                          color: color, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Open ${info['name']} to get your key',
                        style: AppTextStyles.cardTitle
                            .copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Key input ──
              Text('Paste your API key here:',
                  style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _keyController,
                obscureText: !_keyVisible,
                style: AppTextStyles.monospace,
                onChanged: (_) {
                  // Reset validation when user types
                  setState(() {
                    _keyValid = false;
                    _validationError = null;
                  });
                },
                decoration: InputDecoration(
                  hintText: info['keyPrefix'] as String,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _keyVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _keyVisible = !_keyVisible),
                  ),
                  // Show green border if key is valid
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _keyValid
                          ? AppColors.success
                          : AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Validation status
              if (_validationError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: AppTextStyles.cardSubtitle
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],

              if (_keyValid) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Key verified successfully!',
                      style: AppTextStyles.cardSubtitle
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Validate & Save button ──
              ElevatedButton(
                onPressed: _validating ? null : _validateAndSave,
                child: _validating
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  _keyValid ? 'Start monitoring!' : 'Verify & Save key',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Why we can't do this automatically ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why do I need to paste my own key?',
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'For your security and privacy. If we managed the API key ourselves, '
                          'all your monitoring data would pass through our servers. '
                          'By using your own key, everything stays on your device — '
                          'we literally cannot see what you\'re monitoring.',
                      style: AppTextStyles.cardSubtitle,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateAndSave() async {
    final key = _keyController.text.trim();

    // Basic format check
    if (key.isEmpty) {
      setState(() =>
      _validationError = 'Please paste your API key first');
      return;
    }

    if (!_keyService.validateKeyFormat(widget.provider, key)) {
      final info = kProviderInfo[widget.provider]!;
      setState(() => _validationError =
      'Key should start with "${info['keyPrefix']}". Check you copied it correctly.');
      return;
    }

    // Start loading
    setState(() {
      _validating = true;
      _validationError = null;
    });

    // Validate with real API call
    final isValid =
    await _aiService.validateKey(widget.provider, key);

    if (!isValid) {
      setState(() {
        _validating = false;
        _validationError =
        'Key not accepted by the API. Check it\'s correct and has credits available.';
      });
      return;
    }

    // Save the key securely
    await _keyService.saveKey(widget.provider, key);
    await _keyService.saveSelectedProvider(widget.provider);
    await _keyService.setOnboardingDone();

    // Start background monitoring
    await BackgroundService().startMonitoring();

    setState(() {
      _validating = false;
      _keyValid = true;
    });

    // Navigate to home after short delay
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) context.goHome();
  }
}