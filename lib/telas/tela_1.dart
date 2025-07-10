// tela do modulo de fogo

import 'package:flutter/material.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela1 extends StatefulWidget  {
  const Tela1({super.key});

  @override
  State<Tela1> createState() => _Tela1State();
}

class _Tela1State extends State<Tela1> {
  bool isValvulaAberta = false;
  String estadoValvulaTexto = 'Aguardando dados...';

  @override
  void initState() {
    super.initState();
    inicializarEstado();
  }

  Future<void> inicializarEstado() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final feed = "cozinha.valvula-gas-estado";

    // Busca o último valor via REST API
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-AIO-Key': key!},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final valor = data['value'];
        setState(() {
          isValvulaAberta = valor == "ABERTA";
          estadoValvulaTexto = isValvulaAberta
              ? 'Válvula de gás está ABERTA'
              : 'Válvula de gás está FECHADA';
        });
      }
    } catch (e) {
      print('Erro ao buscar valor inicial: $e');
    }

    // Depois conecta ao MQTT normalmente
    await inicializarMqtt(usuario!);
  }

  Future<void> inicializarMqtt(String usuario) async {
    await connect().then((client) {
      print('Conectado ao MQTT com sucesso');

      client.subscribe("$usuario/feeds/cozinha.valvula-gas-estado", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-app", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-reset", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.gas-alerta", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.valvula-gas-controle", MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final msg in c) {
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topico = msg.topic;

          if (topico.endsWith('valvula-gas-estado')) {
            print('Payload recebido: $payload');
            setState(() {
              isValvulaAberta = payload == "ABERTA";
              estadoValvulaTexto = isValvulaAberta
                  ? 'Válvula de gás está ABERTA'
                  : 'Válvula de gás está FECHADA';
            });
          }
        }
      });
    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
      setState(() {
        estadoValvulaTexto = 'Erro ao conectar ao MQTT';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // muda o icone dependendo do estado da válvula
              isValvulaAberta
                  ? SvgPicture.asset(
                      'assets/icons/fogao_ligado_certo.svg',
                      width: 160,
                      height: 160,
                      colorFilter: ColorFilter.mode(
                        Colors.deepOrange,
                        BlendMode.srcIn,
                      ),
                    )
                    // todo: adicionar icone de alerta quando a válvula estiver fechada, condizente ao icone acima
                  : Icon(
                      Icons.lock,
                      color: Colors.green,
                      size: 60,
                    ),
              const SizedBox(height: 16),
              Text(
                estadoValvulaTexto,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isValvulaAberta ? Colors.deepOrange : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isValvulaAberta ? Colors.green : Colors.deepOrange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                // NÃO defina minimumSize ou fixedSize!
                fixedSize: const Size(200, 60)
              ),
              onPressed: () {
                final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
                final key = dotenv.env["ADAFRUIT_IO_KEY"];
                final feed = "cozinha.valvula-gas-controle";
                final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data';
                final valor = isValvulaAberta ? "FECHADA" : "ABERTA";
                final body = json.encode({"value": valor});
                http.post(
                  Uri.parse(url),
                  headers: {
                    'X-AIO-Key': key!,
                    'Content-Type': 'application/json',
                  },
                  body: body,
                ).then((response) {
                  if (response.statusCode == 200) {
                    print('Comando enviado com sucesso: $valor');
                    setState(() {
                      isValvulaAberta = !isValvulaAberta;
                      estadoValvulaTexto = isValvulaAberta
                          ? 'Válvula de gás está ABERTA'
                          : 'Válvula de gás está FECHADA';
                    });
                  } else {
                    print('Erro ao enviar comando: ${response.body}');
                  }
                }).catchError((error) {
                  print('Erro ao enviar comando: $error');
                });
              },
              child: Text(
                isValvulaAberta ? 'Fechar Válvula' : 'Abrir Válvula',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}