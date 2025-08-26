// lib/services/websocket_service.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class WebSocketService {
  WebSocketChannel? _channel;
  Stream? _stream;

  // Usamos o IP da sua máquina na rede Wi-Fi
  final String _ip = "10.0.0.179";

  void connect(String token, int routeId) {
    final uri = Uri.parse('ws://$_ip:3002?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _stream = _channel!.stream.asBroadcastStream();

    subscribeToRoute(routeId);
  }

  void subscribeToRoute(int routeId) {
    if (_channel != null) {
      _channel!.sink.add(
        jsonEncode({'type': 'subscribe_to_route', 'routeId': routeId}),
      );
    }
  }

  Stream? get stream => _stream;

  void disconnect() {
    _channel?.sink.close();
  }
}
