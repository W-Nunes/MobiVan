import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:action_slider/action_slider.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
  final MapController _mapController = MapController();

  final LatLng _defaultCenter = LatLng(-23.27, -51.04);

  // --- ESTADO DA ROTA ---
  List<Marker> _markers = [];
  List<LatLng> _fullRoutePoints = [];
  List<LatLng> _remainingRoutePoints = [];

  List<dynamic> _orderedPassengers = [];
  List<dynamic> _navigationSteps = [];
  int _currentPassengerIndex = 0;

  // --- ESTADO GPS/SENSOR ---
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  LatLng? _currentLocation;

  double _rotation = 0.0;
  double _lastCompassHeading = 0.0;

  bool _isNavigationMode = false;

  // Controle de Performance (Throttling)
  DateTime _lastRouteUpdate = DateTime.now();

  // --- NOVO: Controle de Envio de GPS para o Backend ---
  DateTime _lastApiUpdate = DateTime.now().subtract(const Duration(seconds: 10));

  // Estado da UI
  String _statusMessage = "Buscando localização...";
  bool _showConfirmButton = false;
  bool _isLoading = true;

  // --- VARIÁVEIS DO PAINEL DE NAVEGAÇÃO ---
  String _navInstruction = "Siga a rota";
  String _navStreetName = "";
  IconData _navIcon = Icons.arrow_upward;
  int _navDistance = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndStart() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      await _loadRouteData(position);

      _startNavigationListener();
      _startCompassListener();

    } catch (e) {
      print("Erro GPS: $e");
    }
  }

  Future<void> _loadRouteData(Position myRealPosition) async {
    try {
      setState(() => _statusMessage = "Calculando rota...");

      final passengers = await _apiService.getTodayConfirmations(widget.routeId);
      final activePassengers = passengers.where((p) =>
      p['latitude'] != null && p['status'] == 'CONFIRMED'
      ).toList();

      List<Marker> newMarkers = [];
      final driverLoc = {
        "id": 0, "name": "Minha Van",
        "latitude": myRealPosition.latitude,
        "longitude": myRealPosition.longitude,
        "type": "driver"
      };

      if (activePassengers.isNotEmpty) {
        final optimizedData = await _apiService.getOptimizedRoute(driverLoc, activePassengers);

        _orderedPassengers = optimizedData['optimized_order'] ?? [];
        _navigationSteps = optimizedData['steps'] ?? [];

        for (var i = 0; i < _orderedPassengers.length; i++) {
          final p = _orderedPassengers[i];
          final point = LatLng(p['latitude'], p['longitude']);

          newMarkers.add(
            Marker(
              point: point,
              width: 80, height: 80,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)
                    ),
                    child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                ],
              ),
            ),
          );
        }

        if (optimizedData['geometry'] != null && optimizedData['geometry']['coordinates'] != null) {
          final List<dynamic> coordsBrutos = optimizedData['geometry']['coordinates'];
          _fullRoutePoints = coordsBrutos.map((ponto) {
            return LatLng(ponto[1].toDouble(), ponto[0].toDouble());
          }).toList();

          _remainingRoutePoints = List.from(_fullRoutePoints);
        }

        if (mounted) {
          setState(() {
            _markers = newMarkers;
            _isLoading = false;
            _mapController.move(LatLng(myRealPosition.latitude, myRealPosition.longitude), 17);
            if (_orderedPassengers.isNotEmpty) {
              _statusMessage = "Próximo: ${_orderedPassengers[0]['name']}";
            }
          });
        }
      }
    } catch (e) {
      print("Erro rota: $e");
      setState(() => _isLoading = false);
    }
  }

  void _startCompassListener() {
    _compassStream = FlutterCompass.events!.listen((CompassEvent event) {
      if (event.heading == null) return;
      if ((event.heading! - _lastCompassHeading).abs() < 3.0) return;
      _lastCompassHeading = event.heading!;
    });
  }

  void _startNavigationListener() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {

      final newLoc = LatLng(position.latitude, position.longitude);
      final double speedKmH = position.speed * 3.6;

      double newRotation = (speedKmH > 3.0) ? position.heading : _lastCompassHeading;

      // 1. Atualizações Visuais (Rota cinza/azul)
      final now = DateTime.now();
      if (now.difference(_lastRouteUpdate).inSeconds > 1) {
        _updateRouteProgress(newLoc);
        _lastRouteUpdate = now;
      }

      // 2. Atualiza Painel de Navegação
      _updateNavigationInstructions(newLoc);

      // --- 3. NOVO: ENVIA GPS PARA O BACKEND (A cada 5s) ---
      if (now.difference(_lastApiUpdate).inSeconds >= 5) {
        _apiService.sendDriverLocation(
            widget.routeId,
            position.latitude,
            position.longitude
        );
        _lastApiUpdate = now;
        print("📡 GPS Enviado: ${position.latitude}, ${position.longitude}");
      }
      // -----------------------------------------------------

      setState(() {
        _currentLocation = newLoc;
        _rotation = newRotation;
      });

      if (_isNavigationMode) {
        _mapController.moveAndRotate(newLoc, 18.0, 0);
      }

      _checkProximityToPassenger(newLoc);
    });
  }

  void _updateRouteProgress(LatLng myPos) {
    if (_fullRoutePoints.isEmpty) return;

    int closestIndex = 0;
    double minDistance = double.infinity;
    final Distance distance = Distance();

    for (int i = 0; i < _fullRoutePoints.length; i++) {
      final d = distance.as(LengthUnit.Meter, myPos, _fullRoutePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    if (minDistance < 100) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _remainingRoutePoints = _fullRoutePoints.sublist(closestIndex);
          });
        }
      });
    }
  }

  void _updateNavigationInstructions(LatLng myPos) {
    if (_navigationSteps.isEmpty) return;

    final Distance distanceCalc = Distance();

    for (var step in _navigationSteps) {
      final coords = step['location'];
      final stepLoc = LatLng(coords[1], coords[0]);
      final dist = distanceCalc.as(LengthUnit.Meter, myPos, stepLoc);

      if (dist > 20) {
        setState(() {
          _navDistance = dist.toInt();
          _navStreetName = (step['name'] == null || step['name'] == "") ? "Siga o trajeto" : step['name'];

          String modifier = step['modifier'] ?? "";
          String type = step['instruction'] ?? "";

          if (type == "turn") {
            if (modifier.contains("right")) _navIcon = Icons.turn_right;
            else if (modifier.contains("left")) _navIcon = Icons.turn_left;
          } else if (type == "roundabout") {
            _navIcon = Icons.loop;
          } else if (type == "arrive") {
            _navIcon = Icons.flag;
          } else {
            _navIcon = Icons.arrow_upward;
          }

          if (type == "arrive") _navInstruction = "Chegando ao destino";
          else if (modifier == "right") _navInstruction = "Vire à Direita";
          else if (modifier == "left") _navInstruction = "Vire à Esquerda";
          else _navInstruction = "Siga em frente";
        });
        break;
      }
    }
  }

  void _checkProximityToPassenger(LatLng myPos) {
    if (_orderedPassengers.isEmpty || _currentPassengerIndex >= _orderedPassengers.length) return;

    final nextPassenger = _orderedPassengers[_currentPassengerIndex];
    final passPos = LatLng(nextPassenger['latitude'], nextPassenger['longitude']);
    final Distance distance = Distance();
    final double meters = distance.as(LengthUnit.Meter, myPos, passPos);

    if (meters < 50 && !_showConfirmButton) {
      setState(() {
        _showConfirmButton = true;
      });
    }
  }

  Future<void> _confirmBoarding() async {
    if (_orderedPassengers.isEmpty || _currentPassengerIndex >= _orderedPassengers.length) return;

    final currentPassenger = _orderedPassengers[_currentPassengerIndex];
    // Garante pegar o ID certo (suporta id ou passenger_id)
    final int passengerId = currentPassenger['passenger_id'] ?? currentPassenger['id'];

    // Chama o backend para confirmar
    bool success = await _apiService.confirmPassengerBoarding(passengerId, widget.routeId);

    if (success) {
      setState(() {
        _showConfirmButton = false;
        _currentPassengerIndex++;
        if (_currentPassengerIndex < _orderedPassengers.length) {
          _statusMessage = "Próximo: ${_orderedPassengers[_currentPassengerIndex]['name']}";
        } else {
          _statusMessage = "Viagem Finalizada!";
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${currentPassenger['name']} confirmado!"), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao confirmar. Tente novamente."), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleNavigationMode() {
    setState(() {
      _isNavigationMode = !_isNavigationMode;
      if (_isNavigationMode && _currentLocation != null) {
        _mapController.moveAndRotate(_currentLocation!, 18.0, 0);
      } else if (!_isNavigationMode && _currentLocation != null) {
        _mapController.move(_currentLocation!, 15.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _defaultCenter,
              initialZoom: 15.0,
              minZoom: 5,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _fullRoutePoints,
                    strokeWidth: 9.0,
                    color: Colors.grey.withOpacity(0.5),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.grey[300]!,
                  ),
                ],
              ),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _remainingRoutePoints,
                    strokeWidth: 9.0,
                    color: Colors.blueAccent,
                  ),
                ],
              ),

              MarkerLayer(markers: _markers),

              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 70, height: 70,
                      child: Transform.rotate(
                        angle: _rotation * (pi / 180),
                        child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 50),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (_isNavigationMode && _navigationSteps.isNotEmpty)
            Positioned(
              top: 50, left: 15, right: 15,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A2E43),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                ),
                child: Row(
                  children: [
                    Icon(_navIcon, color: Colors.white, size: 42),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$_navDistance m", style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(_navInstruction, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          Text(_navStreetName, style: TextStyle(color: Colors.grey[400], fontSize: 14), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 150, right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              child: Icon(_isNavigationMode ? Icons.navigation : Icons.my_location, color: Colors.blue),
              onPressed: _toggleNavigationMode,
            ),
          ),

          if (_showConfirmButton)
            Positioned(
              bottom: 40, left: 20, right: 20,
              child: ActionSlider.standard(
                sliderBehavior: SliderBehavior.stretch,
                rolling: true,
                width: 300,
                backgroundColor: Colors.white,
                toggleColor: Colors.amber,
                icon: const Icon(Icons.check_circle_outline),
                successIcon: const Icon(Icons.check, color: Colors.white),
                child: const Text('Confirmar Embarque', style: TextStyle(fontWeight: FontWeight.bold)),
                action: (controller) async {
                  controller.loading();
                  await _confirmBoarding();
                  controller.success();
                  await Future.delayed(const Duration(seconds: 1));
                  controller.reset();
                },
              ),
            ),
        ],
      ),
    );
  }
}