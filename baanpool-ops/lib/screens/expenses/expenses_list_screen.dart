import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/expense.dart';
import '../../services/supabase_service.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final _service = SupabaseService(Supabase.instance.client);
  List<Expense> _expenses = [];
  bool _loading = true;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getExpenses();
      _expenses = data.map((e) => Expense.fromJson(e)).toList();
      _total = _expenses.fold(0, (sum, e) => sum + e.amount);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '฿${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    }
    return '฿${amount.toStringAsFixed(0)}';
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'material':
        return 'วัสดุ';
      case 'labor':
        return 'ค่าแรง';
      case 'contractor':
        return 'ผู้รับเหมา';
      default:
        return category ?? 'อื่น ๆ';
    }
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'material':
        return Icons.inventory;
      case 'labor':
        return Icons.engineering;
      case 'contractor':
        return Icons.business;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ค่าใช้จ่าย')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      const Text('ยังไม่มีข้อมูลค่าใช้จ่าย'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Total summary
                      Card(
                        color: theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ค่าใช้จ่ายทั้งหมด',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(_total),
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Expense items
                      ..._expenses.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(_categoryIcon(e.category)),
                            ),
                            title: Text(
                              e.description ?? _categoryLabel(e.category),
                            ),
                            subtitle: Text(
                              '${_categoryLabel(e.category)} • ${e.expenseDate.day}/${e.expenseDate.month}/${e.expenseDate.year}',
                            ),
                            trailing: Text(
                              _formatAmount(e.amount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/expenses/new');
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มค่าใช้จ่าย'),
      ),
    );
  }
}
