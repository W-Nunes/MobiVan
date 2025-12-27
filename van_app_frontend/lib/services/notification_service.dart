import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Inicializa e pede permissão
  Future<void> initialize() async {
    // 1. Pedir permissão (Obrigatório para Android 13+ e iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 Permissão de notificação: CONCEDIDA');

      // 2. Pegar o Token do dispositivo
      // Esse token é o que o Backend vai usar para enviar msg para ESTE celular
      String? token = await _firebaseMessaging.getToken();
      print('🔥 FCM TOKEN (Copie isso): $token');

      // Configurar listeners
      _setupForegroundHandler();
    } else {
      print('🔕 Permissão de notificação: NEGADA');
    }
  }

  // O que fazer se a notificação chegar com o app ABERTO
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Notificação recebida em 1º plano!');
      if (message.notification != null) {
        print('Título: ${message.notification!.title}');
        print('Corpo: ${message.notification!.body}');

        // Aqui podemos mostrar um SnackBar ou Dialog futuramente
      }
    });
  }
}