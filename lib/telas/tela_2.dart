import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela2 extends StatefulWidget {
  const Tela2({super.key});

  @override
  State<Tela2> createState() => _Tela2State();
}

class _Tela2State extends State<Tela2> {
  MqttClient? mqttClient;
  double umidadeSolo = 0.0;
  double limiarUmidade = 35.0; // Valor inicial padrão
  String statusRega = "Carregando...";

  // Feeds da Jardinagem
  final feedUmidadeSolo = "jardim-umidade-solo";
  final feedStatusRega = "jardim-status-rega";
  final feedLimiarUmidade = "jardim-limiar-umidade";

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
      if (mounted) setState(() => statusRega = "Erro no .env");
      return;
    }

    await _buscarValoresIniciais(usuario, key);

    try {
      final client = await connect();
      if (mounted) {
        setState(() {
          mqttClient = client;
        });
        _configurarMqttListeners(usuario);
      }
    } catch (e) {
      print('Erro ao conectar ao MQTT: $e');
      if (mounted && statusRega == "Carregando...") {
        setState(() => statusRega = "Erro de Conexão");
      }
    }
  }

  Future<void> _buscarValoresIniciais(String usuario, String key) async {
    await _fetchLastValue(usuario, key, feedUmidadeSolo, (valor) {
      if (mounted) setState(() => umidadeSolo = double.tryParse(valor) ?? 0.0);
    });
    await _fetchLastValue(usuario, key, feedStatusRega, (valor) {
      if (mounted) setState(() => statusRega = valor);
    });
    await _fetchLastValue(usuario, key, feedLimiarUmidade, (valor) {
      if (mounted) setState(() => limiarUmidade = double.tryParse(valor) ?? 35.0);
    });
  }

  Future<void> _fetchLastValue(String user, String key, String feed, Function(String) onValue) async {
    final url = 'https://io.adafruit.com/api/v2/$user/feeds/$feed/data/last';
    try {
      final response = await http.get(Uri.parse(url), headers: {'X-AIO-Key': key});
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        onValue(data['value'].toString());
      }
    } catch (e) {
      print('Exceção ao buscar valor inicial para $feed: $e');
    }
  }

  void _configurarMqttListeners(String usuario) {
    mqttClient?.subscribe("$usuario/feeds/$feedUmidadeSolo", MqttQos.atLeastOnce);
    mqttClient?.subscribe("$usuario/feeds/$feedStatusRega", MqttQos.atLeastOnce);

    mqttClient?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      if (!mounted) return;

      setState(() {
        if (topic.endsWith(feedUmidadeSolo)) {
          umidadeSolo = double.tryParse(payload) ?? umidadeSolo;
        } else if (topic.endsWith(feedStatusRega)) {
          statusRega = payload;
        }
      });
    });
  }

  void _publicarLimiar(double valor) {
    if (mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final comandoTopic = "$usuario/feeds/$feedLimiarUmidade";
    final builder = MqttClientPayloadBuilder();
    builder.addString(valor.round().toString());
    mqttClient?.publishMessage(comandoTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildCardMedidorUmidade(),
            const SizedBox(height: 20),
            _buildCardAjusteSensibilidade(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMedidorUmidade() {
    final bool precisaRegar = statusRega.toUpperCase() == "REGAR_AGORA";
    final String statusTexto = precisaRegar ? "Regar Agora" : "Umidade OK";
    final Color corStatus = precisaRegar ? Colors.orange.shade800 : Colors.cyan.shade700;
    final IconData iconStatus = precisaRegar ? Icons.water_drop_rounded : Icons.check_circle_outline_rounded;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Umidade da Planta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 250,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    showLabels: false,
                    showTicks: false,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 0.2,
                      cornerStyle: CornerStyle.bothCurve,
                      color: Color.fromARGB(255, 222, 238, 244),
                      thicknessUnit: GaugeSizeUnit.factor,
                    ),
                    pointers: <GaugePointer>[
                      RangePointer(
                        value: umidadeSolo,
                        cornerStyle: CornerStyle.bothCurve,
                        width: 0.2,
                        sizeUnit: GaugeSizeUnit.factor,
                        color: Colors.lightBlue.shade300,
                        enableAnimation: true,
                      )
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        positionFactor: 0.1,
                        angle: 90,
                        widget: Text(
                          '${umidadeSolo.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: corStatus.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: corStatus.withOpacity(0.5))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconStatus, color: corStatus, size: 24),
                  const SizedBox(width: 10),
                  Text(statusTexto, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: corStatus)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardAjusteSensibilidade() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Ajustar Sensibilidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Regar quando a umidade for menor que: ${limiarUmidade.round()}%',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            Slider(
              value: limiarUmidade,
              min: 10,
              max: 70,
              divisions: 60,
              label: limiarUmidade.round().toString(),
              onChanged: (double value) {
                setState(() => limiarUmidade = value);
              },
              onChangeEnd: (double value) {
                _publicarLimiar(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
