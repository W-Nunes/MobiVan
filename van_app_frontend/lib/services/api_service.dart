// lib/services/api_service.dart (CORRIGIDO PARA ACEITAR 404)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // IP da sua máquina na rede Wi-Fi
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

  // --- MUDANÇA CRÍTICA AQUI ---
  Future<Map<String, dynamic>?> getMyRoute(int passengerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/passengers/$passengerId/route'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      // SUCESSO SILENCIOSO: Retorna null se não tiver rota
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

    // Aceita 200 (OK) ou 201 (Created)
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao confirmar presença: ${response.body}');
    }
  }

  // --- MÉTODOS DO MOTORISTA ---
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

  // --- MÉTODO DE OTIMIZAÇÃO ---
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
      // Retorna vazio em caso de erro para não travar o mapa
      return {"optimize_order": [], "total_distance_km": 0.0};
    }
  }
}