// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Importar o nosso serviço de API

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.login(
        _emailController.text,
        _passwordController.text,
      );
      // Se o login for bem-sucedido, pode navegar para a próxima tela
      print('Login bem-sucedido! Token: ${result['token']}');
      // TODO: Navegar para a tela principal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login bem-sucedido, ${result['user']['name']}!'),
        ),
      );
    } catch (e) {
      // Mostrar uma mensagem de erro
      print('Erro no login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer login. Verifique as suas credenciais.'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - App da Van'),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Palavra-passe'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('Entrar'),
                ),
          ],
        ),
      ),
    );
  }
}
