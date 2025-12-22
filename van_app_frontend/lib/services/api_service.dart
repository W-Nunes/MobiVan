// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // IP da sua máquina na rede Wi-Fi conforme informado
  final String _ip = "10.0.0.179";

  // Endereços diretos para os microserviços (mais estável para dispositivo físico)
  late final String _authBaseUrl = "http://$_ip:3001";
  late final String _routesBaseUrl = "http://$_ip:8000";
  late final String _tripsBaseUrl = "http://$_ip:8001";

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
    // Rota de login direta no auth-service (porta 3001)
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

  Future<Map<String, dynamic>> getMyRoute(int passengerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_routesBaseUrl/passengers/$passengerId/route'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Falha ao carregar a sua rota. Status: ${response.statusCode}, Body: ${response.body}',
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

    if (response.statusCode != 200) {
      throw Exception('Falha ao confirmar presença.');
    }
  }
}
