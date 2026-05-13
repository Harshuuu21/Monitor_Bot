import 'package:flutter/material.dart';
import 'package:monitor_bot/core/theme.dart';

class AddMonitorScreen extends StatelessWidget {
  const AddMonitorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Monitor')),
      body: const Center(
        child: Text('Add monitor coming soon',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}