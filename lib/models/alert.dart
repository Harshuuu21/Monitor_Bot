// alert.dart
// Data blueprint for a single alert/notification.
// Every time a monitor condition is met,
// one Alert object is created and stored in SQLite.

import 'package:monitor_bot/core/constants.dart';

class Alert {
  final String id;            // Unique alert ID
  final String monitorId;     // Which monitor triggered this alert
  final String monitorName;   // Name of that monitor (for display)
  final String message;       // What the AI found e.g. "Price dropped to ₹1,299!"
  final DateTime triggeredAt; // When it happened
  final bool isRead;          // Has the user seen this alert?
  final String? screenshotPath; // Optional — path to screenshot that triggered it

  const Alert({
    required this.id,
    required this.monitorId,
    required this.monitorName,
    required this.message,
    required this.triggeredAt,
    this.isRead = false,
    this.screenshotPath,
  });

  // Convert raw SQLite map → Alert object
  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map[DbConstants.colId] as String,
      monitorId: map[DbConstants.colMonitorId] as String,
      monitorName: map['monitor_name'] as String? ?? 'Unknown',
      message: map[DbConstants.colMessage] as String,
      triggeredAt: DateTime.parse(map[DbConstants.colTriggeredAt] as String),
      isRead: (map[DbConstants.colRead] as int) == 1,
      screenshotPath: map['screenshot_path'] as String?,
    );
  }

  // Convert Alert object → raw map for SQLite
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: id,
      DbConstants.colMonitorId: monitorId,
      'monitor_name': monitorName,
      DbConstants.colMessage: message,
      DbConstants.colTriggeredAt: triggeredAt.toIso8601String(),
      DbConstants.colRead: isRead ? 1 : 0,
      'screenshot_path': screenshotPath,
    };
  }

  // Create a copy with some fields changed
  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      monitorId: monitorId,
      monitorName: monitorName,
      message: message,
      triggeredAt: triggeredAt,
      isRead: isRead ?? this.isRead,
      screenshotPath: screenshotPath,
    );
  }

  // Human readable time e.g. "2 hours ago"
  String get timeAgo {
    final diff = DateTime.now().difference(triggeredAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}