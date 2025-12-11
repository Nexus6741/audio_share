import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import 'discovery_service.dart';

class AudioReceiver {
  AudioReceiver({required this.identity, required this.discovery, this.port = 43210});

  final DeviceIdentity identity;
  final DiscoveryService discovery;
  final int port;

  RawDatagramSocket? _socket;
  late final AudioPlayer _player;
  late final StreamController<PlayerState> _playbackController;

  Stream<PlayerState> get playbackState => _playbackController.stream;

  Future<void> start() async {
    _playbackController = StreamController.broadcast();
    _player = AudioPlayer();
    _player.playerStateStream.listen(_playbackController.add);

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      _handlePayload(datagram.data);
    });
  }

  Future<void> _handlePayload(Uint8List payload) async {
    final source = SingleBufferSource(payload);
    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> dispose() async {
    await _player.dispose();
    _socket?.close();
    await _playbackController.close();
  }
}

/// Minimal audio source that wraps a single PCM payload.
class SingleBufferSource extends StreamAudioSource {
  SingleBufferSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<StreamAudioResponse> request([StreamAudioRequest? request]) async {
    final start = request?.start ?? 0;
    final end = request?.end ?? bytes.length;
    final slice = bytes.sublist(start, end);
    final stream = Stream.value(slice);
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: slice.length,
      offset: start,
      stream: stream,
      contentType: 'audio/pcm',
    );
  }
}
