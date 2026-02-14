import 'package:flutter/material.dart';

class PropertiesListScreen extends StatelessWidget {
  const PropertiesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายชื่อบ้าน')),
      body: const Center(child: Text('ยังไม่มีข้อมูลบ้าน')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add property
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
