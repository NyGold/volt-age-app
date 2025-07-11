/* TODO:  
*  publicar o valor correto para ignorar e ativar a lógica de esquecimento
*  adicionar a opção na notificação de fechar a valvula
*/
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart'; // Importa o serviço MQTT
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';

class NotificacaoService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        print('Ação da notificação: ${response.actionId}');
        if (response.actionId == 'reniciar-timer') {
          print('Enviando RESET_TIMER para o MQTT...');
          final client = await connect();
          print('MQTT conectado? ${client.connectionStatus?.state}');
          final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
          final topic = "$usuario/feeds/cozinha.fogo-timer-reset";
          final builder = MqttClientPayloadBuilder();
          builder.addString("RESET_TIMER");
          client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
          print('Mensagem enviada!');
        }
      },
    );
  }

  static Future<void> enviarNotificacaoGasAberto() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gas_alerta_channel',
      'Alertas de Gás',
      importance: Importance.max,
      color: Color(0xFFe53935),
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'reniciar-timer', // id da ação
          'reniciar temporizador',
        ),
      ],
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'Alerta de Gás',
      'Atenção! o gás está aberto!',
      details,
    );
  }
}