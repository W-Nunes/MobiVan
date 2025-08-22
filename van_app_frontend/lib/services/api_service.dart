// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ATENÇÃO: O URL base da nossa API.
  // Se estiver a usar um emulador Android, 'localhost' é mapeado para '10.0.2.2'.
  // Se estiver a usar um dispositivo físico, substitua pelo IP da sua máquina na rede local (ex: '192.168.1.10').
  final String _baseUrl =
      "http://localhost:3001"; // Corrigido para a porta 3001 do auth-service

  // Função de Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    // O endpoint correto é /login, que o nosso API Gateway irá redirecionar
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Guardar o token de forma segura
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      // Lançar um erro se o login falhar
      final errorBody = jsonDecode(response.body);
      throw Exception('Falha ao fazer login: ${errorBody['error']}');
    }
  }
}
