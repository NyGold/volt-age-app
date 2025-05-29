import 'dart:async';
import 'dart:io';
import 'dart:math'; // Importa a biblioteca para gerar números aleatórios
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MqttService {
  final String server = 'io.adafruit.com';
  final int port = 8883;
  final String username = dotenv.env['ADAFRUIT_IO_USERNAME']!;  // Seu username
  final String apiKey = dotenv.env['ADAFRUIT_IO_KEY']!;         // Sua AIO Key

  // --- FIX 1: Client ID mais simples e aleatório ---
  final String clientIdentifier = 'flutterClient-${Random().nextInt(100000)}';

  late MqttServerClient client;
  final StreamController<String> _messageStreamController = StreamController<String>.broadcast();

  Stream<String> get messages => _messageStreamController.stream;

  Future<void> connect() async {

    client = MqttServerClient.withPort(server, clientIdentifier, port);

    // Configurações de segurança
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.onBadCertificate = (dynamic certificate) => true;

    // --- FIX 2: Restaurar o Keep Alive Period ---
    client.keepAlivePeriod = 60;

    // Configurações de log e callbacks
    client.logging(on: true);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean();
    client.connectionMessage = connMessage;

    try {
      print('--- TENTATIVA FINAL DE CONEXÃO ---');
      await client.connect(username, apiKey);
    } catch (e) {
      print('Exceção: $e');
      client.disconnect();
    }
  }

  void onConnected() {
    print('✅✅✅ CONECTADO COM SUCESSO AO ADAFRUIT IO! ✅✅✅');
    final topic = '$username/feeds/teste-volt-age'; // IMPORTANTE: use o nome do seu feed
    client.subscribe(topic, MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MENSAGEM RECEBIDA: $pt');
      _messageStreamController.add(pt);
    });
  }

  void onDisconnected() {
    print('Desconectado do broker MQTT.');
  }

  void onSubscribed(String topic) {
    print('Inscrito no tópico: $topic');
  }

  void pong() {
    print('Ping response recebido.');
  }

  void publish(String message) {
    final topic = '$username/feeds/teste-volt-age'; // IMPORTANTE: use o nome do seu feed
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('Mensagem "$message" publicada no tópico $topic');
    } else {
      print('Não foi possível publicar. Cliente não conectado.');
    }
  }

  void disconnect() {
    client.disconnect();
  }
}