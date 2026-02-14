import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExpensesListScreen extends StatelessWidget {
  const ExpensesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ค่าใช้จ่าย')),
      body: const Center(child: Text('ยังไม่มีข้อมูลค่าใช้จ่าย')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มค่าใช้จ่าย'),
      ),
    );
  }
}
