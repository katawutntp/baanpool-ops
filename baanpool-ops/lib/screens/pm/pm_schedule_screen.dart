import 'package:flutter/material.dart';

class PmScheduleScreen extends StatelessWidget {
  const PmScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preventive Maintenance')),
      body: const Center(child: Text('ยังไม่มี PM Schedule')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to create PM schedule
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
