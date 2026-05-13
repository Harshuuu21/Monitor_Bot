// ai_service.dart
// The brain of the app.
// Sends webpage screenshots to AI providers
// and asks them whether a condition is met.
// Handles Gemini, OpenAI, and Claude — all three.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/services/key_service.dart';
import 'package:monitor_bot/services/storage_service.dart';

// ─────────────────────────────────────────
// AI CHECK RESULT
// What the AI returns after checking a page.
// Instead of returning raw strings, we wrap
// the result in a clean object.
// ─────────────────────────────────────────
class AiCheckResult {
  // Did the condition get met?
  final bool conditionMet;

  // What the AI found on the page
  // e.g. "Price is currently ₹1,299 which is below ₹1,500"
  final String summary;

  // The exact alert message to show the user if conditionMet is true
  final String? alertMessage;

  // Did something go wrong during the check?
  final bool hasError;
  final String? errorMessage;

  const AiCheckResult({
    required this.conditionMet,
    required this.summary,
    this.alertMessage,
    this.hasError = false,
    this.errorMessage,
  });

  // A quick factory for error results
  // so we don't repeat this structure everywhere
  factory AiCheckResult.error(String message) {
    return AiCheckResult(
      conditionMet: false,
      summary: 'Check failed',
      hasError: true,
      errorMessage: message,
    );
  }
}

// ─────────────────────────────────────────
// AI SERVICE
// ─────────────────────────────────────────
class AiService {
  // Singleton — same pattern as before
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  // Dependencies — services this file needs
  final _keyService = KeyService();
  final _storageService = StorageService();

  // HTTP timeout — if AI takes longer than this
  // we give up and return an error
  // 30 seconds is generous but safe
  static const _timeout = Duration(seconds: 30);

