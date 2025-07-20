import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io'; // Import necessário para SecurityContext

// A função agora aceita um parâmetro opcional {bool isBackground = false}
Future<MqttClient> connect({bool isBackground = false}) async {
  await dotenv.load();
  
  final String broker = dotenv.env['ADAFRUIT_IO_URL'] ?? 'io.adafruit.com';
  final String portString = dotenv.env['ADAFRUIT_IO_PORT'] ?? '8883';
  final int port = int.tryParse(portString) ?? 8883;

  final String user = dotenv.env['ADAFRUIT_IO_USERNAME'] ?? '';
  final String key = dotenv.env['ADAFRUIT_IO_KEY'] ?? '';
  
  final String clientId = isBackground 
    ? 'volt_age_background_${DateTime.now().millisecondsSinceEpoch}' 
    : 'volt_age_app_mobile';

  // --- ADICIONADO PARA DEBUG ---
  print('--- Tentando conectar ao MQTT ---');
  print('Broker: $broker');
  print('Porta: $port');
  print('Usuário: $user');
  print('Chave AIO: ${key.isNotEmpty ? "${key.substring(0, 4)}..." : "NÃO ENCONTRADA"}');
  print('ID do Cliente: $clientId');
  print('---------------------------------');
  // --- FIM DO CÓDIGO DE DEBUG ---

  MqttServerClient client = MqttServerClient.withPort(broker, clientId, port);
  
  // **CORREÇÃO:** Força o uso de uma conexão segura (TLS), que é necessária para a porta 8883.
  client.secure = true;
  client.securityContext = SecurityContext.defaultContext;
  client.logging(on: false);
  client.setProtocolV311();
  client.keepAlivePeriod = 60;
  client.onDisconnected = onDisconnected;
  client.onConnected = onConnected;
  client.onSubscribed = onSubscribed;

  final connMess = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .authenticateAs(user, key)
      .withWillTopic('willtopic')
      .withWillMessage('My Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);
  client.connectionMessage = connMess;

  try {
    await client.connect();
  } on Exception catch (e) {
    print('Exception: $e');
    client.disconnect();
    rethrow;
  }

  return client;
}

void onSubscribed(String topic) {
  print('Subscription confirmed for topic $topic');
}

void onDisconnected() {
  print('Disconnected');
}

void onConnected() {
  print('Connected');
}
