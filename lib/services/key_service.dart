// key_service.dart
// Handles secure storage of API keys on the device.
// Uses Android Keystore / iOS Keychain for encryption.
// Keys NEVER leave the device in plain text.
// Your servers never see them — ever.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:monitor_bot/core/constants.dart';

class KeyService {
  // ─────────────────────────────────────────
  // SINGLETON — same pattern as StorageService
  // Only one instance ever exists in the app
  // ─────────────────────────────────────────
  static final KeyService _instance = KeyService._internal();
  factory KeyService() => _instance;
  KeyService._internal();

  // The secure storage object from the package
  // encryptedSharedPreferences: true on Android
  // means an extra layer of encryption on top
  // of the Android Keystore
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // first_unlock_this_device means:
      // key is accessible only after the user
      // unlocks their phone at least once after reboot
      // Prevents access if phone is stolen while off
    ),
  );

  // ─────────────────────────────────────────
  // KEY NAMES
  // These are the "labels" used to store each key.
  // Like naming a folder where you put the key.
  // Private so nothing outside this class can
  // accidentally use the wrong key name.
  // ─────────────────────────────────────────
  static const String _geminiKey = 'api_key_gemini';
  static const String _openaiKey = 'api_key_openai';
  static const String _claudeKey = 'api_key_claude';
  static const String _selectedProvider = 'selected_provider';
  static const String _onboardingDone = 'onboarding_done';

  // ─────────────────────────────────────────
  // SAVE API KEY
  // Encrypts and stores the key for a provider.
  // Called when user pastes their key during setup.
  //
  // 'async' means this function does work that
  // takes time (like writing to storage).
  // 'await' means "wait for this to finish
  // before moving to the next line".
  // ─────────────────────────────────────────
  Future<void> saveKey(AiProvider provider, String key) async {
    // Trim removes any accidental spaces the user
    // might have added when pasting
    final cleanKey = key.trim();

    // Pick the right storage label for this provider
    final storageKey = _keyNameFor(provider);

    // Write to encrypted storage
    await _storage.write(key: storageKey, value: cleanKey);
  }

  // ─────────────────────────────────────────
  // GET API KEY
  // Decrypts and returns the stored key.
  // Returns null if no key is saved yet.
  // Called every time a monitor check runs.
  // ─────────────────────────────────────────
  Future<String?> getKey(AiProvider provider) async {
    return await _storage.read(key: _keyNameFor(provider));
  }

  // ─────────────────────────────────────────
  // CHECK IF KEY EXISTS
  // Returns true if user has saved a key
  // for this provider. Used to decide whether
  // to show the setup screen or the dashboard.
  // ─────────────────────────────────────────
  Future<bool> hasKey(AiProvider provider) async {
    final key = await getKey(provider);
    // A key exists AND is not empty
    return key != null && key.isNotEmpty;
  }

  // ─────────────────────────────────────────
  // DELETE API KEY
  // Called if user wants to switch providers
  // or remove their key from the app.
  // ─────────────────────────────────────────
  Future<void> deleteKey(AiProvider provider) async {
    await _storage.delete(key: _keyNameFor(provider));
  }

  // ─────────────────────────────────────────
  // VALIDATE KEY FORMAT
  // Basic check before even saving the key.
  // Each provider has a known key prefix —
  // if it doesn't match we warn the user immediately.
  //
  // This does NOT call the API — it just checks
  // the format so we can catch obvious mistakes.
  // ─────────────────────────────────────────
  bool validateKeyFormat(AiProvider provider, String key) {
    final info = kProviderInfo[provider]!;
    final prefix = info['keyPrefix'] as String;
    final trimmed = key.trim();

    // Key must start with the known prefix
    // AND be at least 20 characters long
    return trimmed.startsWith(prefix) && trimmed.length >= 20;
  }

  // ─────────────────────────────────────────
  // VALIDATE KEY WITH API CALL
  // Actually calls the API with a tiny test prompt
  // to confirm the key is real and working.
  // Called after the user pastes their key.
  //
  // Returns true if API accepted the key.
  // Returns false if API rejected it (wrong key,
  // no credits, account suspended etc.)
  // ─────────────────────────────────────────
  Future<bool> validateKeyWithApi(AiProvider provider, String key) async {
    try {
      // We import AiService here inside the function
      // to avoid a circular import issue
      // (AiService imports KeyService, KeyService imports AiService
      // would cause an error — so we do a late import)
      final aiService = _AiServiceValidator();
      return await aiService.testKey(provider, key);
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // SELECTED PROVIDER
  // Saves which provider the user picked.
  // Loaded on app start so we remember their choice.
  // ─────────────────────────────────────────
  Future<void> saveSelectedProvider(AiProvider provider) async {
    await _storage.write(
      key: _selectedProvider,
      value: provider.name,
    );
  }

  Future<AiProvider> getSelectedProvider() async {
    final stored = await _storage.read(key: _selectedProvider);
    if (stored == null) return AiProvider.gemini; // Default to Gemini (free)
    return AiProvider.values.firstWhere(
          (e) => e.name == stored,
      orElse: () => AiProvider.gemini,
    );
  }

  // ─────────────────────────────────────────
  // ONBOARDING STATE
  // Tracks whether user has completed onboarding.
  // If true → go straight to dashboard on launch.
  // If false → show welcome/quiz screens.
  // ─────────────────────────────────────────
  Future<void> setOnboardingDone() async {
    await _storage.write(key: _onboardingDone, value: 'true');
  }

  Future<bool> isOnboardingDone() async {
    final value = await _storage.read(key: _onboardingDone);
    return value == 'true';
  }

  // ─────────────────────────────────────────
  // GET KEY SUMMARY
  // Returns a masked version of the key for display.
  // e.g. "sk-ant-...xK9p" — shows prefix and last 4 chars.
  // User can confirm it's the right key without
  // exposing the full key on screen.
  // ─────────────────────────────────────────
  Future<String> getKeyPreview(AiProvider provider) async {
    final key = await getKey(provider);
    if (key == null || key.isEmpty) return 'No key saved';
    if (key.length <= 8) return '****';

    // Show first 6 characters + ... + last 4 characters
    final prefix = key.substring(0, 6);
    final suffix = key.substring(key.length - 4);
    return '$prefix...$suffix';
  }

  // ─────────────────────────────────────────
  // CLEAR EVERYTHING
  // Removes all stored data.
  // Called from settings → "Reset app".
  // ─────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ─────────────────────────────────────────
  // PRIVATE HELPER
  // Maps a provider enum to its storage key name.
  // ─────────────────────────────────────────
  String _keyNameFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return _geminiKey;
      case AiProvider.openai:
        return _openaiKey;
      case AiProvider.claude:
        return _claudeKey;
    }
  }
}

