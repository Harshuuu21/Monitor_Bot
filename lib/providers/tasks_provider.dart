import 'package:flutter/foundation.dart';
import 'package:monitor_bot/models/monitor_task.dart';
import 'package:monitor_bot/services/storage_service.dart';

class TasksProvider extends ChangeNotifier {
  final _storage = StorageService();
  List<MonitorTask> _tasks = [];
  bool _loading = false;
  String? _error;

  List<MonitorTask> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;
  int get activeCount =>
      _tasks.where((t) => t.status == MonitorStatus.active).length;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      _tasks = await _storage.getAllMonitors();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addTask(MonitorTask task) async {
    await _storage.insertMonitor(task);
    await init();
  }

  Future<void> updateTask(MonitorTask task) async {
    await _storage.updateMonitor(task);
    await init();
  }

  Future<void> deleteTask(String id) async {
    await _storage.deleteMonitor(id);
    await init();
  }

  Future<void> toggleTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    final newStatus = task.status == MonitorStatus.active
        ? MonitorStatus.paused
        : MonitorStatus.active;
    await _storage.updateMonitorStatus(id, newStatus);
    await init();
  }

  Future<void> refresh() => init();
}
