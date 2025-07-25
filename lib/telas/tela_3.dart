/* TODO: 
* 1 criar os stream na home_page com os tópicos que ele vai ouvir
* 2 passar os streams para as telas que vão ouvir
* 3 criar os streams nas telas que vão ouvir
* 4 criar os listeners para atualizar o estado das telas
* 5 criar os métodos de publicar comandos para cada tela
* 6 criar os métodos de publicar comandos em background para cada tela 

* qualquer coisa é só ver o gemini ou ver tela_1 que já está quase tudo certo.
*/

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';


class Tela3 extends StatefulWidget {
  final MqttClient? mqttClient;

  const Tela3({super.key, this.mqttClient});

  @override
  State<Tela3> createState() => _Tela3State();
}

class _Tela3State extends State<Tela3> {
  String luzStatus = 'Carregando...';
  bool get isLuzAcesa => luzStatus.toUpperCase() == 'ACESA';
  MqttClient? mqttClient;

  // Feeds do Adafruit IO
  final feedStatus = "iluminacao-status";
  final feedComando = "iluminacao-comando";

  @override
  void initState() {
    super.initState();
  }

  void _publicarComando(String comando) {
    if (mqttClient == null || mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MQTT não conectado. Tente novamente.')),
      );
      return;
    }

    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final comandoTopic = "$usuario/feeds/$feedComando";
    final builder = MqttClientPayloadBuilder();
    builder.addString(comando);

    print('Publicando no tópico $comandoTopic: $comando');
    mqttClient?.publishMessage(comandoTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              _buildCardStatus(),
              const SizedBox(height: 30),
              _buildCardControleManual(),
               const SizedBox(height: 20),
              _buildCardModoAutomatico(),
              const SizedBox(height: 20),
              _buildCardControleCor(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStatus() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Icon(
              isLuzAcesa ? Icons.lightbulb : Icons.lightbulb_outline,
              size: 80,
              color: isLuzAcesa ? Colors.amber.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            const Text(
              'Status Atual da Iluminação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              luzStatus,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isLuzAcesa ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControleManual() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Controle Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _publicarComando('LIGAR_MANUAL'),
                  icon: const Icon(Icons.wb_sunny),
                  label: const Text('Ligar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _publicarComando('DESLIGAR_MANUAL'),
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('Desligar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildCardModoAutomatico() {
    return Card(
       elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             const Text('Modo Automático', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _publicarComando('AUTOMATICO'),
              icon: const Icon(Icons.brightness_auto),
              label: const Text('Ativar Modo Automático'),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCardControleCor() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Controle de Cor (Fita LED)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildColorButton(Colors.red, '#FF0000'),
                _buildColorButton(Colors.green, '#00FF00'),
                _buildColorButton(Colors.blue, '#0000FF'),
                _buildColorButton(Colors.yellow, '#FFFF00'),
                _buildColorButton(Colors.purple, '#800080'),
                _buildColorButton(Colors.white, '#FFFFFF'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color, String hexCode) {
    return InkWell(
      onTap: () => _publicarComando(hexCode),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    );
  }
}