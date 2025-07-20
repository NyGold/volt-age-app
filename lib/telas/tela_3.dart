import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart'; // Mantenha seu import do serviço MQTT
import 'package:mqtt_client/mqtt_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela3 extends StatefulWidget {
  const Tela3({super.key});

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
    _inicializarConexao();
  }

  Future<void> _inicializarConexao() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];

    if (usuario == null || key == null) {
      if (mounted) setState(() => luzStatus = "Erro: .env");
      return;
    }

    // 1. Busca o estado inicial via API REST
    await _buscarEstadoInicial(usuario, key);

    // 2. Conecta ao Broker MQTT
    try {
      final client = await connect();
      if (mounted) setState(() => mqttClient = client);
      print('MQTT Conectado com sucesso!');
      _configurarMqttListeners(usuario);
    } catch (e) {
      print('Erro ao conectar ao MQTT: $e');
      if (mounted) setState(() => luzStatus = 'Erro de conexão');
    }
  }

  Future<void> _buscarEstadoInicial(String usuario, String key) async {
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feedStatus/data/last';
    try {
      final response = await http.get(Uri.parse(url), headers: {'X-AIO-Key': key});
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() => luzStatus = data['value'].toString());
      } else {
         if (mounted) setState(() => luzStatus = 'Sem dados');
      }
    } catch (e) {
      print('Erro ao buscar valor inicial: $e');
      if (mounted) setState(() => luzStatus = 'Falha ao buscar');
    }
  }

  void _configurarMqttListeners(String usuario) {
    final statusTopic = "$usuario/feeds/$feedStatus";
    mqttClient?.subscribe(statusTopic, MqttQos.atLeastOnce);

    mqttClient?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      if (topic == statusTopic && mounted) {
        setState(() => luzStatus = payload);
      }
    });
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