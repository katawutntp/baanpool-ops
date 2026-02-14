import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

/// Screen for creating / editing a property
class PropertyFormScreen extends StatefulWidget {
  final String? propertyId; // null = create mode

  const PropertyFormScreen({super.key, this.propertyId});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService(Supabase.instance.client);
  bool _saving = false;
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerContactCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool get _isEdit => widget.propertyId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProperty();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerContactCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getProperty(widget.propertyId!);
      _nameCtrl.text = data['name'] ?? '';
      _addressCtrl.text = data['address'] ?? '';
      _ownerNameCtrl.text = data['owner_name'] ?? '';
      _ownerContactCtrl.text = data['owner_contact'] ?? '';
      _notesCtrl.text = data['notes'] ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      'owner_name': _ownerNameCtrl.text.trim().isEmpty
          ? null
          : _ownerNameCtrl.text.trim(),
      'owner_contact': _ownerContactCtrl.text.trim().isEmpty
          ? null
          : _ownerContactCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      if (_isEdit) {
        await _service.updateProperty(widget.propertyId!, data);
      } else {
        await _service.createProperty(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'อัพเดทบ้านสำเร็จ' : 'เพิ่มบ้านสำเร็จ'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'แก้ไขบ้าน' : 'เพิ่มบ้านใหม่')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อบ้าน *',
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'กรุณากรอกชื่อบ้าน'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ที่อยู่',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อเจ้าของ',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerContactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'เบอร์ติดต่อเจ้าของ',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'หมายเหตุ',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'บันทึก' : 'เพิ่มบ้าน'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
