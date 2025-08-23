// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userRole;
  final ApiService _apiService = ApiService();

  // Variável para guardar o resultado da nossa chamada à API
  Future<List<dynamic>>? _routesFuture;

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndData();
  }

  Future<void> _loadUserInfoAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    String? role;

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      role = decodedToken['role'];
    }

    // Atualizamos o estado e, se for admin, iniciamos a chamada à API
    setState(() {
      _userRole = role ?? 'desconhecido';
      if (_userRole == 'SUPER_ADMIN') {
        _routesFuture = _apiService.getRoutes();
      }
    });
  }

  // --- PAINEL DO ADMIN ATUALIZADO ---
  Widget _buildAdminDashboard() {
    return FutureBuilder<List<dynamic>>(
      // Usamos a nossa variável de estado aqui
      future: _routesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Mostra o erro detalhado para depuração
          return Center(
            child: Text('Erro ao carregar rotas: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma rota encontrada.'));
        }

        final routes = snapshot.data!;
        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return ListTile(
              leading: const Icon(Icons.route, color: Colors.amber),
              title: Text(route['name']),
              subtitle: Text('Motorista ID: ${route['driver_id']}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // TODO: Navegar para a tela de detalhes da rota
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDriverDashboard() {
    return const Center(
      child: Text('Painel do Motorista', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildPassengerDashboard() {
    return const Center(
      child: Text('Painel do Passageiro', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildDashboardByRole() {
    if (_userRole == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_userRole) {
      case 'SUPER_ADMIN':
        return _buildAdminDashboard();
      case 'MOTORISTA':
        return _buildDriverDashboard();
      case 'PASSAGEIRO':
        return _buildPassengerDashboard();
      default:
        return const Center(child: Text('Papel de utilizador desconhecido.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Painel Principal (${_userRole ?? ''})'),
        backgroundColor: Colors.amber,
      ),
      body: _buildDashboardByRole(),
      floatingActionButton:
          _userRole == 'SUPER_ADMIN'
              ? FloatingActionButton(
                onPressed: () {
                  // TODO: Navegar para a tela de criação de rota
                },
                backgroundColor: Colors.amber,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
