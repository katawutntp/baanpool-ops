import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkOrderFormScreen extends StatefulWidget {
  const WorkOrderFormScreen({super.key});

  @override
  State<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends State<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างใบงานใหม่')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'หัวข้องาน *'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกหัวข้องาน' : null,
              ),
              const SizedBox(height: 16),

              // Property dropdown placeholder
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'บ้าน *'),
                items: const [],
                onChanged: (v) {},
                validator: (v) => v == null ? 'กรุณาเลือกบ้าน' : null,
              ),
              const SizedBox(height: 16),

              // Priority
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'ความสำคัญ'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('ต่ำ')),
                  DropdownMenuItem(value: 'medium', child: Text('ปานกลาง')),
                  DropdownMenuItem(value: 'high', child: Text('สูง')),
                  DropdownMenuItem(value: 'urgent', child: Text('ด่วน')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Save to Supabase
                    context.pop();
                  }
                },
                child: const Text('บันทึกใบงาน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
