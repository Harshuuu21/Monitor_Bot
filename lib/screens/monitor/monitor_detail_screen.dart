import 'package:flutter/material.dart';
import 'package:monitor_bot/core/theme.dart';

class MonitorDetailScreen extends StatelessWidget {
  final String monitorId;
  const MonitorDetailScreen({super.key, required this.monitorId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitor Detail')),
      body: Center(
        child: Text('Monitor $monitorId detail coming soon',
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}