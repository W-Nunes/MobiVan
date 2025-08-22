// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // Importar a nossa nova tela

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App da Van',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(), // A nossa tela de login é a tela inicial
    );
  }
}
