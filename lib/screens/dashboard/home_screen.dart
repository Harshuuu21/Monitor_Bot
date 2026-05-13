// home_screen.dart
// The main dashboard screen.
// Shows all monitors, their status,
// last check time, and quick actions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitor_bot/core/constants.dart';
import 'package:monitor_bot/core/router.dart';
import 'package:monitor_bot/core/theme.dart';
import 'package:monitor_bot/models/monitor_task.dart';
import 'package:monitor_bot/providers/tasks_provider.dart';
import 'package:monitor_bot/providers/usage_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedTab == 0
          ? const _MonitorsTab()
          : _selectedTab == 1
          ? const _AlertsTabPlaceholder()
          : const _UsageTabPlaceholder(),

      // ── Bottom navigation ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) {
          if (i == 1) {
            context.goAlerts();
          } else if (i == 2) {
            context.goUsage();
          } else {
            setState(() => _selectedTab = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Monitors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Usage',
          ),
        ],
      ),

      // ── Add monitor FAB ──
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goAddMonitor(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MONITORS TAB
// The main content — list of all monitors
// ─────────────────────────────────────────
class _MonitorsTab extends StatelessWidget {
  const _MonitorsTab();

  @override
  Widget build(BuildContext context) {
    final tasksProvider = context.watch<TasksProvider>();
    final usageProvider = context.watch<UsageProvider>();

    return SafeArea(
      child: RefreshIndicator(
        // Pull down to refresh the list
        onRefresh: () async {
          await tasksProvider.refresh();
          await usageProvider.refresh();
        },
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── App bar ──
            SliverAppBar(
              floating: true,
              snap: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.appName,
                      style:
                      Theme.of(context).textTheme.headlineSmall),
                  Text(
                    '${tasksProvider.activeCount} active monitor${tasksProvider.activeCount == 1 ? '' : 's'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.goSettings(),
                ),
              ],
            ),

            // ── Usage warning banner ──
            if (usageProvider.isWarning)
              SliverToBoxAdapter(
                child: _UsageWarningBanner(provider: usageProvider),
              ),

            // ── Loading state ──
            if (tasksProvider.loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              )

            // ── Empty state ──
            else if (tasksProvider.tasks.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(),
              )

            // ── Monitor list ──
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final task = tasksProvider.tasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.md),
                        child: _MonitorCard(task: task),
                      );
                    },
                    childCount: tasksProvider.tasks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// USAGE WARNING BANNER
// Shows at top when approaching free limit
// ─────────────────────────────────────────
class _UsageWarningBanner extends StatelessWidget {
  final UsageProvider provider;
  const _UsageWarningBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isOver = provider.isOverLimit;
    final color = isOver ? AppColors.error : AppColors.warning;
    final message = isOver
        ? AppStrings.warningOverLimit
        : AppStrings.warningNearLimit;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.pause_circle : Icons.warning_amber,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: AppTextStyles.cardSubtitle
                    .copyWith(color: color)),
          ),
          TextButton(
            onPressed: () => context.goUsage(),
            child: Text('View',
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// MONITOR CARD
// One card per monitor in the list
// ─────────────────────────────────────────
class _MonitorCard extends StatelessWidget {
  final MonitorTask task;
  const _MonitorCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final tasksProvider = context.read<TasksProvider>();

    // Status color
    Color statusColor;
    switch (task.status) {
      case MonitorStatus.active:
        statusColor = AppColors.success;
        break;
      case MonitorStatus.paused:
        statusColor = AppColors.textHint;
        break;
      case MonitorStatus.error:
        statusColor = AppColors.error;
        break;
      case MonitorStatus.limitHit:
        statusColor = AppColors.warning;
        break;
    }

    return GestureDetector(
      onTap: () => context.goMonitorDetail(task.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                // Status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Name
                Expanded(
                  child: Text(task.name,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),

                // Pause/resume toggle
                GestureDetector(
                  onTap: () => tasksProvider.toggleTask(task.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: task.isActive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.isActive ? 'Active' : 'Paused',
                      style: AppTextStyles.badge.copyWith(
                        color: task.isActive
                            ? AppColors.success
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Condition ──
            Text(
              task.condition,
              style: AppTextStyles.cardSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Footer row ──
            Row(
              children: [
                // Provider badge
                _InfoChip(
                  icon: Icons.smart_toy_outlined,
                  label: task.provider.name.toUpperCase(),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Interval
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: 'Every ${task.intervalMinutes}m',
                ),
                const Spacer(),

                // Last checked
                Text(
                  task.lastCheckedLabel,
                  style: AppTextStyles.cardSubtitle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(label,
              style:
              AppTextStyles.badge.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// EMPTY STATE
// Shown when user has no monitors yet
// ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.noMonitors,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.noMonitorsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.goAddMonitor(),
              icon: const Icon(Icons.add),
              label: const Text('Add your first monitor'),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder tabs for nav routing
class _AlertsTabPlaceholder extends StatelessWidget {
  const _AlertsTabPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _UsageTabPlaceholder extends StatelessWidget {
  const _UsageTabPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox();
}