import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/property.dart';
import '../../services/supabase_service.dart';

class PropertiesListScreen extends StatefulWidget {
  const PropertiesListScreen({super.key});

  @override
  State<PropertiesListScreen> createState() => _PropertiesListScreenState();
}

class _PropertiesListScreenState extends State<PropertiesListScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  List<Property> _properties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getProperties();
      _properties = data.map((e) => Property.fromJson(e)).toList();
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
      appBar: AppBar(title: const Text('รายชื่อบ้าน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _properties.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีข้อมูลบ้าน'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/properties/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มบ้าน'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _properties.length,
                itemBuilder: (context, index) {
                  final p = _properties[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.home)),
                      title: Text(p.name),
                      subtitle: Text(p.address ?? 'ไม่มีที่อยู่'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await context.push('/properties/${p.id}');
                        _load(); // refresh after returning
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/properties/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
