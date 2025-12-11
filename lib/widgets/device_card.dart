import 'package:flutter/material.dart';

import '../services/discovery_service.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.selected, required this.onTap});

  final DiscoveredDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accepting = device.accepting == true;
    return Card(
      color: selected ? Colors.deepPurple.shade50 : null,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(device.name ?? device.id.substring(0, 8)),
        subtitle: Text(
          '${device.platform} @ ${device.address.address}:${device.port ?? 'N/A'}${accepting ? ' · 接收中' : ''}',
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.deepPurple)
            : (accepting ? const Icon(Icons.hearing, color: Colors.green) : null),
        enabled: accepting,
        onTap: onTap,
      ),
    );
  }
}
