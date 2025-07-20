import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// A função agora aceita um parâmetro opcional {bool isBackground = false}
Future<MqttClient> connect({bool isBackground = false}) async {
  await dotenv.load();
  final String broker = dotenv.env['ADAFRUIT_IO_URL'] ?? '';
  
  // **CORREÇÃO:** Adicionada lógica para usar uma porta padrão se a do .env falhar.
  final String portString = dotenv.env['ADAFRUIT_IO_PORT'] ?? '8883';
  final int port = int.tryParse(portString) ?? 8883; // Usa 8883 se a conversão falhar.

  final String user = dotenv.env['ADAFRUIT_IO_USERNAME'] ?? '';
  final String key = dotenv.env['ADAFRUIT_IO_KEY'] ?? '';
  
  // Gera um ID de cliente único para tarefas de background para evitar conflitos
  final String clientId = isBackground 
    ? 'volt_age_background_${DateTime.now().millisecondsSinceEpoch}' 
    : 'volt_age_app_mobile';

  MqttServerClient client = MqttServerClient.withPort(broker, clientId, port);
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