  // ─────────────────────────────────────────
  // MAIN METHOD — checkCondition()
  // This is what the background scheduler calls
  // every time a monitor check runs.
  //
  // It takes:
  // - provider: which AI to use
  // - pageContent: the text extracted from the page
  // - condition: the user's plain English condition
  //   e.g. "notify me when price drops below ₹1500"
  // - screenshot: the page screenshot as bytes (optional)
  //
  // It returns an AiCheckResult with conditionMet = true/false
  // ─────────────────────────────────────────
  Future<AiCheckResult> checkCondition({
    required AiProvider provider,
    required String pageContent,
    required String condition,
    Uint8List? screenshot,
  }) async {
    // Get the user's API key for this provider
    final key = await _keyService.getKey(provider);

    if (key == null || key.isEmpty) {
      return AiCheckResult.error('No API key found for ${provider.name}');
    }

    // Build the prompt we'll send to the AI
    // This is carefully worded to get a consistent
    // structured response we can parse reliably
    final prompt = _buildPrompt(condition, pageContent);

    try {
      // Route to the right provider's API
      AiCheckResult result;
      switch (provider) {
        case AiProvider.gemini:
          result = await _callGemini(key, prompt, screenshot);
          break;
        case AiProvider.openai:
          result = await _callOpenAi(key, prompt, screenshot);
          break;
        case AiProvider.claude:
          result = await _callClaude(key, prompt, screenshot);
          break;
      }

      // Record this request in usage tracking
      // so the usage dashboard stays accurate
      await _storageService.recordRequest(provider);

      return result;

    } catch (e) {
      // Something went wrong — network error, timeout, etc.
      return AiCheckResult.error('AI check failed: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────
  // BUILD PROMPT
  // The prompt is the instruction we send to the AI.
  // It's carefully structured to get a reliable
  // YES/NO response we can parse in code.
  //
  // We ask the AI to respond ONLY in JSON format
  // so we can parse it programmatically.
  // ─────────────────────────────────────────
  String _buildPrompt(String condition, String pageContent) {
    return '''
You are a web monitoring assistant. Your job is to check if a specific condition is met on a webpage.

CONDITION TO CHECK:
$condition

PAGE CONTENT:
$pageContent

INSTRUCTIONS:
1. Read the page content carefully
2. Check if the condition above is currently met
3. Respond ONLY with a valid JSON object — no other text, no markdown, no explanation outside the JSON

RESPONSE FORMAT (respond with exactly this structure):
{
  "condition_met": true or false,
  "summary": "Brief description of what you found on the page (max 100 words)",
  "alert_message": "If condition_met is true: write a clear alert message for the user. If false: null",
  "current_value": "The current value relevant to the condition e.g. current price, current status"
}

EXAMPLES:
- If condition is "price below ₹1500" and page shows ₹1,299: condition_met = true
- If condition is "price below ₹1500" and page shows ₹2,499: condition_met = false
- If condition is "new problem added" and you see a problem newer than yesterday: condition_met = true

Be precise. Only return the JSON object.
''';
  }

  // ─────────────────────────────────────────
  // CALL GEMINI API
  // Google's API format is unique —
  // it uses "contents" with "parts" structure.
  // The API key goes in the URL itself, not headers.
  // ─────────────────────────────────────────
  Future<AiCheckResult> _callGemini(
      String key,
      String prompt,
      Uint8List? screenshot,
      ) async {
    final info = kProviderInfo[AiProvider.gemini]!;
    final model = info['model'] as String;

    // Build the URL — key goes as query parameter
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
    );

    // Build the request body
    // Gemini uses "contents" → "parts" structure
    final List<Map<String, dynamic>> parts = [
      {'text': prompt},
    ];

    // If we have a screenshot, add it as an image part
    // Gemini can look at images (vision capability)
    if (screenshot != null) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/png',
          // base64 encodes the image bytes as a string
          // APIs can't send raw binary — base64 is the standard way
          'data': base64Encode(screenshot),
        }
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'temperature': 0.1,    // Low temperature = more consistent/deterministic responses
        'maxOutputTokens': 500, // We only need a short JSON response
      },
    });

    // Make the actual HTTP POST request
    final response = await http
        .post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    )
        .timeout(_timeout);

    // Parse the response
    return _parseGeminiResponse(response);
  }

  // Parse Gemini's response format into AiCheckResult
  AiCheckResult _parseGeminiResponse(http.Response response) {
    if (response.statusCode != 200) {
      return AiCheckResult.error(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    try {
      // Gemini wraps the text in:
      // candidates[0].content.parts[0].text
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List;
      final content = candidates[0]['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      final text = parts[0]['text'] as String;

      return _parseAiJsonResponse(text);
    } catch (e) {
      return AiCheckResult.error('Failed to parse Gemini response: $e');
    }
  }

  // ─────────────────────────────────────────
  // CALL OPENAI API
  // OpenAI uses "messages" array format.
  // API key goes in Authorization header as "Bearer key".
  // Supports vision via image_url in message content.
  // ─────────────────────────────────────────
  Future<AiCheckResult> _callOpenAi(
      String key,
      String prompt,
      Uint8List? screenshot,
      ) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Build message content
    // If no screenshot: just text
    // If screenshot: text + image
    final List<Map<String, dynamic>> content = [
      {'type': 'text', 'text': prompt},
    ];

    if (screenshot != null) {
      content.add({
        'type': 'image_url',
        'image_url': {
          // OpenAI accepts base64 images as data URLs
          'url': 'data:image/png;base64,${base64Encode(screenshot)}',
          'detail': 'high', // 'high' = more detailed analysis
        },
      });
    }

    final body = jsonEncode({
      'model': kProviderInfo[AiProvider.openai]!['model'],
      'messages': [
        {
          'role': 'user',
          'content': screenshot != null ? content : prompt,
        }
      ],
      'max_tokens': 500,
      'temperature': 0.1,
    });

    final response = await http
        .post(
      url,
      headers: {
        'Content-Type': 'application/json',
        // OpenAI auth: "Bearer" + space + key
        'Authorization': 'Bearer $key',
      },
      body: body,
    )
        .timeout(_timeout);

    return _parseOpenAiResponse(response);
  }

  // Parse OpenAI's response format
  AiCheckResult _parseOpenAiResponse(http.Response response) {
    if (response.statusCode != 200) {
      return AiCheckResult.error(
        'OpenAI API error ${response.statusCode}: ${response.body}',
      );
    }

    try {
      // OpenAI wraps text in:
      // choices[0].message.content
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List;
      final message = choices[0]['message'] as Map<String, dynamic>;
      final text = message['content'] as String;

      return _parseAiJsonResponse(text);
    } catch (e) {
      return AiCheckResult.error('Failed to parse OpenAI response: $e');
    }
  }

  // ─────────────────────────────────────────
  // CALL CLAUDE API
  // Anthropic uses "messages" array like OpenAI
  // but has different headers and body structure.
  // Requires 'anthropic-version' header.
  // ─────────────────────────────────────────
  Future<AiCheckResult> _callClaude(
      String key,
      String prompt,
      Uint8List? screenshot,
      ) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    // Build message content
    final List<Map<String, dynamic>> content = [];

    // Claude expects image BEFORE text in the content array
    if (screenshot != null) {
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': base64Encode(screenshot),
        },
      });
    }

    content.add({'type': 'text', 'text': prompt});

    final body = jsonEncode({
      'model': kProviderInfo[AiProvider.claude]!['model'],
      'max_tokens': 500,
      'messages': [
        {
          'role': 'user',
          'content': screenshot != null ? content : prompt,
        }
      ],
    });

    final response = await http
        .post(
      url,
      headers: {
        'Content-Type': 'application/json',
        // Claude uses 'x-api-key' header — different from OpenAI
        'x-api-key': key,
        // Required by Anthropic — tells them which API version to use
        'anthropic-version': '2023-06-01',
      },
      body: body,
    )
        .timeout(_timeout);

    return _parseClaudeResponse(response);
  }

  // Parse Claude's response format
  AiCheckResult _parseClaudeResponse(http.Response response) {
    if (response.statusCode != 200) {
      return AiCheckResult.error(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    try {
      // Claude wraps text in:
      // content[0].text
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List;
      final text = content[0]['text'] as String;

      return _parseAiJsonResponse(text);
    } catch (e) {
      return AiCheckResult.error('Failed to parse Claude response: $e');
    }
  }

  // ─────────────────────────────────────────
  // PARSE AI JSON RESPONSE
  // All three providers ultimately give us a text string.
  // We asked the AI to respond in JSON format.
  // This method parses that JSON into AiCheckResult.
  //
  // We're defensive here — AI sometimes adds
  // extra text around the JSON even when told not to.
  // We handle that gracefully.
  // ─────────────────────────────────────────
  AiCheckResult _parseAiJsonResponse(String text) {
    try {
      // Strip any markdown code fences the AI might add
      // e.g. ```json { ... } ``` → { ... }
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Parse the JSON
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final conditionMet = json['condition_met'] as bool? ?? false;
      final summary = json['summary'] as String? ?? 'No summary provided';
      final alertMessage = json['alert_message'] as String?;

      return AiCheckResult(
        conditionMet: conditionMet,
        summary: summary,
        alertMessage: conditionMet ? alertMessage : null,
      );
    } catch (e) {
      // If JSON parsing fails, try to extract a yes/no from raw text
      // This is a fallback for when the AI ignores our format instruction
      final lower = text.toLowerCase();
      final conditionMet = lower.contains('condition_met": true') ||
          lower.contains('yes, the condition is met') ||
          lower.contains('condition is met');

      return AiCheckResult(
        conditionMet: conditionMet,
        summary: text.length > 200 ? text.substring(0, 200) : text,
        alertMessage: conditionMet ? 'Condition met — check the page' : null,
      );
    }
  }

  // ─────────────────────────────────────────
  // VALIDATE KEY
  // Makes a minimal test API call to confirm
  // the key is real and working.
  // Called from the key setup screen.
  // ─────────────────────────────────────────
  Future<bool> validateKey(AiProvider provider, String key) async {
    try {
      const testPrompt = 'Respond with exactly: {"condition_met": false, "summary": "test", "alert_message": null}';

      AiCheckResult result;
      switch (provider) {
        case AiProvider.gemini:
          result = await _callGemini(key, testPrompt, null);
          break;
        case AiProvider.openai:
          result = await _callOpenAi(key, testPrompt, null);
          break;
        case AiProvider.claude:
          result = await _callClaude(key, testPrompt, null);
          break;
      }

      // If we got any result without an error, the key works
      return !result.hasError;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // ESTIMATE MONTHLY COST
  // Calculates approximate monthly API cost
  // based on number of bots and check interval.
  // Used by the cost estimator in the UI.
  //
  // Costs are rough estimates — actual cost
  // depends on page size and response length.
  // ─────────────────────────────────────────
  Map<String, dynamic> estimateCost({
    required AiProvider provider,
    required int botCount,
    required int intervalMinutes,
  }) {
    // How many checks per day per bot?
    final checksPerDay = 1440 ~/ intervalMinutes;

    // Total checks per day across all bots
    final totalChecksPerDay = checksPerDay * botCount;

    // Total checks per month (30 days)
    final totalChecksPerMonth = totalChecksPerDay * 30;

    // Cost per check in USD (rough estimates)
    const Map<AiProvider, double> costPerCheck = {
      AiProvider.gemini: 0.000035,  // Very cheap — flash model
      AiProvider.openai: 0.01,      // GPT-4o vision
      AiProvider.claude: 0.008,     // Claude Sonnet
    };

    final cost = costPerCheck[provider]! * totalChecksPerMonth;

    // Free tier info
    final info = kProviderInfo[provider]!;
    final freeLimit = info['freeLimit'] as int;
    final isFreeProvider = freeLimit > 0;

    // For Gemini: how many checks fit in free tier?
    String freeNote = '';
    if (isFreeProvider) {
      if (totalChecksPerDay <= freeLimit) {
        freeNote = 'Within free tier — \$0/month';
      } else {
        final overBy = totalChecksPerDay - freeLimit;
        freeNote = 'Exceeds free tier by $overBy requests/day';
      }
    }

    return {
      'checksPerDay': totalChecksPerDay,
      'checksPerMonth': totalChecksPerMonth,
      'estimatedCostUsd': cost,
      'estimatedCostInr': cost * 83, // Approximate USD → INR
      'isWithinFreeTier': isFreeProvider && totalChecksPerDay <= freeLimit,
      'freeNote': freeNote,
      'withinFreeTier': isFreeProvider && totalChecksPerDay <= freeLimit,
    };
  }
}