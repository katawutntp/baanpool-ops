import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/asset.dart';
import '../../models/pm_schedule.dart';
import '../../services/supabase_service.dart';

class AssetDetailScreen extends StatefulWidget {
  final String assetId;

  const AssetDetailScreen({super.key, required this.assetId});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  Asset? _asset;
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
      final aData = await _service.getAsset(widget.assetId);
      _asset = Asset.fromJson(aData);
      final sData = await _service.getPmSchedules(assetId: widget.assetId);
      _schedules = sData.map((e) => PmSchedule.fromJson(e)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteAsset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบอุปกรณ์'),
        content: const Text(
          'ลบอุปกรณ์นี้จะลบ PM Schedule ที่เกี่ยวข้องทั้งหมด',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteAsset(widget.assetId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบอุปกรณ์สำเร็จ')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบล้มเหลว: $e')));
      }
    }
  }

  Future<void> _showEditAssetDialog() async {
    if (_asset == null) return;
    final a = _asset!;
    final nameCtrl = TextEditingController(text: a.name);
    final categoryCtrl = TextEditingController(text: a.category ?? '');
    final brandCtrl = TextEditingController(text: a.brand ?? '');
    final modelCtrl = TextEditingController(text: a.model ?? '');
    final notesCtrl = TextEditingController(text: a.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขอุปกรณ์'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'ชื่ออุปกรณ์ *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'ประเภท'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brandCtrl,
                decoration: const InputDecoration(labelText: 'ยี่ห้อ'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'รุ่น'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      await _service.updateAsset(widget.assetId, {
        'name': nameCtrl.text.trim(),
        'category': categoryCtrl.text.trim().isEmpty
            ? null
            : categoryCtrl.text.trim(),
        'brand': brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
        'model': modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('แก้ไขล้มเหลว: $e')));
      }
    }
  }

  Future<void> _showAddScheduleDialog() async {
    if (_asset == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    PmFrequency selectedFreq = PmFrequency.monthly;
    DateTime nextDue = DateTime.now().add(const Duration(days: 30));
    String? selectedTechId;

    // Load technicians
    List<Map<String, dynamic>> technicians = [];
    try {
      technicians = await _service.getTechnicians();
    } catch (_) {}

    // Also load all users as potential assignees
    if (technicians.isEmpty) {
      try {
        technicians = await _service.getUsers();
      } catch (_) {}
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('เพิ่ม PM Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่องาน PM *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PmFrequency>(
                  value: selectedFreq,
                  decoration: const InputDecoration(labelText: 'ความถี่'),
                  items: PmFrequency.values
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedFreq = v);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('วันครบกำหนดถัดไป'),
                  subtitle: Text(
                    '${nextDue.day}/${nextDue.month}/${nextDue.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDue,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => nextDue = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedTechId,
                  decoration: const InputDecoration(labelText: 'มอบหมายช่าง'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                    ...technicians.map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(
                          t['full_name'] as String? ?? t['email'] as String,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setDialogState(() => selectedTechId = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('เพิ่ม'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      await _service.createPmSchedule({
        'property_id': _asset!.propertyId,
        'asset_id': widget.assetId,
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty
            ? null
            : descCtrl.text.trim(),
        'frequency': selectedFreq.name,
        'next_due_date': nextDue.toIso8601String().split('T').first,
        'assigned_to': selectedTechId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่ม PM Schedule สำเร็จ')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่ม PM Schedule ล้มเหลว: $e')),
        );
      }
    }
  }

  void _createWorkOrderFromPm(PmSchedule s) {
    final dateStr =
        '${s.nextDueDate.day}/${s.nextDueDate.month}/${s.nextDueDate.year}';
    final description =
        'PM: ${s.title}\nกำหนด: $dateStr\nความถี่: ${s.frequency.displayName}'
        '${s.description != null ? "\nรายละเอียด: ${s.description}" : ""}';

    final queryParams = <String, String>{
      'title': s.title,
      'propertyId': s.propertyId,
      'description': description,
      'assetId': widget.assetId,
    };
    if (s.assignedTo != null) {
      queryParams['technicianId'] = s.assignedTo!;
    }

    final uri = Uri(path: '/work-orders/new', queryParameters: queryParams);
    context.push(uri.toString());
  }

  Future<void> _deleteSchedule(PmSchedule s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบ PM Schedule'),
        content: Text('ลบ "${s.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deletePmSchedule(s.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบล้มเหลว: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดอุปกรณ์')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดอุปกรณ์')),
        body: const Center(child: Text('ไม่พบข้อมูลอุปกรณ์')),
      );
    }

    final a = _asset!;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditAssetDialog,
          ),
          IconButton(icon: const Icon(Icons.delete), onPressed: _deleteAsset),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Asset info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ข้อมูลอุปกรณ์', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (a.category != null)
                      _infoRow(Icons.category, 'ประเภท', a.category!),
                    if (a.brand != null)
                      _infoRow(Icons.business, 'ยี่ห้อ', a.brand!),
                    if (a.model != null)
                      _infoRow(Icons.info_outline, 'รุ่น', a.model!),
                    if (a.installDate != null)
                      _infoRow(
                        Icons.calendar_today,
                        'วันติดตั้ง',
                        '${a.installDate!.day}/${a.installDate!.month}/${a.installDate!.year}',
                      ),
                    if (a.warrantyExpiry != null)
                      _infoRow(
                        a.isWarrantyExpired
                            ? Icons.warning
                            : Icons.verified_user,
                        'ประกัน',
                        '${a.warrantyExpiry!.day}/${a.warrantyExpiry!.month}/${a.warrantyExpiry!.year}'
                            '${a.isWarrantyExpired ? " (หมดแล้ว)" : ""}',
                      ),
                    if (a.notes != null)
                      _infoRow(Icons.notes, 'หมายเหตุ', a.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // PM Schedules section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PM Schedule (${_schedules.length})',
                  style: theme.textTheme.titleMedium,
                ),
                FilledButton.tonalIcon(
                  onPressed: _showAddScheduleDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่ม Schedule'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_schedules.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text('ยังไม่มี PM Schedule'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._schedules.map((s) => _buildScheduleCard(s)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildScheduleCard(PmSchedule s) {
    final theme = Theme.of(context);
    final daysUntilDue = s.nextDueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = daysUntilDue <= 7 && daysUntilDue >= 0;

    Color statusColor = theme.colorScheme.primary;
    String statusText = '$daysUntilDue วัน';
    if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'เกินกำหนด ${-daysUntilDue} วัน';
    } else if (isDueSoon) {
      statusColor = Colors.orange;
      statusText = 'อีก $daysUntilDue วัน';
    }

    return Card(
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteSchedule(s),
                ),
              ],
            ),
            if (s.isDueSoon || daysUntilDue < 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _createWorkOrderFromPm(s),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('สร้างใบงาน'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: statusColor,
                    side: BorderSide(color: statusColor),
                  ),
                ),
              ),
            ],
            if (s.description != null) ...[
              const SizedBox(height: 4),
              Text(s.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                _chip(Icons.repeat, s.frequency.displayName),
                _chip(
                  Icons.calendar_today,
                  '${s.nextDueDate.day}/${s.nextDueDate.month}/${s.nextDueDate.year}',
                ),
                if (s.assignedToName != null)
                  _chip(Icons.person, s.assignedToName!),
                if (s.assignedTo != null && s.assignedToName == null)
                  _chip(Icons.person, 'มอบหมายแล้ว'),
              ],
            ),
          ],
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
