// usage_provider.dart
// Manages API usage statistics.
// The usage dashboard screen listens to this.

import 'package:flutter/foundation.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/services/storage_service.dart';

class UsageProvider extends ChangeNotifier {
  final _storage = StorageService();
  final _keyService = KeyService();

  int _todayRequests = 0;
  int _freeLimit = 0;
  AiProvider _provider = AiProvider.gemini;
  List<Map<String, dynamic>> _weeklyUsage = [];
  bool _loading = false;

  // Getters
  int get todayRequests => _todayRequests;
  int get freeLimit => _freeLimit;
  AiProvider get provider => _provider;
  List<Map<String, dynamic>> get weeklyUsage => _weeklyUsage;
  bool get loading => _loading;

  // Usage percentage 0.0 to 1.0
  double get usagePercent => _freeLimit > 0
      ? (_todayRequests / _freeLimit).clamp(0.0, 1.0)
      : 0.0;

  // Is user approaching limit?
  bool get isWarning => usagePercent >= AppLimits.warningThreshold;

  // Is user over limit?
  bool get isOverLimit => usagePercent >= 1.0;

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    try {
      _provider = await _keyService.getSelectedProvider();
      _todayRequests = await _storage.getTodayRequests(_provider);
      _weeklyUsage = await _storage.getWeeklyUsage(_provider);

      final info = kProviderInfo[_provider]!;
      _freeLimit = info['freeLimit'] as int;
    } catch (e) {
      debugPrint('UsageProvider error: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() => init();
}