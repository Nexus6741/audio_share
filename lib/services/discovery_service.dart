import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DeviceIdentity {
  DeviceIdentity(this.id, {required this.platformLabel, this.name});

  final String id;
  final String platformLabel;
  final String? name;

  Map<String, dynamic> toJson({int? port, bool? accepting}) => {
        'id': id,
        'platform': platformLabel,
        if (name != null) 'name': name,
        if (port != null) 'port': port,
        if (accepting != null) 'accepting': accepting,
      };
}

class DiscoveredDevice {
  DiscoveredDevice({
    required this.id,
    required this.platform,
    required this.address,
    this.port,
    this.name,
    this.accepting,
    required this.lastSeen,
  });

  final String id;
  final String platform;
  final InternetAddress address;
  final int? port;
  final String? name;
  final bool? accepting;
  final DateTime lastSeen;
}

/// Simple UDP-based discovery.
class DiscoveryService {
  DiscoveryService({required this.identity, this.discoveryPort = 42042});

  final DeviceIdentity identity;
  final int discoveryPort;

  final _devices = <String, DiscoveredDevice>{};
  late final StreamController<List<DiscoveredDevice>> _devicesController;
  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _cleanupTimer;
  int? _advertisedPort;
  bool? _accepting;

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  void start() {
    _devicesController = StreamController.broadcast();
    _bind();
  }

  /// Update presence metadata included in announcements.
  void updatePresence({int? port, bool? accepting}) {
    _advertisedPort = port;
    _accepting = accepting;
  }

  void _bind() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
    _socket!.broadcastEnabled = true;
    _socket!.listen(_handlePacket);
    _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) => _announce());
    _cleanupTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pruneStale(const Duration(seconds: 8)));
  }

  void _announce() {
    final payload = utf8.encode(jsonEncode(identity.toJson(
      port: _advertisedPort,
      accepting: _accepting,
    )));
    _socket?.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
  }

  void _handlePacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) return;
    final datagram = _socket!.receive();
    if (datagram == null) return;
    final message = utf8.decode(datagram.data);
    try {
      final decoded = jsonDecode(message) as Map<String, dynamic>;
      final id = decoded['id'] as String;
      if (id == identity.id) return;
      _devices[id] = DiscoveredDevice(
        id: id,
        platform: decoded['platform'] as String? ?? 'unknown',
        address: datagram.address,
        port: decoded['port'] as int?,
        name: decoded['name'] as String?,
        accepting: decoded['accepting'] as bool?,
        lastSeen: DateTime.now(),
      );
      _devicesController.add(_devices.values.toList());
    } catch (_) {
      // Ignore malformed packets.
    }
  }

  void _pruneStale(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    _devices.removeWhere((_, device) => device.lastSeen.isBefore(cutoff));
    _devicesController.add(_devices.values.toList());
  }

  void dispose() {
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _devicesController.close();
  }
}
