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

  // Função para obter a lista de rotas
  Future<List<dynamic>> getRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$_routesBaseUrl/routes'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        // 'Authorization': 'Bearer $token', // Vamos adicionar isto mais tarde quando implementarmos a segurança
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar as rotas.');
    }
  }
}
