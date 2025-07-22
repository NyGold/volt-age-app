import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:http/http.dart' as http;

class Tela2 extends StatefulWidget {
  final MqttClient? mqttClient;

  final Stream<String>? umidadeSoloStream;
  final Stream<String>? statusRegaStream;
  final Stream<String>? limiarUmidadeStream;

  const Tela2({
    super.key,
    this.mqttClient,
    this.umidadeSoloStream,
    this.statusRegaStream,
    this.limiarUmidadeStream,
  });

  @override
  State<Tela2> createState() => _Tela2State();
}

class _Tela2State extends State<Tela2> {
  double umidadeSolo = 0.0;
  double limiarUmidade = 35.0; // Valor inicial padrão
  String statusRega = "Carregando...";

  // stream para receber atualizações
  StreamSubscription? _umidadeSoloSubscription;
  StreamSubscription? _statusRegaSubscription;
  StreamSubscription? _limiarUmidadeSubscription;

  // Feeds da Jardinagem
  final feedUmidadeSolo = "jardim-umidade-solo";
  final feedStatusRega = "jardim-status-rega";
  final feedLimiarUmidade = "jardim-limiar-umidade";

  @override
  void initState() {
    super.initState();

    buscarValorFeed(feedUmidadeSolo, (valor) {
      setState(() {
        umidadeSolo = double.tryParse(valor) ?? 0.0;
      });
      print('[DEBUG] Valor inicial umidadeSolo: $valor | Estado: $umidadeSolo');
    });

    buscarValorFeed(feedStatusRega, (valor) {
      setState(() {
        statusRega = valor;
      });
      print('[DEBUG] Valor inicial statusRega: $valor | Estado: $statusRega');
    });

    buscarValorFeed(feedLimiarUmidade, (valor) {
      setState(() {
        limiarUmidade = double.tryParse(valor) ?? limiarUmidade;
      });
      print('[DEBUG] Valor inicial limiarUmidade: $valor | Estado: $limiarUmidade');
    });

    _umidadeSoloSubscription = widget.umidadeSoloStream?.listen((novaMensagem) {
      print('[DEBUG][TELA2] Stream umidadeSolo recebeu: $novaMensagem');
      if (mounted) {
        setState(() {
          umidadeSolo = double.tryParse(novaMensagem) ?? 0.0;
        });
        print('[DEBUG][TELA2] Estado umidadeSolo atualizado: $umidadeSolo');
      }
    });

    _statusRegaSubscription = widget.statusRegaStream?.listen((novoStatus) {
      print('[DEBUG][TELA2] Stream statusRega recebeu: $novoStatus');
      if (mounted) {
        setState(() {
          statusRega = novoStatus;
        });
        print('[DEBUG][TELA2] Estado statusRega atualizado: $statusRega');
      }
    });

    _limiarUmidadeSubscription = widget.limiarUmidadeStream?.listen((novoLimiar) {
      print('[DEBUG][TELA2] Stream limiarUmidade recebeu: $novoLimiar');
      if (mounted) {
        setState(() {
          limiarUmidade = double.tryParse(novoLimiar) ?? limiarUmidade;
        });
        print('[DEBUG][TELA2] Estado limiarUmidade atualizado: $limiarUmidade');
      }
    });
  }

  void _publicarLimiar(double valor) {
    if (widget.mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final comandoTopic = "$usuario/feeds/$feedLimiarUmidade";
    final builder = MqttClientPayloadBuilder();
    builder.addString(valor.round().toString());
    print('Publicando novo limiar de umidade: $valor% no tópico: $comandoTopic');
    widget.mqttClient?.publishMessage(comandoTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> buscarValorFeed(String feed, Function(String) onValor) async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';
    print('[DEBUG] Buscando valor inicial do feed: $feed');
    print('[DEBUG] URL: $url');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-AIO-Key': key ?? ''},
      );
      print('[DEBUG] Status code: ${response.statusCode}');
      print('[DEBUG] Body recebido: ${response.body}');
      if (response.statusCode == 200) {
        final data = response.body;
        final match = RegExp('"value":"(.*?)"').firstMatch(data);
        final valor = match?.group(1) ?? data;
        print('[DEBUG] Valor extraído: $valor');
        onValor(valor);
      } else {
        print('[DEBUG] Falha ao buscar feed $feed: status ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] Erro ao buscar valor inicial do feed $feed: $e');
    }
  }

  @override
  void dispose() {
    _umidadeSoloSubscription?.cancel();
    _statusRegaSubscription?.cancel();
    _limiarUmidadeSubscription?.cancel();
    super.dispose();
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
