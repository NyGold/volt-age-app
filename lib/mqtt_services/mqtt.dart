import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

Future<MqttServerClient> connect() async {
  final String username = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
  final String key = dotenv.env["ADAFRUIT_IO_KEY"]!;
  final idUnico = Random().nextInt(1000000).toString(); // Gera um ID único aleatório

  final client = MqttServerClient.withPort('io.adafruit.com', username, 1883);

  client.logging(on: true);
  client.keepAlivePeriod = 60;
  client.onDisconnected = onDisconnected;
  client.onConnected = onConnected;
  client.onSubscribed = onSubscribed;

  final connMess = MqttConnectMessage()
      .withClientIdentifier(idUnico)
      .withWillTopic('willtopic') // Tópico de "última vontade" (opcional)
      .withWillMessage('My Will message')
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);

  print('EXAMPLE::Adafruit client connecting....');
  client.connectionMessage = connMess;

  try {
    await client.connect(username, key);
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