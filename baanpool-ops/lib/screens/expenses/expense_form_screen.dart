import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _billableToPartner = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มค่าใช้จ่าย')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงิน (บาท) *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกจำนวนเงิน' : null,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'ประเภท'),
                items: const [
                  DropdownMenuItem(value: 'material', child: Text('วัสดุ')),
                  DropdownMenuItem(value: 'labor', child: Text('ค่าแรง')),
                  DropdownMenuItem(
                    value: 'contractor',
                    child: Text('ผู้รับเหมา'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                ],
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Upload receipt
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Image picker for receipt
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('อัปโหลดใบเสร็จ'),
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Save to Supabase
                    context.pop();
                  }
                },
                child: const Text('บันทึกค่าใช้จ่าย'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
