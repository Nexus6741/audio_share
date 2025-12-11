import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/discovery_service.dart';
import '../services/session_state.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('音频共享'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(session.isReceiving ? Icons.stop : Icons.speaker),
                  label: Text(session.isReceiving ? '停止接收' : '开启接收模式'),
                  onPressed: () {
                    if (session.isReceiving) {
                      session.stopReceiving();
                    } else {
                      session.startReceiving();
                    }
                  },
                ),
                const SizedBox(width: 12),
                if (session.receiver != null)
                  Chip(
                    avatar: const Icon(Icons.wifi_tethering),
                    label: Text('发送到: ${session.receiver!.id.substring(0, 6)}'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => Future.delayed(const Duration(milliseconds: 300)),
              child: ListView.builder(
                itemCount: session.devices.length,
                itemBuilder: (context, index) {
                  final device = session.devices[index];
                  return DeviceCard(
                    device: device,
                    selected: session.receiver?.id == device.id,
                    onTap: () => session.selectReceiver(device),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
