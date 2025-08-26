// lib/screens/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/websocket_service.dart';

class MapScreen extends StatefulWidget {
  final int routeId;
  final String token;

  const MapScreen({super.key, required this.routeId, required this.token});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  final Set<Marker> _markers = {};

  // Posição inicial do mapa (São Paulo)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-23.550520, -46.633308),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _webSocketService.connect(widget.token, widget.routeId);
    _webSocketService.stream?.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'driver_location') {
        final location = data['location'];
        _updateDriverMarker(LatLng(location['lat'], location['lng']));
      }
    });
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _markers.clear(); // Limpa o marcador antigo
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'A sua Van'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _webSocketService.disconnect(); // Desliga o WebSocket ao sair do ecrã
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localização em Tempo Real'),
        backgroundColor: Colors.amber,
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        markers: _markers,
      ),
    );
  }
}
