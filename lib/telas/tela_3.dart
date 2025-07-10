// tela do modulo de iluminação

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela3 extends StatefulWidget {
  const Tela3({super.key});

  @override
  State<Tela3> createState() => _Tela3State();
}

class _Tela3State extends State<Tela3> {
  String luzEstado = 'Aguardando dados...';
  String luzIntensidade = 'Aguardando dados...';

  @override
  void initState() {
    super.initState();
    inicializarEstado();
  }

  Future<void> inicializarEstado() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];

    // Busca o último valor de cada feed via REST API
    await buscarValorFeed(usuario!, key!, "iluminacao.luz-estado", (valor) {
      setState(() => luzEstado = valor);
    });
    await buscarValorFeed(usuario, key, "iluminacao.luz-intensidade", (valor) {
      setState(() => luzIntensidade = valor);
    });

    // Depois conecta ao MQTT normalmente
    await inicializarMqtt(usuario);
  }

  Future<void> buscarValorFeed(String usuario, String key, String feed, Function(String) onValor) async {
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-AIO-Key': key},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final valor = data['value'].toString();
        onValor(valor);
      }
    } catch (e) {
      print('Erro ao buscar valor inicial do feed $feed: $e');
    }
  }

  Future<void> inicializarMqtt(String usuario) async {
    await connect().then((client) {
      print('Conectado ao MQTT com sucesso!');

      client.subscribe("$usuario/feeds/iluminacao.luz-estado", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/iluminacao.luz-intensidade", MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final msg in c) {
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topico = msg.topic;

          if (topico.endsWith('luz-estado')) {
            setState(() => luzEstado = payload);
          } else if (topico.endsWith('luz-intensidade')) {
            setState(() => luzIntensidade = payload);
          }
        }
      });
    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
      setState(() {
        luzEstado = 'Erro ao conectar ao MQTT';
        luzIntensidade = 'Erro ao conectar ao MQTT';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Estado da luz: $luzEstado', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Intensidade da luz: $luzIntensidade', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
