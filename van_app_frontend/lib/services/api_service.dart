// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // URLs base para os nossos diferentes serviços
  final String _routesBaseUrl =
      "http://localhost:8000"; // Aponta para o routes-service
  final String _authBaseUrl =
      "http://localhost:3001"; // Aponta para o auth-service
  final String _tripsBaseUrl =
      "http://localhost:8001"; // Aponta para o trips-service

  Future<Map<String, dynamic>> login(String email, String password) async {
    // (Código existente - sem alterações)
    final response = await http.post(
      Uri.parse('$_authBaseUrl/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao fazer login: ${errorBody['error']}');
    }
  }

  Future<List<dynamic>> getRoutes() async {
    // (Código existente - sem alterações)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$_routesBaseUrl/routes'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar as rotas.');
    }
  }

  Future<void> createRoute(String name, int driverId) async {
    // (Código existente - sem alterações)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$_routesBaseUrl/routes'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{'name': name, 'driver_id': driverId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao criar a rota.');
    }
  }

  // --- NOVA FUNÇÃO ---
  Future<Map<String, dynamic>> getMyRoute(int passengerId) async {
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/passengers/$passengerId/route'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar a sua rota.');
    }
  }

  // --- NOVA FUNÇÃO ---
  Future<void> confirmPresence(
    int passengerId,
    int routeId,
    String status,
  ) async {
    final response = await http.post(
      Uri.parse('$_tripsBaseUrl/confirmations'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'passenger_id': passengerId,
        'route_id': routeId,
        'status': status,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao confirmar presença.');
    }
  }
}
