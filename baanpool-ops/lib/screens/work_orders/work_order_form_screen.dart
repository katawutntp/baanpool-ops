import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/line_notify_service.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({super.key});

  @override
  State<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends State<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService(Supabase.instance.client);
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';
  String? _selectedPropertyId;
  String? _selectedTechnicianId;
  bool _saving = false;
  bool _loading = true;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _technicians = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getProperties(),
        _service.getUsers(), // Get all users for assignment
      ]);
      _properties = results[0];
      _technicians = results[1];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'property_id': _selectedPropertyId,
        'priority': _priority,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'assigned_to': _selectedTechnicianId,
        'status': 'open',
      };

      await _service.createWorkOrder(data);

      // Send LINE notification to assigned technician
      if (_selectedTechnicianId != null && _selectedPropertyId != null) {
        final property = _properties.firstWhere(
          (p) => p['id'] == _selectedPropertyId,
          orElse: () => {'name': ''},
        );
        await LineNotifyService().notifyTechnicianAssigned(
          technicianUserId: _selectedTechnicianId!,
          workOrderTitle: _titleController.text.trim(),
          propertyName: property['name'] ?? '',
          priority: _priority,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('สร้างใบงานสำเร็จ')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('สร้างใบงานล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างใบงานใหม่')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'หัวข้องาน *',
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'กรุณากรอกหัวข้องาน' : null,
                    ),
                    const SizedBox(height: 16),

                    // Property dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPropertyId,
                      decoration: const InputDecoration(
                        labelText: 'บ้าน *',
                        prefixIcon: Icon(Icons.home),
                      ),
                      items: _properties
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPropertyId = v),
                      validator: (v) => v == null ? 'กรุณาเลือกบ้าน' : null,
                    ),
                    const SizedBox(height: 16),

                    // Technician dropdown
                    DropdownButtonFormField<String?>(
                      value: _selectedTechnicianId,
                      decoration: const InputDecoration(
                        labelText: 'มอบหมายช่าง',
                        prefixIcon: Icon(Icons.engineering),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ยังไม่ระบุ'),
                        ),
                        ..._technicians.map(
                          (t) => DropdownMenuItem(
                            value: t['id'] as String,
                            child: Text('${t['full_name']} (${t['role']})'),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedTechnicianId = v),
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'ความสำคัญ',
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('ต่ำ')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('ปานกลาง'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('สูง')),
                        DropdownMenuItem(value: 'urgent', child: Text('ด่วน')),
                      ],
                      onChanged: (v) =>
                          setState(() => _priority = v ?? 'medium'),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Photo attachment
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Image picker
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('แนบรูปภาพ'),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('บันทึกใบงาน'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
