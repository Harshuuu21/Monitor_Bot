// constants.dart
// Central config file for the entire app.
// Every fixed value lives here — URLs, limits, labels, pricing.
// Never hardcode these values directly in your screens.

// ─────────────────────────────────────────
// AI PROVIDER CONSTANTS
// Everything the app needs to know about
// each AI provider — in one clean place.
// ─────────────────────────────────────────

// Enum = a fixed list of named options.
// Instead of typing "gemini" as a raw string everywhere
// (which can cause typos), we use AiProvider.gemini.
// Dart will catch mistakes at compile time.
enum AiProvider {
  gemini,
  openai,
  claude,
}

// All metadata about each provider in one map.
// Your UI screens just read from this —
// no provider-specific logic scattered everywhere.
const Map<AiProvider, Map<String, dynamic>> kProviderInfo = {

  AiProvider.gemini: {
    // Display name shown in UI
    'name': 'Google Gemini',

    // Short model identifier sent in API calls
    'model': 'gemini-1.5-flash',

    // The actual API endpoint URL
    // %s will be replaced with the user's API key at runtime
    'endpoint': 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%s',

    // One-line pitch shown on provider card
    'tagline': 'Best value · Free tier available',

    // Longer description shown on provider card
    'description':
    'Perfect for getting started. Offers a generous free tier '
        'with 1,500 requests per day at no cost. Great for monitoring '
        'long pages thanks to its large context window.',

    // Strengths shown as tags on the card
    'strengths': ['Free tier', 'Best value', 'Longest context', 'Fast'],

    // Estimated cost per single monitor check
    'costPerCheck': 'Free / ~\$0.002',

    // Monthly cost estimate for typical usage
    'monthlyEstimate': 'Free for most users',

    // Whether a free tier exists
    'hasFree': true,

    // Daily free request limit
    'freeLimit': 1500,

    // Link to get an API key
    'keyUrl': 'https://aistudio.google.com/app/apikey',

    // What the key looks like (shown as placeholder in input)
    'keyPrefix': 'AIza',

    // Step by step instructions for getting a key
    'keySteps': [
      'Go to Google AI Studio (link above)',
      'Sign in with your Google account',
      'Click "Get API key" in the top left',
      'Click "Create API key"',
      'Copy the key and paste it below',
    ],

    // Badge label shown on card
    'badge': 'FREE TIER',

    // Badge color (hex)
    'badgeColor': 0xFF1DB954,

    // Brand color for the card accent
    'color': 0xFF4285F4,
  },

  AiProvider.openai: {
    'name': 'OpenAI GPT-4o',
    'model': 'gpt-4o',
    'endpoint': 'https://api.openai.com/v1/chat/completions',
    'tagline': 'Most popular · Most versatile',
    'description':
    'The most widely used AI in the world. Extremely reliable and '
        'versatile — handles any webpage, any condition, any language. '
        'Best choice if you want the most battle-tested option.',
    'strengths': ['Most popular', 'Most versatile', 'Highly reliable', 'Vision'],
    'costPerCheck': '~\$0.01',
    'monthlyEstimate': '~\$1–5/month for typical use',
    'hasFree': false,
    'freeLimit': 0,
    'keyUrl': 'https://platform.openai.com/api-keys',
    'keyPrefix': 'sk-',
    'keySteps': [
      'Go to platform.openai.com (link above)',
      'Sign in or create an account',
      'Click your profile → "API keys"',
      'Click "+ Create new secret key"',
      'Give it a name like "Monitor Bot"',
      'Copy the key immediately — it won\'t show again',
      'Paste it below',
    ],
    'badge': 'POPULAR',
    'badgeColor': 0xFF3B82F6,
    'color': 0xFF10A37F,
  },

  AiProvider.claude: {
    'name': 'Anthropic Claude',
    'model': 'claude-sonnet-4-6',
    'endpoint': 'https://api.anthropic.com/v1/messages',
    'tagline': 'Best reasoning · Most nuanced',
    'description':
    'Excels at following complex, nuanced instructions precisely. '
        'Ideal if you write detailed conditions like "notify me only if '
        'price drops AND it\'s sold by the official brand AND rating stays above 4 stars."',
    'strengths': ['Best reasoning', 'Complex conditions', 'Nuanced', 'Precise'],
    'costPerCheck': '~\$0.01',
    'monthlyEstimate': '~\$1–5/month for typical use',
    'hasFree': false,
    'freeLimit': 0,
    'keyUrl': 'https://console.anthropic.com/settings/keys',
    'keyPrefix': 'sk-ant-',
    'keySteps': [
      'Go to console.anthropic.com (link above)',
      'Sign in or create an account',
      'Go to Settings → API Keys',
      'Click "Create Key"',
      'Give it a name like "Monitor Bot"',
      'Copy the key and paste it below',
    ],
    'badge': 'BEST REASONING',
    'badgeColor': 0xFFD4A853,
    'color': 0xFFD4A853,
  },
};

