import 'package:flutter/material.dart';
import 'package:monitor_bot/core/theme.dart';

class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage & Costs')),
      body: const Center(
        child: Text(
          'Usage dashboard coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
