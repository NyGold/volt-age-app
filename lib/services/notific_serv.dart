// ARQUIVO: lib/services/notific_serv.dart
import 'dart:typed_data'; // Importação necessária para Int64List
import 'package:flutter/material.dart'; // Importação necessária para Color
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // O método de inicialização agora recebe a função que vai lidar com os cliques
  static Future<void> initialize({
    required Function(NotificationResponse) onSelectNotification,
  }) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Define a mesma função para quando o app está aberto ou em background
      onDidReceiveNotificationResponse: onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
    );
    
    // Cria os canais necessários
    await _configureNotificationChannels();
  }

  static Future<void> _configureNotificationChannels() async {
    // Configuração do canal para notificações críticas
    final AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
      'volt_age_channel_critical',
      'Alertas Críticos Volt-Age',
      description: 'Canal para notificações de emergência com ações.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ledColor: Color.fromARGB(255, 255, 0, 0),
    );

    // Configuração do canal para notificações normais
    final AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'volt_age_channel_default',
      'Notificações Volt-Age',
      description: 'Canal para notificações gerais do aplicativo.',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    // Cria os canais
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(criticalChannel);
    
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(defaultChannel);
  }

  // O método para mostrar a notificação agora tem um parâmetro 'isEmergency'
  static Future<void> showNotification({
    required String title,
    required String body,
    String payload = '',
    bool isEmergency = false, // Decide se o botão de ação deve ser adicionado
  }) async {
    
    // Gera um ID único para a notificação
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Lista de ações (botões) para a notificação
    final List<AndroidNotificationAction> actions = isEmergency
        ? [
            const AndroidNotificationAction(
              'FECHAR_GAS_ACTION', // ID único da ação
              'FECHAR GÁS',       // Texto que aparece no botão
              cancelNotification: true, // Fecha a notificação após o clique
            )
          ]
        : [];

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      isEmergency ? 'volt_age_channel_critical' : 'volt_age_channel_default',
      isEmergency ? 'Alertas Críticos Volt-Age' : 'Notificações Volt-Age',
      channelDescription: isEmergency
          ? 'Canal para notificações de emergência com ações.'
          : 'Canal para notificações gerais do aplicativo.',
      importance: isEmergency ? Importance.max : Importance.defaultImportance,
      priority: isEmergency ? Priority.high : Priority.defaultPriority,
      actions: actions, // Adiciona a lista de ações aqui
      playSound: true,
      enableVibration: isEmergency,
      vibrationPattern: isEmergency ? Int64List.fromList([0, 500, 200, 500]) : null,
      ledColor: isEmergency ? Color.fromARGB(255, 255, 0, 0) : null,
    );

    final DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(
          android: androidNotificationDetails,
          iOS: iosNotificationDetails,
        );

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}