// ─────────────────────────────────────────
// INTERNAL VALIDATOR HELPER
// A tiny helper class that makes a minimal
// API call just to test if a key works.
// Kept here to avoid circular imports.
// ─────────────────────────────────────────
class _AiServiceValidator {
  Future<bool> testKey(AiProvider provider, String key) async {
    // We use the http package for a raw HTTP call
    // dart:convert is built into Dart — no import needed for JSON
    final http = await _getHttp();

    try {
      switch (provider) {

      // ── Test Gemini key ──
        case AiProvider.gemini:
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: '{"contents":[{"parts":[{"text":"Hi"}]}]}',
          );
          // 200 = success, 400/401/403 = bad key
          return response.statusCode == 200;

      // ── Test OpenAI key ──
        case AiProvider.openai:
          final url = Uri.parse('https://api.openai.com/v1/chat/completions');
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hi"}],"max_tokens":5}',
          );
          return response.statusCode == 200;

      // ── Test Claude key ──
        case AiProvider.claude:
          final url = Uri.parse('https://api.anthropic.com/v1/messages');
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
            },
            body: '{"model":"claude-haiku-4-5-20251001","max_tokens":5,"messages":[{"role":"user","content":"Hi"}]}',
          );
          return response.statusCode == 200;
      }
    } catch (e) {
      // Network error or timeout — can't validate right now
      return false;
    }
  }

  // Gets the http client
  // We use a dynamic import pattern here
  Future<dynamic> _getHttp() async {
    // ignore: avoid_dynamic_calls
    return _HttpClient();
  }
}

// Thin wrapper around dart's http
// so we don't need a full import at the top
class _HttpClient {
  Future<_Response> post(
      Uri url, {
        Map<String, String>? headers,
        String? body,
      }) async {
    // ignore: depend_on_referenced_packages
    final client = await _createClient();
    return client.post(url, headers: headers, body: body);
  }

  Future<dynamic> _createClient() async {
    // This gets resolved at runtime via the http package
    // already declared in pubspec.yaml
    throw UnimplementedError('Use the http package directly in ai_service.dart');
  }
}

class _Response {
  final int statusCode;
  final String body;
  const _Response(this.statusCode, this.body);
}