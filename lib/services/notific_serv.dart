import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificacaoService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _ignorePeriodKey = 'ignore_notifications_until';
  
  // Tópicos MQTT
  static String get _baseTopico => "${dotenv.env["ADAFRUIT_IO_USERNAME"]}/feeds/cozinha";
  static String get topicoGasAlerta => "$_baseTopico.gas-alerta";
  static String get topicoValvulaEstado => "$_baseTopico.valvula-gas-estado";
  static String get topicoValvulaControle => "$_baseTopico.valvula-gas-controle";
  static String get topicoFogoTimerReset => "$_baseTopico.fogo-timer-reset";
  static String get topicoFogoTimerApp => "$_baseTopico.fogo-timer-app";

  // Comandos MQTT
  static const String cmdFecharValvula = "FECHAR_AGORA";
  static const String cmdResetTimer = "RESET_TIMER";
  static const String cmdAtivarTimer = "ATIVAR_TIMER";
  
  // Configurações de tempo para notificações
  static const Duration tempoLembreteGas = Duration(minutes: 30);
  static const Duration tempoIgnorarPadrao = Duration(hours: 1);
  
  // Níveis de prioridade
  static const int prioridadeBaixa = 0;
  static const int prioridadeMedia = 1;
  static const int prioridadeAlta = 2;

  static Future<void> inicializar() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        print('Ação da notificação: ${response.actionId}');
        switch (response.actionId) {
          case 'fechar-valvula':
            await _enviarComandoMQTT(cmdFecharValvula);
            break;
          case 'ativar-timer':
            await _enviarComandoMQTT(cmdAtivarTimer);
            break;
          case 'ignorar':
            await _ignorarNotificacoes(tempoIgnorarPadrao);
            break;
        }
      },
    );
  }

  static Future<void> enviarNotificacaoGasAberto() async {
    // Verifica se as notificações estão sendo ignoradas
    if (await _deveIgnorarNotificacao()) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gas_alerta_channel',
      'Alertas de Gás',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFe53935),
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'fechar-valvula',
          'Fechar Válvula',
        ),
        AndroidNotificationAction(
          'ativar-timer',
          'Ativar Timer',
        ),
        AndroidNotificationAction(
          'ignorar',
          'Ignorar por 1h',
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

  static Future<void> _enviarComandoMQTT(String comando) async {
    final client = await connect();
    String topic;
    
    switch (comando) {
      case cmdFecharValvula:
        topic = topicoValvulaControle;
        break;
      case cmdResetTimer:
        topic = topicoFogoTimerReset;
        break;
      case cmdAtivarTimer:
        topic = topicoFogoTimerApp;
        break;
      default:
        throw Exception('Comando MQTT inválido: $comando');
    }
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(comando);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  static Future<void> _ignorarNotificacoes(Duration duracao) async {
    final prefs = await SharedPreferences.getInstance();
    final ignorarAte = DateTime.now().add(duracao).millisecondsSinceEpoch;
    await prefs.setInt(_ignorePeriodKey, ignorarAte);
  }

  static Future<bool> _deveIgnorarNotificacao() async {
    final prefs = await SharedPreferences.getInstance();
    final ignorarAte = prefs.getInt(_ignorePeriodKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < ignorarAte;
  }
}