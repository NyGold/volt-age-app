import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<MqttServerClient> connect() async {
  final String adafruitAioKey = dotenv.env['ADAFRUIT_AIO_KEY'];
  final String adafruitAioUsername = dotenv.env['ADAFRUIT_AIO_USERNAME'];

  final client = MqttServerClient.withPort('io.adafruit.com', adafruitAioUsername, 1883);

  client.logging(on: true);
  client.keepAlivePeriod = 60;
  client.onDisconnected = onDisconnected;
  client.onConnected = onConnected;
  client.onSubscribed = onSubscribed;

  final connMess = MqttConnectMessage()
      .withClientIdentifier('seu_client_id_unico')
      .withWillTopic('willtopic') // Tópico de "última vontade" (opcional)
      .withWillMessage('My Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);

  print('EXAMPLE::Adafruit client connecting....');
  client.connectionMessage = connMess;

  try {
    await client.connect('seu_username_adafruit', 'sua_chave_aio_adafruit');
  } catch (e) {
    print('Exception: $e');
    client.disconnect();
  }

  if (client.connectionStatus!.state == MqttConnectionState.connected) {
    print('EXAMPLE::Adafruit client connected');
  } else {
    print('EXAMPLE::Adafruit client connection failed - disconnecting, status is ${client.connectionStatus}');
    client.disconnect();
  }

  return client;
}

// callbacks
void onConnected() {
  print('Connected');
}

void onDisconnected() {
  print('Disconnected');
}

void onSubscribed(String topic) {
  print('Subscribed to topic: $topic');
}