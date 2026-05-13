// tasks_provider.dart
// Manages the list of monitor tasks.
// Any screen that shows monitors listens to this.
// When tasks change, all listening screens rebuild.

import 'package:flutter/foundation.dart';
import 'package:monitor_bot/models/monitor_task.dart';
import 'package:monitor_bot/services/storage_service.dart';

// ChangeNotifier is Flutter's built-in observable.
// When we call notifyListeners(), every widget
// that's watching this provider rebuilds itself.
class TasksProvider extends ChangeNotifier {
  final _storage = StorageService();

  List<MonitorTask> _tasks = [];
  bool _loading = false;
  String? _error;

  // Getters — screens read data through these
  List<MonitorTask> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;
  int get activeCount =>
      _tasks.where((t) => t.status == MonitorStatus.active).length;

  // Load all tasks from database
  Future<void> init() async {
    _loading = true;
    notifyListeners(); // Tell screens we're loading

    try {
      _tasks = await _storage.getAllMonitors();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners(); // Tell screens we're done
  }

  // Add a new monitor
  Future<void> addTask(MonitorTask task) async {
    await _storage.insertMonitor(task);
    await init(); // Reload list
  }

  // Update an existing monitor
  Future<void> updateTask(MonitorTask task) async {
    await _storage.updateMonitor(task);
    await init();
  }

  // Delete a monitor
  Future<void> deleteTask(String id) async {
    await _storage.deleteMonitor(id);
    await init();
  }

  // Toggle active/paused
  Future<void> toggleTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    final newStatus = task.status == MonitorStatus.active
        ? MonitorStatus.paused
        : MonitorStatus.active;
    await _storage.updateMonitorStatus(id, newStatus);
    await init();
  }

  // Refresh from database
  Future<void> refresh() => init();
}