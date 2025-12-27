import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class PassengerMapScreen extends StatefulWidget {
  final int routeId;
  final String token;

  const PassengerMapScreen({super.key, required this.routeId, required this.token});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  // Coordenada padrão (Centro da cidade ou da rota)
  final LatLng _defaultCenter = LatLng(-23.27, -51.04);

  // Estado da Van
  LatLng? _vanLocation;
  bool _isFirstLoad = true;
  String _statusMessage = "Aguardando sinal da van...";
  Timer? _pollingTimer;

  // Estado da Rota (Visualização estática do caminho)
  List<LatLng> _routePoints = [];
  List<Marker> _stopMarkers = [];

  @override
  void initState() {
    super.initState();
    _loadStaticRoute(); // Carrega o desenho da rota (linha azul)
    _startTracking();   // Inicia o "Radar"
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // IMPORTANTE: Parar o timer ao sair da tela
    _mapController.dispose();
    super.dispose();
  }

  // 1. Carrega o desenho da rota apenas para o passageiro ter contexto
  Future<void> _loadStaticRoute() async {
    try {
      // Pega os passageiros para desenhar os pinos das paradas
      final passengers = await _apiService.getTodayConfirmations(widget.routeId);
      final activePassengers = passengers.where((p) => p['latitude'] != null && p['status'] == 'CONFIRMED').toList();

      if (activePassengers.isNotEmpty) {
        // Usamos uma posição fictícia de motorista só para gerar o traçado inicial
        final dummyDriver = {
          "id": 0, "name": "Ponto Inicial",
          "latitude": activePassengers[0]['latitude'],
          "longitude": activePassengers[0]['longitude'],
          "type": "driver"
        };

        final optimizedData = await _apiService.getOptimizedRoute(dummyDriver, activePassengers);

        // Desenha a linha azul da rota
        if (optimizedData['geometry'] != null) {
          final coords = optimizedData['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = coords.map((p) => LatLng(p[1].toDouble(), p[0].toDouble())).toList();
          });
        }

        // Desenha os pinos das paradas (Escolas/Casas)
        List<Marker> markers = [];
        final sortedList = optimizedData['optimized_order'] ?? [];
        for (var i = 0; i < sortedList.length; i++) {
          final p = sortedList[i];
          markers.add(Marker(
            point: LatLng(p['latitude'], p['longitude']),
            width: 60, height: 60,
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2)),
                  child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))
              ),
              const Icon(Icons.location_on, color: Colors.blue, size: 30),
            ]),
          ));
        }
        setState(() => _stopMarkers = markers);
      }
    } catch (e) {
      print("Erro ao carregar rota estática: $e");
    }
  }

  // 2. O "Radar": Busca a posição da van a cada 5 segundos
  void _startTracking() {
    // Chama imediatamente
    _fetchVanLocation();

    // Configura o loop
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchVanLocation();
    });
  }

  Future<void> _fetchVanLocation() async {
    final locationData = await _apiService.getDriverLocation(widget.routeId);

    if (locationData != null) {
      final newLocation = LatLng(locationData['latitude'], locationData['longitude']);

      setState(() {
        _vanLocation = newLocation;
        _statusMessage = "Van em movimento";
      });

      // Se for a primeira vez que achamos a van, centraliza a câmera nela
      if (_isFirstLoad) {
        _mapController.move(newLocation, 16.0);
        _isFirstLoad = false;
      }
    } else {
      setState(() {
        _statusMessage = "Motorista ainda não iniciou o trajeto.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Acompanhar Van"),
        backgroundColor: Colors.amber,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14.0,
            ),
            children: [
              // Tile Layer (Estilo Clean)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              // Rota Estática (Linha Cinza Clara de fundo)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: Colors.blueAccent.withOpacity(0.4),
                  ),
                ],
              ),

              // Marcadores das Paradas
              MarkerLayer(markers: _stopMarkers),

              // MARCADOR DA VAN (O mais importante!)
              if (_vanLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _vanLocation!,
                      width: 80, height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                            child: const Text("Motorista", style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                          const Icon(Icons.directions_bus, color: Colors.amber, size: 50),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Painel de Status Inferior
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  _vanLocation != null
                      ? const Icon(Icons.rss_feed, color: Colors.green, size: 30) // Ícone pulsando (simulado)
                      : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botão para focar na Van
          if (_vanLocation != null)
            Positioned(
              bottom: 110, right: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                child: const Icon(Icons.center_focus_strong, color: Colors.blue),
                onPressed: () {
                  _mapController.move(_vanLocation!, 17.0);
                },
              ),
            ),
        ],
      ),
    );
  }
}