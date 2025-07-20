import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:volt_age_app/services/notific_serv.dart';

import 'dart:async';

import 'package:volt_age_app/telas/tela_1.dart';
import 'package:volt_age_app/telas/tela_2.dart';
import 'package:volt_age_app/telas/tela_3.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _paginaAtual = 0;
  final PageController _pageController = PageController();
  MqttClient? mqttClient;

  // Streams para receber atualizações
  final StreamController<String> _gasAlertaController = StreamController<String>.broadcast();
  final StreamController<String> _valvulaEstadoController = StreamController<String>.broadcast();

  // boa prática de fechar os steams
  @override
  void dispose() {
    _gasAlertaController.close();
    _valvulaEstadoController.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _inicializarConexaoMqttGlobal();
  }

  Future<void> _inicializarConexaoMqttGlobal() async {
    try {
      final client = await connect();
      if (mounted) {
        setState(() {
          mqttClient = client;
        });
        _configurarListenerDeNotificacoes();
      }
    } catch (e) {
      print('Erro na conexão MQTT Global: $e');
    }

    mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print('MQTT_LOGS:: Mensagem recebida: Tópico: <$topic>, Payload: <-- $pt -->');
      print('');

      // Direciona a mensagem para o "cano" (Stream) correto
      if (topic.endsWith('/feeds/gas-alerta')) {
        _gasAlertaController.add(pt); // Adiciona a mensagem ao stream do gasAlerta
      }
      if (topic.endsWith('/feeds/valvula-gas-estado')) {
        _valvulaEstadoController.add(pt); // Adiciona a mensagem ao stream do valvulaEstado
      }
      // Adicione outros `if` para outros feeds que você queira ouvir.
    });

  }

  void _configurarListenerDeNotificacoes() {
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    if (usuario == null) return;

    final feedGasAlerta = "$usuario/feeds/gas-alerta";
    final feedStatusRega = "$usuario/feeds/jardim-status-rega";

    mqttClient?.subscribe(feedGasAlerta, MqttQos.atLeastOnce);
    mqttClient?.subscribe(feedStatusRega, MqttQos.atLeastOnce);

    mqttClient?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print("Mensagem global recebida no tópico $topic: $payload");

      if (topic == feedGasAlerta) {
        if (payload == "ALARME_GAS") {
          NotificationService.showNotification(
            title: '🚨 ALERTA DE GÁS! 🚨',
            body: 'Vazamento de gás detectado. Aja agora!',
            isEmergency: true, // <-- INFORMA QUE PRECISA DO BOTÃO
            payload: 'gas_alert',
          );
        } else if (payload == "FOGO_SEM_PRESENCA") {
          NotificationService.showNotification(
            title: '🔥 ALERTA DE FOGO! 🔥',
            body: 'O fogão pode ter sido esquecido aceso. Aja agora!',
            isEmergency: true, // <-- INFORMA QUE PRECISA DO BOTÃO
            payload: 'fire_alert',
          );
        }
      } else if (topic == feedStatusRega) {
        if (payload == "REGAR_AGORA") {
          NotificationService.showNotification(
            title: '💧 Hora de Regar a Planta 💧',
            body: 'A umidade do solo está baixa. Sua planta precisa de água.',
            isEmergency: false, // Notificação normal
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Volt-Age',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _paginaAtual = index;
          });
        },
        children: [
          Tela1(
              mqttClient: mqttClient,
              gasAlertaStream: _gasAlertaController.stream,
              valvulaEstadoStream: _valvulaEstadoController.stream
            ),
          Tela2(mqttClient: mqttClient),
          Tela3(mqttClient: mqttClient),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_rounded),
            label: 'Cozinha',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist_rounded),
            label: 'Jardim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_rounded),
            label: 'Iluminação',
          ),
        ],
      ),
    );
  }
}
