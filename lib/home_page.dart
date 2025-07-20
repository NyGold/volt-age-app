import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:volt_age_app/services/notific_serv.dart';
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
        children: const [
          Tela1(),
          Tela2(),
          Tela3(),
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
