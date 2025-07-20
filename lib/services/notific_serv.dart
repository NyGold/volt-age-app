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

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Define a mesma função para quando o app está aberto ou em background
      onDidReceiveNotificationResponse: onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
    );
  }

  // O método para mostrar a notificação agora tem um parâmetro 'isEmergency'
  static Future<void> showNotification({
    required String title,
    required String body,
    String payload = '',
    bool isEmergency = false, // Decide se o botão de ação deve ser adicionado
  }) async {
    
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
      'volt_age_channel_critical', // ID do Canal
      'Alertas Críticos Volt-Age', // Nome do Canal
      channelDescription: 'Canal para notificações de emergência com ações.',
      importance: Importance.max,
      priority: Priority.high,
      actions: actions, // Adiciona a lista de ações aqui
      playSound: true,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond, // ID único para a notificação
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
