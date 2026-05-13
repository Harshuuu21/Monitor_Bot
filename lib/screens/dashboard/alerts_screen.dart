import 'package:flutter/material.dart';
import 'package:monitor_bot/core/theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const Center(
        child: Text('Alerts coming soon',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}