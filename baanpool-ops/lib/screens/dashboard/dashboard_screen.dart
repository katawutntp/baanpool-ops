import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../services/auth_state_service.dart';

/// Dashboard — งานด่วน, งานวันนี้, PM ใกล้ครบ, Snapshot ค่าใช้จ่าย
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ด'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await AuthStateService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Reload data from Supabase
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Cards Row
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'งานด่วน',
                    value: '–',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.urgentColor,
                    onTap: () => context.go('/work-orders'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'งานวันนี้',
                    value: '–',
                    icon: Icons.today,
                    color: AppTheme.primaryColor,
                    onTap: () => context.go('/work-orders'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'PM ใกล้ครบ',
                    value: '–',
                    icon: Icons.schedule,
                    color: AppTheme.warningColor,
                    onTap: () => context.go('/pm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'ค่าใช้จ่ายเดือนนี้',
                    value: '–',
                    icon: Icons.receipt_long,
                    color: AppTheme.secondaryColor,
                    onTap: () => context.go('/expenses'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Work Orders
            _SectionHeader(
              title: 'งานล่าสุด',
              onSeeAll: () => context.go('/work-orders'),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'ยังไม่มีข้อมูล\nเชื่อมต่อ Supabase เพื่อเริ่มใช้งาน',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('ดูทั้งหมด')),
      ],
    );
  }
}
