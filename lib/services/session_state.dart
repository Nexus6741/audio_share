import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

import 'audio_receiver.dart';
import 'audio_sender.dart';
import 'discovery_service.dart';

/// Shared app state that keeps track of discovery and the current role.
class SessionState extends ChangeNotifier {
  SessionState() {
    final hostName = Platform.localHostname.isNotEmpty ? Platform.localHostname : null;
    _identity = DeviceIdentity(
      const Uuid().v4(),
      platformLabel: describeEnum(defaultTargetPlatform),
      name: hostName,
    );
    _discovery = DiscoveryService(identity: _identity);
    _discovery.updatePresence(accepting: false);
    _discovery.devicesStream.listen((devices) {
      _devices = devices;
      if (_receiver != null && !_devices.any((d) => d.id == _receiver!.id)) {
        _statusMessage = '接收端已离线，自动停止推流';
        stopSending();
      }
      notifyListeners();
    });
    _discovery.start();
    _discovery.forceAnnounce();
  }

  late final DeviceIdentity _identity;
  late final DiscoveryService _discovery;
  late List<DiscoveredDevice> _devices = [];

  DiscoveredDevice? _receiver;
  AudioSender? _sender;
  AudioReceiver? _receiverService;
  StreamSubscription? _playbackSubscription;
  String? _statusMessage;
  double _volume = 1.0;
  PlayerState? _playbackState;

  List<DiscoveredDevice> get devices => _devices;
  DiscoveredDevice? get receiver => _receiver;
  bool get isSending => _sender != null;
  bool get isReceiving => _receiverService != null;
  DeviceIdentity get identity => _identity;
  String? get statusMessage => _statusMessage;
  double get volume => _volume;
  PlayerState? get playbackState => _playbackState;

  /// Choose which device should receive audio from this device.
  Future<void> selectReceiver(DiscoveredDevice target) async {
    if (_receiver?.id == target.id) {
      await stopSending();
      _statusMessage = '已取消推流';
      notifyListeners();
      return;
    }
    if (target.accepting != true) {
      _statusMessage = '目标设备未开启接收模式';
      notifyListeners();
      return;
    }
    _receiver = target;
    _statusMessage = '正在连接到 ${target.id.substring(0, 6)}';
    notifyListeners();
    await _startSender();
  }

  Future<void> _startSender() async {
    await _sender?.dispose();
    try {
      _sender = AudioSender(
        target: _receiver!,
        discovery: _discovery,
      );
      await _sender!.start();
      _statusMessage = '正在向 ${_receiver!.id.substring(0, 6)} 推流';
    } catch (e) {
      _statusMessage = '启动推流失败: $e';
      _receiver = null;
      await _sender?.dispose();
      _sender = null;
    }
    notifyListeners();
  }

  /// Start listening for audio from others.
  Future<void> startReceiving() async {
    if (_receiverService != null) return;
    _receiverService = AudioReceiver(identity: _identity, discovery: _discovery);
    await _receiverService!.start();
    await _receiverService!.setVolume(_volume);
    _discovery.updatePresence(port: _receiverService!.port, accepting: true);
    _playbackSubscription = _receiverService!.playbackState.listen((event) {
      _playbackState = event;
      notifyListeners();
    });
    _statusMessage = '接收模式已开启';
    notifyListeners();
  }

  Future<void> stopReceiving() async {
    await _receiverService?.dispose();
    await _playbackSubscription?.cancel();
    _receiverService = null;
    _playbackState = null;
    _discovery.updatePresence(port: null, accepting: false);
    _statusMessage = '已停止接收';
    notifyListeners();
  }

  Future<void> stopSending() async {
    await _sender?.dispose();
    _sender = null;
    _receiver = null;
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    if (_receiverService != null) {
      await _receiverService!.setVolume(_volume);
    }
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _sender?.dispose();
    await _receiverService?.dispose();
    await _playbackSubscription?.cancel();
    _discovery.dispose();
    super.dispose();
  }
}
