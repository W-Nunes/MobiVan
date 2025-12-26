import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  final int routeId;
  final String token;

  const MapScreen({super.key, required this.routeId, required this.token});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _isLoading = true;
  String _routeInfo = "Calculando..."; // Para mostrar o tempo na tela

  // Ibiporã/Londrina approx
  final LatLng _initialCenter = LatLng(-23.27, -51.04);

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    try {
      // 1. Buscar passageiros
      final passengers = await _apiService.getTodayConfirmations(widget.routeId);

      // Filtra apenas os válidos e confirmados
      final activePassengers = passengers.where((p) =>
      p['latitude'] != null && p['status'] == 'CONFIRMED'
      ).toList();

      List<Marker> newMarkers = [];

      // 2. Definir Motorista
      final driverLoc = {
        "id": 0, "name": "Motorista",
        "latitude": _initialCenter.latitude,
        "longitude": _initialCenter.longitude,
        "type": "driver"
      };

      // Marcador do Motorista
      newMarkers.add(
        Marker(
          point: LatLng(driverLoc['latitude'] as double, driverLoc['longitude'] as double),
          width: 50, height: 50,
          child: const Icon(Icons.directions_bus, color: Colors.black, size: 40),
        ),
      );

      // 3. Chamar a Otimização (Python)
      if (activePassengers.isNotEmpty) {
        final optimizedData = await _apiService.getOptimizedRoute(driverLoc, activePassengers);

        // --- CORREÇÃO 1: Nome da chave atualizado para 'optimized_order' ---
        final List<dynamic> sortedList = optimizedData['optimized_order'] ?? [];

        // Adiciona marcadores (Pinos) na ordem otimizada
        for (var i = 0; i < sortedList.length; i++) {
          final p = sortedList[i];
          final point = LatLng(p['latitude'], p['longitude']);

          newMarkers.add(
            Marker(
              point: point,
              width: 80, height: 80,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                ],
              ),
            ),
          );
        }

        // --- CORREÇÃO 2: Ler a Geometria da Rua (OSRM) ---
        List<LatLng> routePoints = [];

        if (optimizedData['geometry'] != null && optimizedData['geometry']['coordinates'] != null) {
          final List<dynamic> coordsBrutos = optimizedData['geometry']['coordinates'];

          // OSRM retorna [Longitude, Latitude]. Precisamos inverter para [Latitude, Longitude]
          routePoints = coordsBrutos.map((ponto) {
            return LatLng(ponto[1].toDouble(), ponto[0].toDouble());
          }).toList();
        }

        // Criar a Linha da Rua
        final routeLine = Polyline(
          points: routePoints,
          strokeWidth: 5.0, // Linha mais grossa para ver melhor
          color: Colors.blueAccent,
        );

        // Extrair tempo estimado
        String tempo = "${optimizedData['total_duration_minutes'] ?? '?'} min";
        String distancia = "${optimizedData['total_distance_km'] ?? '?'} km";

        if (mounted) {
          setState(() {
            _markers = newMarkers;
            _polylines = [routeLine];
            _routeInfo = "$distancia em $tempo"; // Atualiza o título
            _isLoading = false;
          });
        }
      } else {
        // Caso não tenha passageiros, só desenha o motorista
        if (mounted) {
          setState(() {
            _markers = newMarkers;
            _isLoading = false;
            _routeInfo = "Sem passageiros";
          });
        }
      }
    } catch (e) {
      print("Erro ao carregar mapa: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mostra o tempo estimado na barra superior
      appBar: AppBar(
          title: Text("Rota: $_routeInfo"),
          backgroundColor: Colors.amber
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          PolylineLayer(polylines: _polylines), // Desenha a rua real!
          MarkerLayer(markers: _markers),       // Desenha os pinos
        ],
      ),
    );
  }
}