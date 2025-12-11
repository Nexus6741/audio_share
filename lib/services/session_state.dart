import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'audio_receiver.dart';
import 'audio_sender.dart';
import 'discovery_service.dart';

/// Shared app state that keeps track of discovery and the current role.
class SessionState extends ChangeNotifier {
  SessionState() {
    _identity = DeviceIdentity(
      const Uuid().v4(),
      platformLabel: describeEnum(defaultTargetPlatform),
    );
    _discovery = DiscoveryService(identity: _identity);
    _discovery.updatePresence(accepting: false);
    _discovery.devicesStream.listen((devices) {
      _devices = devices;
      notifyListeners();
    });
    _discovery.start();
  }

  late final DeviceIdentity _identity;
  late final DiscoveryService _discovery;
  late List<DiscoveredDevice> _devices = [];

  DiscoveredDevice? _receiver;
  AudioSender? _sender;
  AudioReceiver? _receiverService;
  StreamSubscription? _playbackSubscription;

  List<DiscoveredDevice> get devices => _devices;
  DiscoveredDevice? get receiver => _receiver;
  bool get isSending => _sender != null;
  bool get isReceiving => _receiverService != null;
  DeviceIdentity get identity => _identity;

  /// Choose which device should receive audio from this device.
  Future<void> selectReceiver(DiscoveredDevice target) async {
    if (_receiver?.id == target.id) return;
    _receiver = target;
    notifyListeners();
    await _startSender();
  }

  Future<void> _startSender() async {
    await _sender?.dispose();
    _sender = AudioSender(
      target: _receiver!,
      discovery: _discovery,
    );
    await _sender!.start();
    notifyListeners();
  }

  /// Start listening for audio from others.
  Future<void> startReceiving() async {
    if (_receiverService != null) return;
    _receiverService = AudioReceiver(identity: _identity, discovery: _discovery);
    await _receiverService!.start();
    _discovery.updatePresence(port: _receiverService!.port, accepting: true);
    _playbackSubscription = _receiverService!.playbackState.listen((event) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopReceiving() async {
    await _receiverService?.dispose();
    await _playbackSubscription?.cancel();
    _receiverService = null;
    _discovery.updatePresence(port: null, accepting: false);
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
