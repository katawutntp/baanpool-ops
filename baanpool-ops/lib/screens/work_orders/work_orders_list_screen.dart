import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_state_service.dart';

class WorkOrdersListScreen extends StatelessWidget {
  const WorkOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบงานทั้งหมด'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter dialog (ตามสถานะ, บ้าน, ช่าง)
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await AuthStateService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: const Center(child: Text('ยังไม่มีใบงาน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/work-orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบงาน'),
      ),
    );
  }
}
