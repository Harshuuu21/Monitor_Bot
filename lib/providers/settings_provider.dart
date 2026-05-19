import 'package:flutter/foundation.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/services/key_service.dart';

class SettingsProvider extends ChangeNotifier {
  final _keyService = KeyService();
  AiProvider _selectedProvider = AiProvider.gemini;
  bool _loading = false;

  AiProvider get selectedProvider => _selectedProvider;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    _selectedProvider = await _keyService.getSelectedProvider();
    _loading = false;
    notifyListeners();
  }

  Future<void> setProvider(AiProvider provider) async {
    _selectedProvider = provider;
    await _keyService.saveSelectedProvider(provider);
    notifyListeners();
  }
}
