import 'package:flutter/material.dart';

class AssetsListScreen extends StatelessWidget {
  const AssetsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('อุปกรณ์ทั้งหมด')),
      body: const Center(child: Text('ยังไม่มีข้อมูลอุปกรณ์')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add asset
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
