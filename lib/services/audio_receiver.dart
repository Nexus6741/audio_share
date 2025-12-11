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
  late final PcmStreamSource _source;
  late final StreamController<PlayerState> _playbackController;
  double _volume = 1.0;

  Stream<PlayerState> get playbackState => _playbackController.stream;
  double get volume => _volume;

  Future<void> start() async {
    _playbackController = StreamController.broadcast();
    _player = AudioPlayer();
    _player.playerStateStream.listen(_playbackController.add);

    _source = PcmStreamSource();
    await _player.setAudioSource(_source);
    await _player.setVolume(_volume);
    await _player.play();

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      _handlePayload(datagram.data);
    });
  }

  Future<void> _handlePayload(Uint8List payload) async {
    _source.addPayload(payload);
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> dispose() async {
    await _source.dispose();
    await _player.dispose();
    _socket?.close();
    await _playbackController.close();
  }
}

/// Continuous PCM source that forwards incoming UDP payloads to the player.
class PcmStreamSource extends StreamAudioSource {
  PcmStreamSource() : _controller = StreamController.broadcast();

  final StreamController<List<int>> _controller;

  void addPayload(Uint8List bytes) {
    if (!_controller.isClosed) {
      _controller.add(bytes);
    }
  }

  @override
  Future<StreamAudioResponse> request([StreamAudioRequest? request]) async {
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: request?.start ?? 0,
      stream: _controller.stream,
      contentType: 'audio/pcm',
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
