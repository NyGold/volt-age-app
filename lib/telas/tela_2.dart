// tela do modulo de jardinagem

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela2 extends StatefulWidget {
  const Tela2({super.key});

  @override
  State<Tela2> createState() => _Tela2State();
}

class _Tela2State extends State<Tela2> {
  String umidadeSolo = 'Aguardando dados...';
  String statusRega = 'Aguardando dados...';
  String limiarUmidade = 'Aguardando dados...';

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
    await buscarValorFeed(usuario!, key!, "jardinagem.jardim-umidade-solo", (valor) {
      setState(() => umidadeSolo = valor);
    });
    await buscarValorFeed(usuario, key, "jardinagem.jardim-status-rega", (valor) {
      setState(() => statusRega = valor);
    });
    await buscarValorFeed(usuario, key, "jardinagem.jardim-limiar-umidade", (valor) {
      setState(() => limiarUmidade = valor);
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

      client.subscribe("$usuario/feeds/jardinagem.jardim-umidade-solo", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/jardinagem.jardim-status-rega", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/jardinagem.jardim-limiar-umidade", MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final msg in c) {
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topico = msg.topic;

          if (topico.endsWith('jardim-umidade-solo')) {
            setState(() => umidadeSolo = payload);
          } else if (topico.endsWith('jardim-status-rega')) {
            setState(() => statusRega = payload);
          } else if (topico.endsWith('jardim-limiar-umidade')) {
            setState(() => limiarUmidade = payload);
          }
        }
      });
    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
      setState(() {
        umidadeSolo = 'Erro ao conectar ao MQTT';
        statusRega = 'Erro ao conectar ao MQTT';
        limiarUmidade = 'Erro ao conectar ao MQTT';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildBloco("Umidade do solo", umidadeSolo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBloco(String titulo, String valor) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}