// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'carregando...';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setState(() {
        _userRole = decodedToken['role'];
      });
    }
  }

  // Widget para o painel do Admin (placeholder)
  Widget _buildAdminDashboard() {
    return const Center(
      child: Text('Painel do Super Admin', style: TextStyle(fontSize: 24)),
    );
  }

  // Widget para o painel do Motorista (placeholder)
  Widget _buildDriverDashboard() {
    return const Center(
      child: Text('Painel do Motorista', style: TextStyle(fontSize: 24)),
    );
  }

  // Widget para o painel do Passageiro (placeholder)
  Widget _buildPassengerDashboard() {
    return const Center(
      child: Text('Painel do Passageiro', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildDashboardByRole() {
    switch (_userRole) {
      case 'SUPER_ADMIN':
        return _buildAdminDashboard();
      case 'MOTORISTA':
        return _buildDriverDashboard();
      case 'PASSAGEIRO':
        return _buildPassengerDashboard();
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bem-vindo ($_userRole)'),
        backgroundColor: Colors.amber,
      ),
      body: _buildDashboardByRole(),
    );
  }
}
