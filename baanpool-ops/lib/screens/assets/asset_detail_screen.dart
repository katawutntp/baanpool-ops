import 'package:flutter/material.dart';

class AssetDetailScreen extends StatelessWidget {
  final String assetId;

  const AssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดอุปกรณ์')),
      body: Center(child: Text('Asset ID: $assetId')),
    );
  }
}