// ─────────────────────────────────────────
// USAGE LIMITS
// These control the smart warning system.
// When user hits these thresholds we warn them.
// ─────────────────────────────────────────
class AppLimits {
  // Warn user when they've used this % of their daily free quota
  static const double warningThreshold = 0.80; // 80%

  // Pause all bots when this % is hit
  static const double pauseThreshold = 1.0; // 100%

  // Maximum bots allowed on free tier (Gemini 1500/day ÷ 48 checks = 31)
  static const int maxFreeBots = 31;

  // Minimum check interval in minutes
  // (shorter than this drains quota too fast)
  static const int minIntervalMinutes = 15;

  // Default interval for new monitors
  static const int defaultIntervalMinutes = 30;

  // Maximum interval
  static const int maxIntervalMinutes = 1440; // 24 hours
}

// ─────────────────────────────────────────
// DATABASE CONSTANTS
// Names for our SQLite tables and columns.
// Using constants prevents typos in SQL queries.
// ─────────────────────────────────────────
class DbConstants {
  // Database file name stored on device
  static const String dbName = 'monitor_bot.db';

  // Current database version
  // Increment this if you change the table structure
  static const int dbVersion = 1;

  // ── Monitor tasks table ──
  // Stores every monitor bot the user creates
  static const String tableMonitors = 'monitors';
  static const String colId = 'id';
  static const String colName = 'name';           // User-given name e.g. "Amazon Backpack"
  static const String colUrl = 'url';             // Page URL to monitor
  static const String colCondition = 'condition'; // Plain English condition
  static const String colInterval = 'interval';   // Check interval in minutes
  static const String colProvider = 'provider';   // Which AI provider
  static const String colActive = 'active';       // 1 = running, 0 = paused
  static const String colCreatedAt = 'created_at';
  static const String colLastChecked = 'last_checked';
  static const String colLastSnapshot = 'last_snapshot'; // Last page content seen

  // ── Alerts table ──
  // Stores every alert that was fired
  static const String tableAlerts = 'alerts';
  static const String colMonitorId = 'monitor_id'; // Which monitor triggered it
  static const String colMessage = 'message';       // Alert message shown to user
  static const String colTriggeredAt = 'triggered_at';
  static const String colRead = 'read';             // 1 = user has seen it

  // ── Usage table ──
  // Tracks daily API request counts per provider
  static const String tableUsage = 'usage';
  static const String colDate = 'date';             // e.g. "2026-05-13"
  static const String colRequests = 'requests';     // How many requests made today
}

// ─────────────────────────────────────────
// APP-WIDE STRING CONSTANTS
// All text shown in the app lives here.
// Easy to update, easy to translate later.
// ─────────────────────────────────────────
class AppStrings {
  static const String appName = 'Monitor Bot';
  static const String tagline = 'Your 24/7 AI web watcher';

  // Onboarding
  static const String welcomeTitle = 'Meet Monitor Bot';
  static const String welcomeSubtitle =
      'Set it, forget it. Get notified the moment anything changes on any website.';
  static const String quizTitle = 'Let\'s find your perfect plan';
  static const String providerTitle = 'Choose your AI';
  static const String providerSubtitle =
      'Your API key stays on your device only. We never see it.';

  // Dashboard
  static const String dashboardTitle = 'My Monitors';
  static const String noMonitors = 'No monitors yet';
  static const String noMonitorsSubtitle = 'Tap + to start watching a website';

  // Usage
  static const String usageTitle = 'Usage & Costs';
  static const String warningNearLimit =
      'You\'re approaching your daily free limit. Consider increasing check intervals.';
  static const String warningOverLimit =
      'Daily free limit reached. Monitors paused until midnight.';

  // Errors
  static const String errorInvalidKey = 'Invalid API key. Please check and try again.';
  static const String errorNetwork = 'Network error. Check your connection.';
  static const String errorPageLoad = 'Could not load page. The site may be blocking automated access.';
}

// ─────────────────────────────────────────
// ROUTE NAMES
// All screen route paths in one place.
// go_router uses these strings to navigate.
// ─────────────────────────────────────────
class AppRoutes {
  static const String welcome = '/';
  static const String quiz = '/quiz';
  static const String providerSelect = '/provider-select';
  static const String keySetup = '/key-setup';
  static const String home = '/home';
  static const String addMonitor = '/add-monitor';
  static const String monitorDetail = '/monitor-detail';
  static const String usage = '/usage';
  static const String alerts = '/alerts';
  static const String settings = '/settings';
}