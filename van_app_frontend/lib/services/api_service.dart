// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _ip = "10.0.0.179";

  late final String _routesBaseUrl = "http://$_ip:8000";
  late final String _authBaseUrl = "http://$_ip:3001";
  late final String _tripsBaseUrl = "http://$_ip:8001";

  Future<Map<String, dynamic>> login(String email, String password) async {
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
