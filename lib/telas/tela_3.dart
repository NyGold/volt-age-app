// tela do modulo de iluminação

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
  String luzStatus = 'Aguardando dados...';
  Color corSelecionada = Colors.white;

  @override
  void initState() {
    super.initState();
    inicializarEstado();
  }

  Future<void> inicializarEstado() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];

    // Busca o último valor do status via REST API
    await buscarValorFeed(usuario!, key!, "iluminacao-status", (valor) {
      setState(() => luzStatus = valor);
    });

    // Conecta ao MQTT
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

      // Subscreve ao feed de status
      client.subscribe("$usuario/feeds/iluminacao-status", MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final msg in c) {
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topico = msg.topic;

          if (topico.endsWith('iluminacao-status')) {
            setState(() => luzStatus = payload);
          }
        }
      });
    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
      setState(() {
        luzStatus = 'Erro ao conectar ao MQTT';
      });
    });
  }

  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> enviarComando(String comando) async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/iluminacao-comando/data';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-AIO-Key': key!,
          'Content-Type': 'application/json',
        },
        body: json.encode({'value': comando}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comando enviado: $comando')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar comando')),
        );
      }
    } catch (e) {
      print('Erro ao enviar comando: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar comando')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Status das luzes: $luzStatus', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => enviarComando('AUTOMATICO'),
                child: const Text('LED Automático'),
              ),
              ElevatedButton(
                onPressed: () => enviarComando('LIGAR_MANUAL'),
                child: const Text('Ligar LED'),
              ),
              ElevatedButton(
                onPressed: () => enviarComando('DESLIGAR_MANUAL'),
                child: const Text('Desligar LED'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Escolha a cor da fita de LED:', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          ColorPicker(
            pickerColor: corSelecionada,
            onColorChanged: (color) {
              setState(() {
                corSelecionada = color;
              });
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            showLabel: false,
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: corSelecionada,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  final hex = colorToHex(corSelecionada);
                  enviarComando(hex);
                },
                child: const Text('Enviar Cor'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
