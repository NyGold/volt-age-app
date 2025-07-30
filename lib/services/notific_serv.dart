// ARQUIVO: lib/services/notific_serv.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui'; // Import adicionado para a classe Color

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize({
    required Function(NotificationResponse) onSelectNotification,
  }) async {
    // Configuração específica para Android
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Criação do canal de notificações CRÍTICAS (necessário para Android 8.0+)
    final AndroidNotificationChannel androidNotificationChannel =
        AndroidNotificationChannel(
      'volt_age_channel_critical', // ID do canal
      'Alertas Críticos Volt-Age', // Título do canal
      description: 'Canal para notificações de emergência com ações.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );
    
    // Inicializa os canais de notificação
    await _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
    
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
    );
    
    // Para dispositivos iOS, solicita permissão
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }
  
  static Future<void> showNotification({
    required String title,
    required String body,
    String payload = '',
    bool isEmergency = false,
  }) async {
    // Lista de ações (botões) para a notificação
    final List<AndroidNotificationAction> actions = isEmergency
        ? [
            AndroidNotificationAction(
              'FECHAR_GAS_ACTION',
              'FECHAR GÁS',
              cancelNotification: true,
              // Correção: Color agora é reconhecida graças ao import do dart:ui
              titleColor: const Color(0xFFFFFFFF),
              icon: const DrawableResourceAndroidBitmap('ic_launcher'),
            )
          ]
        : [];
    
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'volt_age_channel_critical',
      'Alertas Críticos Volt-Age',
      channelDescription: 'Canal para notificações de emergência com ações.',
      importance: Importance.max,
      priority: Priority.high,
      actions: actions,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      fullScreenIntent: isEmergency,
      // Usando AndroidNotificationCategory.alarm em vez de emergency
      category: AndroidNotificationCategory.alarm,
    );
    
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}