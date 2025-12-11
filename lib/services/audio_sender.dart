import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'discovery_service.dart';

/// Streams microphone/system audio to the chosen receiver.
class AudioSender {
  AudioSender({required this.target, required this.discovery, this.port = 43210});

  final DiscoveredDevice target;
  final DiscoveryService discovery;
  final int port;

  late final Record _recorder;
  RawDatagramSocket? _socket;
  StreamSubscription<Uint8List>? _audioSubscription;

  Future<void> start() async {
    _recorder = Record();
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final targetPort = target.port ?? port;
    await _recorder.startStream(encoder: AudioEncoder.pcm16bitsLE).then((stream) {
      _audioSubscription = stream.listen((data) {
        _socket?.send(data, target.address, targetPort);
      });
    });
  }

  Future<void> dispose() async {
    await _audioSubscription?.cancel();
    await _recorder.stop();
    _socket?.close();
  }
}
