import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/contractor.dart';
import '../../services/supabase_service.dart';

/// รายชื่อช่างภายนอก / ผู้รับเหมา
class ContractorsListScreen extends StatefulWidget {
  const ContractorsListScreen({super.key});

  @override
  State<ContractorsListScreen> createState() => _ContractorsListScreenState();
}

class _ContractorsListScreenState extends State<ContractorsListScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  List<Contractor> _contractors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getContractors();
      _contractors = data.map((e) => Contractor.fromJson(e)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showAddEditDialog({Contractor? contractor}) {
    final nameCtrl = TextEditingController(text: contractor?.name ?? '');
    final phoneCtrl = TextEditingController(text: contractor?.phone ?? '');
    final emailCtrl = TextEditingController(text: contractor?.email ?? '');
    final specialtyCtrl = TextEditingController(
      text: contractor?.specialty ?? '',
    );
    final companyCtrl = TextEditingController(
      text: contractor?.companyName ?? '',
    );
    final notesCtrl = TextEditingController(text: contractor?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contractor == null ? 'เพิ่มช่างภายนอก' : 'แก้ไขข้อมูลช่าง'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'เบอร์โทร',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ช่องทางติดต่ออื่นๆ',
                    prefixIcon: Icon(Icons.contact_page),
                    hintText: 'เช่น LINE ID, Facebook',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: specialtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ความชำนาญ',
                    prefixIcon: Icon(Icons.build),
                    hintText: 'เช่น ไฟฟ้า, ประปา, แอร์',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'บริษัท',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              try {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  'specialty': specialtyCtrl.text.trim().isEmpty
                      ? null
                      : specialtyCtrl.text.trim(),
                  'company_name': companyCtrl.text.trim().isEmpty
                      ? null
                      : companyCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                };

                if (contractor == null) {
                  await _service.createContractor(data);
                } else {
                  await _service.updateContractor(contractor.id, data);
                }

                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        contractor == null
                            ? 'เพิ่มช่างภายนอกสำเร็จ'
                            : 'แก้ไขข้อมูลช่างสำเร็จ',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
                  );
                }
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Contractor contractor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบช่างภายนอก'),
        content: Text('ต้องการลบ "${contractor.name}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteContractor(contractor.id);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ลบ ${contractor.name} แล้ว'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
                }
              }
            },
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ช่างภายนอก / ผู้รับเหมา')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contractors.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.contacts_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีข้อมูลช่างภายนอก',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มช่างภายนอก'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _contractors.length,
                itemBuilder: (context, index) {
                  final c = _contractors[index];
                  return _buildContractorCard(c, theme);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มช่างภายนอก'),
      ),
    );
  }

  Widget _buildContractorCard(Contractor c, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/contractors/${c.id}');
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.engineering,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (c.specialty != null)
                          Text(
                            c.specialty!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (c.rating != null) _buildRating(c.rating!),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showAddEditDialog(contractor: c);
                      if (v == 'delete') _showDeleteDialog(c);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('แก้ไข'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text(
                            'ลบ',
                            style: TextStyle(color: Colors.red),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (c.phone != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(c.phone!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  if (c.companyName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(c.companyName!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  if (!c.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ไม่ใช้งาน',
                        style: TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }
}
