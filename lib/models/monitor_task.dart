// monitor_task.dart
// This is the data blueprint for a single monitor bot.
// Every monitor the user creates becomes one MonitorTask object.
// It gets saved to SQLite and loaded back as this exact object.

import 'package:monitor_bot/core/constants.dart';

// ─────────────────────────────────────────
// MONITOR STATUS ENUM
// Represents the current state of a monitor.
// Instead of storing raw strings like "running"
// we use this enum — safer, no typos possible.
// ─────────────────────────────────────────
enum MonitorStatus {
  active,   // Currently running, checks happening on schedule
  paused,   // User manually paused it
  error,    // Something went wrong (page failed to load, API error)
  limitHit, // Paused automatically because free tier limit was reached
}

// ─────────────────────────────────────────
// MONITOR TASK MODEL
// ─────────────────────────────────────────
class MonitorTask {
  // ── Identity ──
  final String id;         // Unique ID for this monitor (auto-generated)
  final String name;       // User-given name e.g. "Amazon Backpack Price"

  // ── What to monitor ──
  final String url;        // The webpage URL to watch
  final String condition;  // Plain English condition e.g. "notify when price drops below ₹1500"

  // ── How to monitor ──
  final int intervalMinutes;   // How often to check in minutes e.g. 30
  final AiProvider provider;   // Which AI reads the page (gemini/openai/claude)

  // ── Current state ──
  final MonitorStatus status;  // active / paused / error / limitHit
  final String? lastSnapshot;  // Last page content the AI read (stored to compare next time)
  final String? lastError;     // If status is error, what went wrong

  // ── Timestamps ──
  final DateTime createdAt;    // When the user created this monitor
  final DateTime? lastChecked; // When the monitor last ran a check

  // ── Stats ──
  final int totalChecks;       // How many times this monitor has run total
  final int alertsFired;       // How many alerts this monitor has sent

  // ─────────────────────────────────────────
  // CONSTRUCTOR
  // This is called when creating a new MonitorTask.
  // 'required' means you MUST provide that value.
  // Fields with '?' are optional (can be null).
  // Fields with default values are optional too.
  // ─────────────────────────────────────────
  const MonitorTask({
    required this.id,
    required this.name,
    required this.url,
    required this.condition,
    required this.intervalMinutes,
    required this.provider,
    required this.createdAt,
    this.status = MonitorStatus.active,
    this.lastSnapshot,
    this.lastError,
    this.lastChecked,
    this.totalChecks = 0,
    this.alertsFired = 0,
  });

  // ─────────────────────────────────────────
  // FACTORY CONSTRUCTOR — fromMap()
  // When we read a monitor from SQLite,
  // it comes back as a raw Map (like a dictionary).
  // This factory converts that raw Map → MonitorTask object.
  //
  // Example raw map from SQLite:
  // { 'id': 'abc123', 'name': 'Amazon Price', 'url': 'https://...', ... }
  // ─────────────────────────────────────────
  factory MonitorTask.fromMap(Map<String, dynamic> map) {
    return MonitorTask(
      id: map[DbConstants.colId] as String,
      name: map[DbConstants.colName] as String,
      url: map[DbConstants.colUrl] as String,
      condition: map[DbConstants.colCondition] as String,
      intervalMinutes: map[DbConstants.colInterval] as int,

      // Convert stored string back to AiProvider enum
      // e.g. "gemini" → AiProvider.gemini
      provider: AiProvider.values.firstWhere(
            (e) => e.name == map[DbConstants.colProvider],
        orElse: () => AiProvider.gemini, // default if something goes wrong
      ),

      // Convert stored string back to MonitorStatus enum
      status: MonitorStatus.values.firstWhere(
            (e) => e.name == map[DbConstants.colActive],
        orElse: () => MonitorStatus.active,
      ),

      lastSnapshot: map[DbConstants.colLastSnapshot] as String?,
      lastError: null,

      // SQLite stores dates as strings — parse them back to DateTime
      createdAt: DateTime.parse(map[DbConstants.colCreatedAt] as String),
      lastChecked: map[DbConstants.colLastChecked] != null
          ? DateTime.parse(map[DbConstants.colLastChecked] as String)
          : null,

      totalChecks: (map['total_checks'] as int?) ?? 0,
      alertsFired: (map['alerts_fired'] as int?) ?? 0,
    );
  }

  // ─────────────────────────────────────────
  // toMap()
  // The opposite of fromMap().
  // Converts MonitorTask object → raw Map
  // so we can save it to SQLite.
  // ─────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colName: name,
      DbConstants.colUrl: url,
      DbConstants.colCondition: condition,
      DbConstants.colInterval: intervalMinutes,

      // Store enum as its string name
      // e.g. AiProvider.gemini → "gemini"
      DbConstants.colProvider: provider.name,
      DbConstants.colActive: status.name,

      DbConstants.colLastSnapshot: lastSnapshot,
      DbConstants.colCreatedAt: createdAt.toIso8601String(),
      DbConstants.colLastChecked: lastChecked?.toIso8601String(),
      'total_checks': totalChecks,
      'alerts_fired': alertsFired,
    };
  }

  // ─────────────────────────────────────────
  // copyWith()
  // In Flutter/Dart, objects are often immutable
  // (you don't change them, you make a new copy with changes).
  // copyWith() lets you do that cleanly.
  //
  // Example:
  // final updated = task.copyWith(status: MonitorStatus.paused);
  // This gives you a new MonitorTask identical to 'task'
  // but with status changed to paused.
  // ─────────────────────────────────────────
  MonitorTask copyWith({
    String? id,
    String? name,
    String? url,
    String? condition,
    int? intervalMinutes,
    AiProvider? provider,
    MonitorStatus? status,
    String? lastSnapshot,
    String? lastError,
    DateTime? createdAt,
    DateTime? lastChecked,
    int? totalChecks,
    int? alertsFired,
  }) {
    return MonitorTask(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      condition: condition ?? this.condition,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      lastSnapshot: lastSnapshot ?? this.lastSnapshot,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      lastChecked: lastChecked ?? this.lastChecked,
      totalChecks: totalChecks ?? this.totalChecks,
      alertsFired: alertsFired ?? this.alertsFired,
    );
  }

  // ─────────────────────────────────────────
  // COMPUTED PROPERTIES
  // These are read-only values calculated
  // from existing fields on the fly.
  // ─────────────────────────────────────────

  // How many times per day does this monitor check?
  // e.g. 30 min interval → 1440 ÷ 30 = 48 checks/day
  int get checksPerDay => 1440 ~/ intervalMinutes;

  // Is this monitor currently running?
  bool get isActive => status == MonitorStatus.active;

  // Has this monitor ever run a check?
  bool get hasRun => lastChecked != null;

  // Human readable status label for the UI
  String get statusLabel {
    switch (status) {
      case MonitorStatus.active:
        return 'Active';
      case MonitorStatus.paused:
        return 'Paused';
      case MonitorStatus.error:
        return 'Error';
      case MonitorStatus.limitHit:
        return 'Limit reached';
    }
  }

  // How long ago was the last check?
  // e.g. "2 minutes ago" / "1 hour ago"
  String get lastCheckedLabel {
    if (lastChecked == null) return 'Never checked';
    final diff = DateTime.now().difference(lastChecked!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // toString is useful for debugging —
  // print(task) will show something meaningful
  @override
  String toString() =>
      'MonitorTask(id: $id, name: $name, status: ${status.name})';
}