import 'package:flutter/material.dart';

class WorkOrderDetailScreen extends StatelessWidget {
  final String workOrderId;

  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดใบงาน')),
      body: Center(child: Text('Work Order ID: $workOrderId')),
    );
  }
}
