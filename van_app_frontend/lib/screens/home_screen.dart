// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_service.dart';
import 'create_route_screen.dart';
import 'map_screen.dart'; // Importar o novo ecrã

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userRole;
  int? _userId;
  String? _token;
  final ApiService _apiService = ApiService();

  Future<List<dynamic>>? _routesFuture;
  Future<Map<String, dynamic>>? _myRouteFuture;

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndData();
  }

  Future<void> _loadUserInfoAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    String? role;
    int? userId;

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      role = decodedToken['role'];
      userId = decodedToken['userId'];
    }

    setState(() {
      _userRole = role ?? 'desconhecido';
      _userId = userId;
      _token = token;

      if (_userRole == 'SUPER_ADMIN') {
        _routesFuture = _apiService.getRoutes();
      } else if (_userRole == 'PASSAGEIRO' && _userId != null) {
        _myRouteFuture = _apiService.getMyRoute(_userId!);
      }
    });
  }

  Widget _buildAdminDashboard() {
    // (Código existente)
    return FutureBuilder<List<dynamic>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
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

  // --- PAINEL DO PASSAGEIRO ATUALIZADO ---
  Widget _buildPassengerDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _myRouteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text('Não está associado a nenhuma rota.'),
          );
        }

        final route = snapshot.data!;
        final routeId = route['id'];

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A sua Rota',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route['name'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text('Motorista ID: ${route['driver_id']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // BOTÃO PARA O MAPA
              ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('VER MAPA EM TEMPO REAL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  if (_token != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                MapScreen(routeId: routeId, token: _token!),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Confirmar presença para hoje:',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('CONFIRMAR IDA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => _handleConfirmation(routeId, 'CONFIRMED'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('NÃO VOU'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => _handleConfirmation(routeId, 'CANCELLED'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleConfirmation(int routeId, String status) async {
    try {
      await _apiService.confirmPresence(_userId!, routeId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Presença ${status == 'CONFIRMED' ? 'confirmada' : 'cancelada'} com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar presença: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDashboardByRole() {
    // (Código existente)
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
    // (Código existente)
    return Scaffold(
      appBar: AppBar(
        title: Text('Painel Principal (${_userRole ?? ''})'),
        backgroundColor: Colors.amber,
      ),
      body: _buildDashboardByRole(),
      floatingActionButton:
          _userRole == 'SUPER_ADMIN'
              ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateRouteScreen(),
                    ),
                  );
                  if (result == true) {
                    setState(() {
                      _routesFuture = _apiService.getRoutes();
                    });
                  }
                },
                backgroundColor: Colors.amber,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
