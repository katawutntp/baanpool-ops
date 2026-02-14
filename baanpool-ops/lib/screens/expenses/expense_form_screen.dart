import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class ExpenseFormScreen extends StatefulWidget {
  final String? workOrderId;

  const ExpenseFormScreen({super.key, this.workOrderId});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService(Supabase.instance.client);
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'material';
  bool _saving = false;
  bool _loading = true;

  String? _selectedWorkOrderId;
  List<Map<String, dynamic>> _workOrders = [];

  // Receipt image
  final ImagePicker _picker = ImagePicker();
  XFile? _receiptImage;
  Uint8List? _receiptBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _workOrders = await _service.getWorkOrders();
      // Pre-select work order if passed via query param
      if (widget.workOrderId != null) {
        _selectedWorkOrderId = widget.workOrderId;
      }
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
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() {
        _receiptImage = image;
        _receiptBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เลือกรูปภาพล้มเหลว: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkOrderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกใบงาน')));
      return;
    }

    setState(() => _saving = true);
    try {
      // Upload receipt image if selected
      String? receiptUrl;
      if (_receiptBytes != null && _receiptImage != null) {
        final ext = _receiptImage!.name.split('.').last;
        final path = 'receipts/${DateTime.now().millisecondsSinceEpoch}.$ext';
        try {
          receiptUrl = await _service.uploadFile(
            'photos',
            path,
            _receiptBytes!,
          );
        } catch (e) {
          debugPrint('Upload receipt failed: $e');
        }
      }

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
        'expense_date': DateTime.now().toIso8601String().split('T').first,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
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
                      onChanged: (v) =>
                          setState(() => _selectedWorkOrderId = v),
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
                        if (double.tryParse(v) == null)
                          return 'กรุณากรอกตัวเลข';
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
                        DropdownMenuItem(
                          value: 'material',
                          child: Text('วัสดุ'),
                        ),
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

                    // Receipt image
                    if (_receiptBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.memory(
                              _receiptBytes!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _receiptImage = null;
                                  _receiptBytes = null;
                                }),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.receipt),
                      label: Text(
                        _receiptBytes == null
                            ? 'แนบรูปใบเสร็จ'
                            : 'เปลี่ยนรูปใบเสร็จ',
                      ),
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
