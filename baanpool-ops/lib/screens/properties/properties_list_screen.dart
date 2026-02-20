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

  /// Extract category prefix from property name (e.g. "BS-A1" → "BS-A")
  String _getCategoryPrefix(String name) {
    // Match pattern like "XX-YY" where YY starts with letters then numbers
    final match = RegExp(r'^([A-Za-z]+-[A-Za-z]+)').firstMatch(name);
    if (match != null) return match.group(1)!;
    // Fallback: take everything before the last digit sequence
    final fallback = RegExp(r'^(.+?)\d+$').firstMatch(name);
    if (fallback != null) return fallback.group(1)!;
    return 'อื่นๆ';
  }

  /// Get a display name for the category
  String _getCategoryDisplayName(String prefix) {
    switch (prefix.toUpperCase()) {
      case 'BS-A':
        return 'BS-A (บ้านเดี่ยว A)';
      case 'BS-HS':
        return 'BS-HS (โฮมสเตย์)';
      case 'BS-M':
        return 'BS-M (บ้านเดี่ยว M)';
      case 'BS-T':
        return 'BS-T (ทาวน์เฮาส์)';
      case 'PT-BT':
        return 'PT-BT (พูลวิลล่า)';
      default:
        return prefix;
    }
  }

  /// Group properties by category prefix
  Map<String, List<Property>> _groupProperties() {
    final grouped = <String, List<Property>>{};
    for (final p in _properties) {
      final prefix = _getCategoryPrefix(p.name);
      grouped.putIfAbsent(prefix, () => []).add(p);
    }
    // Sort keys
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    color: theme.colorScheme.outline,
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
          : RefreshIndicator(onRefresh: _load, child: _buildGroupedList(theme)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/properties/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupedList(ThemeData theme) {
    final grouped = _groupProperties();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          // Category header
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.villa,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_getCategoryDisplayName(entry.key)} (${entry.value.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: Divider(indent: 8)),
              ],
            ),
          ),
          // Property cards in this category
          ...entry.value.map(
            (p) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.home)),
                title: Text(p.name),
                subtitle: Text(
                  p.caretakerName != null
                      ? 'ผู้จัดการ: ${p.caretakerName}'
                      : 'ไม่มีผู้จัดการ',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/properties/${p.id}');
                  _load();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
