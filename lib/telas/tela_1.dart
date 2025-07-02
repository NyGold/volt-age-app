// tela do modulo de fogo

import 'package:flutter/material.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    inicializarMqtt();
  }

  Future<void> inicializarMqtt() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];

    await connect().then((client) {
      print('Conectado ao MQTT com sucesso!');

      // Inscreve-se nos tópicos necessários
      client.subscribe("$usuario/feeds/cozinha.valvula-gas-estado", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-app", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-reset", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.gas-alerta", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.valvula-gas-controle", MqttQos.atLeastOnce);      

      // Escuta as atualizações dos tópicos
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        print("Mensagem recebida do MQTT!");
        // Processa todas as mensagens recebidas
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
          // Aqui você pode adicionar lógica para outros tópicos se desejar
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isValvulaAberta ? Icons.lock_open : Icons.lock,
              color: isValvulaAberta ? Colors.green : Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              estadoValvulaTexto,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isValvulaAberta ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}