import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // SEU IP LOCAL (Mantenha atualizado se o roteador reiniciar)
  final String _ip = "10.0.0.179";

  // Endereços dos microserviços
  late final String _authBaseUrl = "http://$_ip:3001";
  late final String _routesBaseUrl = "http://$_ip:8000";
  late final String _tripsBaseUrl = "http://$_ip:8001";
  late final String _routingBaseUrl = "http://$_ip:8002";

  // Helper para criar os cabeçalhos com o token JWT
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- AUTENTICAÇÃO ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_authBaseUrl/login'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          'Falha ao fazer login: ${errorBody['error'] ?? 'Erro desconhecido'}',
        );
      } catch (e) {
        throw Exception('Falha ao fazer login: ${response.body}');
      }
    }
  }

  // --- ROTAS (GERAL) ---
  Future<List<dynamic>> getRoutes() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/routes'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar as rotas.');
    }
  }

  Future<void> createRoute(String name, int driverId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_routesBaseUrl/routes'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{'name': name, 'driver_id': driverId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao criar a rota.');
    }
  }

  // --- PASSAGEIRO ---
  Future<Map<String, dynamic>?> getMyRoute(int passengerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/passengers/$passengerId/route'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Falha ao carregar a sua rota. Status: ${response.statusCode}',
      );
    }
  }

  Future<void> confirmPresence(
      int passengerId,
      int routeId,
      String status,
      ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_tripsBaseUrl/confirmations'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'passenger_id': passengerId,
        'route_id': routeId,
        'status': status,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao confirmar presença: ${response.body}');
    }
  }

  // --- PASSAGEIRO: RASTREAMENTO (NOVO) ---
  // Busca a localização atual da van
  Future<Map<String, dynamic>?> getDriverLocation(int routeId) async {
    final url = Uri.parse('$_tripsBaseUrl/trips/$routeId/location');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // 404 é normal se a van não começou a andar ainda
        return null;
      }
    } catch (e) {
      print("Erro ao buscar GPS da van: $e");
      return null;
    }
  }

  // --- MOTORISTA ---
  Future<Map<String, dynamic>> getDriverRoute(int driverId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/drivers/$driverId/route'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar a rota do motorista.');
    }
  }

  Future<List<dynamic>> getTodayConfirmations(int routeId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_tripsBaseUrl/trips/today/$routeId/confirmations'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar confirmações do dia.');
    }
  }

  // --- OTIMIZAÇÃO DE ROTA ---
  Future<Map<String, dynamic>> getOptimizedRoute(Map<String, dynamic> driverLocation, List<dynamic> passengers) async {
    final headers = await _getHeaders();

    final body = {
      "driver_start": driverLocation,
      "passengers": passengers.map((p) => {
        "id": p['passenger_id'],
        "name": p['passenger_name'],
        "latitude": p['latitude'],
        "longitude": p['longitude'],
        "type": "passenger"
      }).toList()
    };

    final response = await http.post(
      Uri.parse('$_routingBaseUrl/optimize'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"optimize_order": [], "total_distance_km": 0.0};
    }
  }

  // --- MÉTODOS DO MAPA DO MOTORISTA ---

  // 1. Confirma embarque (Botão Deslizante)
  Future<bool> confirmPassengerBoarding(int passengerId, int routeId) async {
    final url = Uri.parse('$_tripsBaseUrl/confirmations');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "passenger_id": passengerId,
          "route_id": routeId,
          "status": "CONFIRMED"
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Embarque confirmado no servidor!");
        return true;
      } else {
        print("❌ Erro ao confirmar embarque: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Erro de conexão: $e");
      return false;
    }
  }

  // 2. Envia GPS do Motorista em tempo real
  Future<void> sendDriverLocation(int routeId, double lat, double long) async {
    final url = Uri.parse('$_tripsBaseUrl/trips/$routeId/location');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "latitude": lat,
          "longitude": long
        }),
      );
    } catch (e) {
      print("Erro silencioso ao enviar GPS: $e");
    }
  }
}