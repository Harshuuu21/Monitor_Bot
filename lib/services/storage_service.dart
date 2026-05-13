// storage_service.dart
// The entire database layer of the app.
// All reading and writing to SQLite goes through here.
// No screen should ever touch the database directly —
// they always go through this service.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/models/monitor_task.dart';
import 'package:monitor_bot/models/alert.dart';

// ─────────────────────────────────────────
// SINGLETON PATTERN
// We only ever want ONE instance of this service
// running in the app at any time.
// This pattern ensures that.
//
// How it works:
// StorageService._internal() is a private constructor.
// StorageService() always returns the same instance (_instance).
// So no matter how many times you write StorageService(),
// you always get the exact same object back.
// ─────────────────────────────────────────
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // The actual database object
  // '?' means it starts as null until we initialize it
  Database? _db;

  // ─────────────────────────────────────────
  // INITIALIZE DATABASE
  // Called once when the app starts.
  // Creates the database file and all tables
  // if they don't already exist.
  // ─────────────────────────────────────────
  Future<void> init() async {
    if (_db != null) return; // Already initialized, skip

    // Get the path where we'll store the database file on the device
    // On Android this is usually: /data/data/com.yourapp/databases/
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, DbConstants.dbName);

    // Open (or create) the database
    _db = await openDatabase(
      path,
      version: DbConstants.dbVersion,

      // onCreate runs ONLY the very first time the app is installed
      // It creates all our tables
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },

      // onUpgrade runs when dbVersion is incremented
      // Use this later if you add new columns or tables
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Future migrations go here
      },
    );
  }

  // ─────────────────────────────────────────
  // CREATE TABLES
  // SQL statements that define our table structure.
  //
  // SQL is the language used to talk to databases.
  // CREATE TABLE = make a new table
  // TEXT = stores text (strings)
  // INTEGER = stores whole numbers
  // PRIMARY KEY = unique identifier for each row
  // ─────────────────────────────────────────
  Future<void> _createTables(Database db) async {
    // ── Monitors table ──
    // One row = one monitor bot the user created
    await db.execute('''
      CREATE TABLE ${DbConstants.tableMonitors} (
        ${DbConstants.colId}           TEXT PRIMARY KEY,
        ${DbConstants.colName}         TEXT NOT NULL,
        ${DbConstants.colUrl}          TEXT NOT NULL,
        ${DbConstants.colCondition}    TEXT NOT NULL,
        ${DbConstants.colInterval}     INTEGER NOT NULL DEFAULT 30,
        ${DbConstants.colProvider}     TEXT NOT NULL DEFAULT 'gemini',
        ${DbConstants.colActive}       TEXT NOT NULL DEFAULT 'active',
        ${DbConstants.colLastSnapshot} TEXT,
        ${DbConstants.colCreatedAt}    TEXT NOT NULL,
        ${DbConstants.colLastChecked}  TEXT,
        total_checks                   INTEGER DEFAULT 0,
        alerts_fired                   INTEGER DEFAULT 0
      )
    ''');

    // ── Alerts table ──
    // One row = one fired alert/notification
    await db.execute('''
      CREATE TABLE ${DbConstants.tableAlerts} (
        ${DbConstants.colId}          TEXT PRIMARY KEY,
        ${DbConstants.colMonitorId}   TEXT NOT NULL,
        monitor_name                  TEXT NOT NULL,
        ${DbConstants.colMessage}     TEXT NOT NULL,
        ${DbConstants.colTriggeredAt} TEXT NOT NULL,
        ${DbConstants.colRead}        INTEGER DEFAULT 0,
        screenshot_path               TEXT,
        FOREIGN KEY (${DbConstants.colMonitorId})
          REFERENCES ${DbConstants.tableMonitors}(${DbConstants.colId})
          ON DELETE CASCADE
      )
    ''');

    // ── Usage table ──
    // One row = one day's request count
    // Tracks how many AI API calls were made each day
    await db.execute('''
      CREATE TABLE ${DbConstants.tableUsage} (
        ${DbConstants.colId}       TEXT PRIMARY KEY,
        ${DbConstants.colDate}     TEXT NOT NULL UNIQUE,
        ${DbConstants.colProvider} TEXT NOT NULL,
        ${DbConstants.colRequests} INTEGER DEFAULT 0
      )
    ''');
  }

  // ─────────────────────────────────────────
  // MONITOR CRUD OPERATIONS
  // CRUD = Create, Read, Update, Delete
  // These are the 4 basic database operations
  // ─────────────────────────────────────────

  // CREATE — Save a new monitor to the database
  Future<void> insertMonitor(MonitorTask task) async {
    await _db!.insert(
      DbConstants.tableMonitors,
      task.toMap(),
      // If a monitor with this ID already exists, replace it
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // READ ALL — Get every monitor the user has created
  Future<List<MonitorTask>> getAllMonitors() async {
    // SELECT * = get all columns
    // ORDER BY created_at DESC = newest first
    final List<Map<String, dynamic>> maps = await _db!.query(
      DbConstants.tableMonitors,
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );

    // Convert each raw map into a MonitorTask object
    return maps.map((map) => MonitorTask.fromMap(map)).toList();
  }

  // READ ONE — Get a single monitor by its ID
  Future<MonitorTask?> getMonitor(String id) async {
    final maps = await _db!.query(
      DbConstants.tableMonitors,
      where: '${DbConstants.colId} = ?',
      // '?' gets replaced with the actual id value
      // This is called a parameterized query — prevents SQL injection
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MonitorTask.fromMap(maps.first);
  }

  // READ ACTIVE — Get only monitors that are currently running
  Future<List<MonitorTask>> getActiveMonitors() async {
    final maps = await _db!.query(
      DbConstants.tableMonitors,
      where: '${DbConstants.colActive} = ?',
      whereArgs: ['active'],
    );
    return maps.map((map) => MonitorTask.fromMap(map)).toList();
  }

  // UPDATE — Save changes to an existing monitor
  Future<void> updateMonitor(MonitorTask task) async {
    await _db!.update(
      DbConstants.tableMonitors,
      task.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [task.id],
    );
  }

  // UPDATE SNAPSHOT — Called after every check
  // Saves the latest page content so next check can compare
  Future<void> updateSnapshot(String id, String snapshot) async {
    await _db!.update(
      DbConstants.tableMonitors,
      {
        DbConstants.colLastSnapshot: snapshot,
        DbConstants.colLastChecked: DateTime.now().toIso8601String(),
        // Increment total_checks by 1 using SQL arithmetic
        'total_checks': await _getCheckCount(id) + 1,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> _getCheckCount(String id) async {
    final result = await _db!.query(
      DbConstants.tableMonitors,
      columns: ['total_checks'],
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    return result.isEmpty ? 0 : (result.first['total_checks'] as int? ?? 0);
  }

  // UPDATE STATUS — Pause, resume, or mark error on a monitor
  Future<void> updateMonitorStatus(String id, MonitorStatus status) async {
    await _db!.update(
      DbConstants.tableMonitors,
      {DbConstants.colActive: status.name},
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  // DELETE — Remove a monitor permanently
  Future<void> deleteMonitor(String id) async {
    await _db!.delete(
      DbConstants.tableMonitors,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    // Related alerts are deleted automatically
    // because of ON DELETE CASCADE in the table definition
  }

  // ─────────────────────────────────────────
  // ALERT CRUD OPERATIONS
  // ─────────────────────────────────────────

  // CREATE — Save a new alert
  Future<void> insertAlert(Alert alert) async {
    await _db!.insert(
      DbConstants.tableAlerts,
      alert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Also increment alerts_fired counter on the monitor
    final monitor = await getMonitor(alert.monitorId);
    if (monitor != null) {
      await _db!.update(
        DbConstants.tableMonitors,
        {'alerts_fired': monitor.alertsFired + 1},
        where: '${DbConstants.colId} = ?',
        whereArgs: [alert.monitorId],
      );
    }
  }

  // READ ALL — Get all alerts, newest first
  Future<List<Alert>> getAllAlerts() async {
    final maps = await _db!.query(
      DbConstants.tableAlerts,
      orderBy: '${DbConstants.colTriggeredAt} DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  // READ UNREAD COUNT — How many alerts hasn't the user seen?
  Future<int> getUnreadAlertCount() async {
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM ${DbConstants.tableAlerts} WHERE ${DbConstants.colRead} = 0',
    );
    return result.first['count'] as int;
  }

  // UPDATE — Mark an alert as read
  Future<void> markAlertRead(String id) async {
    await _db!.update(
      DbConstants.tableAlerts,
      {DbConstants.colRead: 1},
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  // Mark ALL alerts as read
  Future<void> markAllAlertsRead() async {
    await _db!.update(
      DbConstants.tableAlerts,
      {DbConstants.colRead: 1},
    );
  }

  // DELETE — Clear all alerts
  Future<void> clearAlerts() async {
    await _db!.delete(DbConstants.tableAlerts);
  }

  // ─────────────────────────────────────────
  // USAGE TRACKING
  // Tracks how many API requests were made today
  // so we can show the usage dashboard
  // ─────────────────────────────────────────

  // Increment today's request count by 1
  Future<void> recordRequest(AiProvider provider) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final id = '${provider.name}_$today';

    // Try to get existing record for today
    final existing = await _db!.query(
      DbConstants.tableUsage,
      where: '${DbConstants.colDate} = ? AND ${DbConstants.colProvider} = ?',
      whereArgs: [today, provider.name],
    );

    if (existing.isEmpty) {
      // First request today — create a new row
      await _db!.insert(DbConstants.tableUsage, {
        DbConstants.colId: id,
        DbConstants.colDate: today,
        DbConstants.colProvider: provider.name,
        DbConstants.colRequests: 1,
      });
    } else {
      // Already have requests today — increment the count
      final current = existing.first[DbConstants.colRequests] as int;
      await _db!.update(
        DbConstants.tableUsage,
        {DbConstants.colRequests: current + 1},
        where: '${DbConstants.colDate} = ? AND ${DbConstants.colProvider} = ?',
        whereArgs: [today, provider.name],
      );
    }
  }

  // Get today's request count for a specific provider
  Future<int> getTodayRequests(AiProvider provider) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await _db!.query(
      DbConstants.tableUsage,
      where: '${DbConstants.colDate} = ? AND ${DbConstants.colProvider} = ?',
      whereArgs: [today, provider.name],
    );
    if (result.isEmpty) return 0;
    return result.first[DbConstants.colRequests] as int;
  }

  // Get usage for the last 7 days — used for the usage chart
  Future<List<Map<String, dynamic>>> getWeeklyUsage(AiProvider provider) async {
    final result = await _db!.query(
      DbConstants.tableUsage,
      where: '${DbConstants.colProvider} = ?',
      whereArgs: [provider.name],
      orderBy: '${DbConstants.colDate} DESC',
      limit: 7,
    );
    return result;
  }

  // ─────────────────────────────────────────
  // UTILITY
  // ─────────────────────────────────────────

  // Wipe everything — used in settings "Reset app"
  Future<void> clearAll() async {
    await _db!.delete(DbConstants.tableMonitors);
    await _db!.delete(DbConstants.tableAlerts);
    await _db!.delete(DbConstants.tableUsage);
  }

  // Close the database connection cleanly
  // Called when the app is shutting down
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}