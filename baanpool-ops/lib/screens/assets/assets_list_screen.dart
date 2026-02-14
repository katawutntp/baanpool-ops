import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/asset.dart';
import '../../services/supabase_service.dart';

class AssetsListScreen extends StatefulWidget {
  const AssetsListScreen({super.key});

  @override
  State<AssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends State<AssetsListScreen> {
  final _service = SupabaseService(Supabase.instance.client);
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
      final data = await _service.getAssets();
      _assets = data.map((e) => Asset.fromJson(e)).toList();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('อุปกรณ์ทั้งหมด')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีข้อมูลอุปกรณ์'),
                  const SizedBox(height: 8),
                  const Text(
                    'เพิ่มอุปกรณ์ได้ที่หน้ารายละเอียดบ้าน',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  final a = _assets[index];
                  return Card(
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
                  );
                },
              ),
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
