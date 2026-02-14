import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/property.dart';
import '../../models/asset.dart';
import '../../services/supabase_service.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  Property? _property;
  List<Asset> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pData = await _service.getProperty(widget.propertyId);
      final aData = await _service.getAssets(propertyId: widget.propertyId);
      _property = Property.fromJson(pData);
      _assets = aData.map((e) => Asset.fromJson(e)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteProperty() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันลบบ้าน'),
        content: const Text(
          'ลบบ้านนี้จะลบอุปกรณ์และข้อมูลที่เกี่ยวข้องทั้งหมด',
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
      await _service.deleteProperty(widget.propertyId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบบ้านสำเร็จ')));
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

  Future<void> _showAddAssetDialog() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มอุปกรณ์'),
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
                decoration: const InputDecoration(
                  labelText: 'ประเภท',
                  hintText: 'เช่น HVAC, ประปา, ไฟฟ้า',
                ),
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
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );

    if (result != true) return;
    try {
      await _service.createAsset({
        'property_id': widget.propertyId,
        'name': nameCtrl.text.trim(),
        'category': categoryCtrl.text.trim().isEmpty
            ? null
            : categoryCtrl.text.trim(),
        'brand': brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
        'model': modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เพิ่มอุปกรณ์สำเร็จ')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เพิ่มอุปกรณ์ล้มเหลว: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดบ้าน')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดบ้าน')),
        body: const Center(child: Text('ไม่พบข้อมูลบ้าน')),
      );
    }

    final p = _property!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/properties/${p.id}/edit');
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteProperty,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Property info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ข้อมูลบ้าน', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (p.address != null)
                      _infoRow(Icons.location_on, 'ที่อยู่', p.address!),
                    if (p.ownerName != null)
                      _infoRow(Icons.person, 'เจ้าของ', p.ownerName!),
                    if (p.ownerContact != null)
                      _infoRow(Icons.phone, 'เบอร์ติดต่อ', p.ownerContact!),
                    if (p.notes != null)
                      _infoRow(Icons.notes, 'หมายเหตุ', p.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Assets section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'อุปกรณ์ (${_assets.length})',
                  style: theme.textTheme.titleMedium,
                ),
                FilledButton.tonalIcon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มอุปกรณ์'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_assets.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text('ยังไม่มีอุปกรณ์'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._assets.map(
                (a) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_categoryIcon(a.category)),
                    ),
                    title: Text(a.name),
                    subtitle: Text(
                      [
                        if (a.category != null) a.category!,
                        if (a.brand != null) a.brand!,
                      ].join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/assets/${a.id}');
                      _load();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAssetDialog,
        child: const Icon(Icons.add),
      ),
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

  IconData _categoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'hvac':
        return Icons.ac_unit;
      case 'ประปา':
      case 'plumbing':
        return Icons.water_drop;
      case 'ไฟฟ้า':
      case 'electrical':
        return Icons.electrical_services;
      case 'สระว่ายน้ำ':
      case 'pool':
        return Icons.pool;
      default:
        return Icons.build;
    }
  }
}
