import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pm_schedule.dart';
import '../../services/supabase_service.dart';

class PmScheduleScreen extends StatefulWidget {
  const PmScheduleScreen({super.key});

  @override
  State<PmScheduleScreen> createState() => _PmScheduleScreenState();
}

class _PmScheduleScreenState extends State<PmScheduleScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  List<PmSchedule> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getPmSchedules();
      _schedules = data.map((e) => PmSchedule.fromJson(e)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Preventive Maintenance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 64,
                          color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('ยังไม่มี PM Schedule'),
                      const SizedBox(height: 8),
                      const Text('เพิ่ม PM Schedule ได้ที่หน้าอุปกรณ์ของแต่ละบ้าน',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final s = _schedules[index];
                      return _buildScheduleCard(s);
                    },
                  ),
                ),
    );
  }

  Widget _buildScheduleCard(PmSchedule s) {
    final theme = Theme.of(context);
    final daysUntilDue = s.nextDueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = daysUntilDue <= 7 && daysUntilDue >= 0;

    Color statusColor = theme.colorScheme.primary;
    String statusText = 'อีก $daysUntilDue วัน';
    if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'เกินกำหนด ${-daysUntilDue} วัน';
    } else if (isDueSoon) {
      statusColor = Colors.orange;
      statusText = 'อีก $daysUntilDue วัน';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: s.assetId != null
            ? () => context.push('/assets/${s.assetId}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.title, style: theme.textTheme.titleSmall),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
              if (s.description != null) ...[
                const SizedBox(height: 4),
                Text(s.description!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  _chip(Icons.repeat, s.frequency.displayName),
                  _chip(Icons.calendar_today,
                      '${s.nextDueDate.day}/${s.nextDueDate.month}/${s.nextDueDate.year}'),
                  if (s.assignedToName != null)
                    _chip(Icons.person, s.assignedToName!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
