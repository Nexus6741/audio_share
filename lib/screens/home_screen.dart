import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/discovery_service.dart';
import '../services/session_state.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final deviceName = session.identity.name ?? session.identity.platformLabel;
    final playback = session.playbackState;
    final playbackLabel = _playbackLabel(playback);
    return Scaffold(
      appBar: AppBar(
        title: const Text('音频共享'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本机: $deviceName · ${session.identity.id.substring(0, 6)}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                    if (session.isSending)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('停止推流'),
                        onPressed: session.stopSending,
                      ),
                    if (session.receiver != null)
                      Chip(
                        avatar: const Icon(Icons.wifi_tethering),
                        label: Text('发送到: ${session.receiver!.id.substring(0, 6)}'),
                      ),
                    if (session.isReceiving)
                      const Chip(
                        avatar: Icon(Icons.hearing, color: Colors.green),
                        label: Text('接收中'),
                      ),
                  ],
                ),
                if (session.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(session.statusMessage!)),
                    ],
                  ),
                ],
                if (session.isReceiving) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.hearing, size: 18),
                      const SizedBox(width: 6),
                      Text(playbackLabel),
                    ],
                  ),
                  Slider(
                    value: session.volume,
                    onChanged: session.isReceiving ? (v) => session.setVolume(v) : null,
                    divisions: 10,
                    min: 0,
                    max: 1,
                    label: '${(session.volume * 100).round()}% 音量',
                  ),
                ],
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

  String _playbackLabel(PlayerState? state) {
    if (state == null) return '等待推流...';
    final status = state.processingState;
    switch (status) {
      case ProcessingState.idle:
        return '等待推流...';
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return '缓冲中...';
      case ProcessingState.ready:
        return state.playing ? '播放中' : '已暂停';
      case ProcessingState.completed:
        return '播放结束';
    }
  }
}
