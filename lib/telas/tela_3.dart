// tela do modulo de iluminação

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';

class Tela3 extends StatefulWidget {
  const Tela3({super.key});

  @override
  State<Tela3> createState() => _Tela3State();
}

class _Tela3State extends State<Tela3> {
  @override
  void initState() {
    super.initState();

    // Aqui você pode inicializar o MQTT ou outras configurações necessárias.
  }

  Future<void> initMqttIluminacao() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];

    await connect().then((client) {
      print('Conectado ao MQTT com sucesso!');

      // Inscreve-se nos tópicos necessários
      client.subscribe("$usuario/groups/iluminacao/feeds/luz-estado", MqttQos.atLeastOnce);
      client.subscribe("$usuario/groups/iluminacao/feeds/luz-intensidade", MqttQos.atLeastOnce);

      // Escuta as atualizações dos tópicos
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        for (final msg in c) {
          final recMess = msg.payload as MqttPublishMessage;
          final mensagem = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topico = msg.topic;

          if (topico.endsWith('luz-estado')) {
            // Lógica para lidar com o estado da luz
            print('Estado da luz: $mensagem');
          } else if (topico.endsWith('luz-intensidade')) {
            // Lógica para lidar com a intensidade da luz
            print('Intensidade da luz: $mensagem');
          }
        }
      });
    }).catchError((error) {
      print('Erro ao conectar ao MQTT: $error');
    });

    // Implemente a lógica de conexão MQTT aqui, se necessário.
    // Por exemplo, inscreva-se em tópicos relevantes e configure callbacks.
  }


  @override
  Widget build(BuildContext context) {
    // Substitua este widget pelo conteúdo real da sua tela.
    return Container(
       padding: const EdgeInsets.all(16.0),
       child: const Center(
         child: Text(
          'Conteúdo do modulo de luz',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
         ),
       ),
    );
  }
}
