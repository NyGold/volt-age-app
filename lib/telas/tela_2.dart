// tela do modulo de jardinagem

import 'package:flutter/material.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class Tela2 extends StatefulWidget {
  const Tela2({super.key});

  @override
  State<Tela2> createState() => _Tela2State();
}

class _Tela2State extends State<Tela2> {
  String umidadeSolo = '---';
  String statusRega = '---';
  String limiarUmidade = '---';

  @override
  void initState() {
    super.initState();
    initMQTT();
  }

  Future<void> initMQTT() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];

    await connect().then((client) {
      print('Conectado ao MQTT com sucesso!');

      // Inscreve-se nos tópicos necessários
      client.subscribe("$usuario/groups/jardinagem/feeds/jardim-umidade-solo", MqttQos.atLeastOnce);
      client.subscribe("$usuario/groups/jardinagem/feeds/jardim-status-rega", MqttQos.atLeastOnce);
      client.subscribe("$usuario/groups/jardinagem/feeds/jardim-limiar-umidade", MqttQos.atLeastOnce);

      // Escuta as atualizações dos tópicos
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        setState(() {
          for (final msg in c) {
            final recMess = msg.payload as MqttPublishMessage;
            final mensagem = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
            final topico = msg.topic;

            if (topico.endsWith('jardim-umidade-solo')) {
              umidadeSolo = mensagem;
            } else if (topico.endsWith('jardim-status-rega')) {
              statusRega = mensagem;
            } else if (topico.endsWith('jardim-limiar-umidade')) {
              limiarUmidade = mensagem;
            }
          }
        });
      });

    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Umidade do solo: $umidadeSolo', style: const TextStyle(fontSize: 18)),
          Text('Status da rega: $statusRega', style: const TextStyle(fontSize: 18)),
          Text('Limiar de umidade: $limiarUmidade', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}