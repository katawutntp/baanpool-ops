import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/work_order.dart';
import '../../services/supabase_service.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  final String workOrderId;

  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  WorkOrder? _workOrder;
  String? _propertyName;
  String? _technicianName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getWorkOrders();
      final match = data.where((d) => d['id'] == widget.workOrderId);
      if (match.isNotEmpty) {
        _workOrder = WorkOrder.fromJson(match.first);

        // Load property name
        try {
          final prop = await _service.getProperty(_workOrder!.propertyId);
          _propertyName = prop['name'] as String?;
        } catch (_) {}

        // Load technician name
        if (_workOrder!.assignedTo != null) {
          try {
            final user = await _service.getUser(_workOrder!.assignedTo!);
            _technicianName = user?['full_name'] as String?;
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _service.updateWorkOrderStatus(widget.workOrderId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัปเดตสถานะสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตล้มเหลว: $e')),
        );
      }
    }
  }

  void _showStatusDialog() {
    if (_workOrder == null) return;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('เปลี่ยนสถานะ'),
        children: [
          for (final status in WorkOrderStatus.values)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                final value =
                    status == WorkOrderStatus.inProgress
                        ? 'in_progress'
                        : status.name;
                _updateStatus(value);
              },
              child: Row(
                children: [
                  Icon(_statusIcon(status), color: _statusColor(status)),
                  const SizedBox(width: 12),
                  Text(
                    status.displayName,
                    style: TextStyle(
                      fontWeight: _workOrder!.status == status
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (_workOrder!.status == status) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดใบงาน')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_workOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดใบงาน')),
        body: const Center(child: Text('ไม่พบข้อมูลใบงาน')),
      );
    }

    final wo = _workOrder!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดใบงาน'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title + Priority
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            wo.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _priorityBadge(wo.priority),
                      ],
                    ),
                    const Divider(height: 24),

                    // Status
                    _infoRow(
                      Icons.info_outline,
                      'สถานะ',
                      wo.status.displayName,
                      valueColor: _statusColor(wo.status),
                    ),

                    // Property
                    if (_propertyName != null)
                      _infoRow(Icons.home, 'บ้าน', _propertyName!),

                    // Technician
                    if (_technicianName != null)
                      _infoRow(Icons.engineering, 'ช่าง', _technicianName!),

                    // Priority
                    _infoRow(Icons.flag, 'ความเร่งด่วน', wo.priority.displayName),

                    // Created date
                    _infoRow(
                      Icons.calendar_today,
                      'สร้างเมื่อ',
                      '${wo.createdAt.day}/${wo.createdAt.month}/${wo.createdAt.year} ${wo.createdAt.hour.toString().padLeft(2, '0')}:${wo.createdAt.minute.toString().padLeft(2, '0')}',
                    ),

                    // Due date
                    if (wo.dueDate != null)
                      _infoRow(
                        Icons.event,
                        'กำหนดส่ง',
                        '${wo.dueDate!.day}/${wo.dueDate!.month}/${wo.dueDate!.year}',
                        valueColor: wo.isOverdue ? Colors.red : null,
                      ),

                    // Completed at
                    if (wo.completedAt != null)
                      _infoRow(
                        Icons.check_circle,
                        'เสร็จเมื่อ',
                        '${wo.completedAt!.day}/${wo.completedAt!.month}/${wo.completedAt!.year}',
                        valueColor: Colors.green,
                      ),
                  ],
                ),
              ),
            ),

            // Description
            if (wo.description != null && wo.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายละเอียด',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(wo.description!),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            if (wo.status != WorkOrderStatus.completed &&
                wo.status != WorkOrderStatus.cancelled) ...[
              FilledButton.icon(
                onPressed: _showStatusDialog,
                icon: const Icon(Icons.edit),
                label: const Text('เปลี่ยนสถานะ'),
              ),
              const SizedBox(height: 8),
              if (wo.status == WorkOrderStatus.open)
                FilledButton.tonalIcon(
                  onPressed: () => _updateStatus('in_progress'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('เริ่มดำเนินการ'),
                ),
              if (wo.status == WorkOrderStatus.inProgress)
                FilledButton.tonalIcon(
                  onPressed: () => _updateStatus('completed'),
                  icon: const Icon(Icons.check),
                  label: const Text('ทำเสร็จแล้ว'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityBadge(WorkOrderPriority priority) {
    Color color;
    String label;
    switch (priority) {
      case WorkOrderPriority.urgent:
        color = Colors.red;
        label = 'เร่งด่วน';
      case WorkOrderPriority.high:
        color = Colors.orange;
        label = 'สูง';
      case WorkOrderPriority.medium:
        color = Colors.blue;
        label = 'ปกติ';
      case WorkOrderPriority.low:
        color = Colors.grey;
        label = 'ต่ำ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Color _statusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return Colors.blue;
      case WorkOrderStatus.inProgress:
        return Colors.orange;
      case WorkOrderStatus.completed:
        return Colors.green;
      case WorkOrderStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _statusIcon(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return Icons.fiber_new;
      case WorkOrderStatus.inProgress:
        return Icons.autorenew;
      case WorkOrderStatus.completed:
        return Icons.check_circle;
      case WorkOrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}
