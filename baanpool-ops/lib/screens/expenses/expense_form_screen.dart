import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService(Supabase.instance.client);
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'material';
  bool _billableToPartner = false;
  bool _saving = false;
  bool _loading = true;

  String? _selectedWorkOrderId;
  List<Map<String, dynamic>> _workOrders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _workOrders = await _service.getWorkOrders();
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
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกใบงาน')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Get property_id from the selected work order
      final selectedWO = _workOrders.firstWhere(
        (wo) => wo['id'] == _selectedWorkOrderId,
      );

      await _service.createExpense({
        'work_order_id': _selectedWorkOrderId,
        'property_id': selectedWO['property_id'],
        'amount': double.parse(_amountController.text.trim()),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category': _category,
        'billable_to_partner': _billableToPartner,
        'expense_date': DateTime.now().toIso8601String().split('T').first,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกค่าใช้จ่ายสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกล้มเหลว: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มค่าใช้จ่าย')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Work Order selection
                    DropdownButtonFormField<String>(
                      value: _selectedWorkOrderId,
                      decoration: const InputDecoration(
                        labelText: 'ใบงาน *',
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      items: _workOrders.map((wo) {
                        return DropdownMenuItem(
                          value: wo['id'] as String,
                          child: Text(
                            wo['title'] as String? ?? 'ไม่มีชื่อ',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedWorkOrderId = v),
                      validator: (v) => v == null ? 'กรุณาเลือกใบงาน' : null,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนเงิน (บาท) *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกจำนวนเงิน';
                        if (double.tryParse(v) == null) return 'กรุณากรอกตัวเลข';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'ประเภท',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'material', child: Text('วัสดุ')),
                        DropdownMenuItem(value: 'labor', child: Text('ค่าแรง')),
                        DropdownMenuItem(
                          value: 'contractor',
                          child: Text('ผู้รับเหมา'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Billable to partner
                    SwitchListTile(
                      title: const Text('เบิกจาก Partner ได้'),
                      value: _billableToPartner,
                      onChanged: (v) => setState(() => _billableToPartner = v),
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
                          : const Text('บันทึกค่าใช้จ่าย'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
