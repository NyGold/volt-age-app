// ARQUIVO: lib/home_page.dart

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
  final StreamController<String> _umidadeSoloController = StreamController<String>.broadcast();


  // boa prática de fechar os steams
  @override
  void dispose() {
    _gasAlertaController.close();
    _valvulaEstadoController.close();
    _umidadeSoloController.close();
    mqttClient?.disconnect();
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

        // --- Adicionar Logs de Diagnóstico ---
        final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
        if (usuario == null || usuario.isEmpty) {
          print("ERRO CRÍTICO: ADAFRUIT_IO_USERNAME não encontrado no arquivo .env!");
          return;
        }

        print("--- INICIANDO INSCRIÇÃO NOS TÓPICOS ---");
        print("Usuário detectado: $usuario");

        final feedGasAlerta = "$usuario/feeds/gas-alerta";
        final feedValvulaEstado = "$usuario/feeds/valvula-gas-estado";
        final feedUmidadeSolo = "$usuario/feeds/jardim-umidade-solo";
        final feedStatusRega = "$usuario/feeds/jardim-status-rega";

        print("Inscrevendo-se em: $feedGasAlerta");
        mqttClient?.subscribe(feedGasAlerta, MqttQos.atLeastOnce);

        print("Inscrevendo-se em: $feedValvulaEstado");
        mqttClient?.subscribe(feedValvulaEstado, MqttQos.atLeastOnce);

        print("Inscrevendo-se em: $feedUmidadeSolo");
        mqttClient?.subscribe(feedUmidadeSolo, MqttQos.atLeastOnce);

        print("Inscrevendo-se em: $feedStatusRega");
        mqttClient?.subscribe(feedStatusRega, MqttQos.atLeastOnce);

        print("--- INSCRIÇÕES CONCLUÍDAS ---");
      }
    } catch (e) {
      print('ERRO NA CONEXÃO MQTT GLOBAL: $e');
    }

    // Listener de mensagens (sem alterações aqui, mas verifique o terminal)
    mqttClient?.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      // Este print é crucial. Ele mostra TUDO que o app recebe.
      print('MQTT_RECEBIDO:: Tópico: <$topic>, Payload: <-- $pt -->');

      if (topic.endsWith('/feeds/gas-alerta')) {
        _gasAlertaController.add(pt);
      } else if (topic.endsWith('/feeds/valvula-gas-estado')) {
        _valvulaEstadoController.add(pt);
      } else if (topic.endsWith('/feeds/jardim-umidade-solo')) {
        _umidadeSoloController.add(pt);
      }

      // Lógica de notificação permanece aqui
      if (topic.endsWith('/feeds/gas-alerta')) {
         if (pt == "ALARME_GAS") {
          NotificationService.showNotification(
            title: '🚨 ALERTA DE GÁS! 🚨',
            body: 'Vazamento de gás detectado. Aja agora!',
            isEmergency: true,
            payload: 'gas_alert',
          );
        } else if (pt == "FOGO_SEM_PRESENCA") {
          NotificationService.showNotification(
            title: '🔥 ALERTA DE FOGO! 🔥',
            body: 'O fogão pode ter sido esquecido aceso. Aja agora!',
            isEmergency: true,
            payload: 'fire_alert',
          );
        }
      } else if (topic.endsWith('/feeds/jardim-status-rega')) {
         if (pt == "REGAR_AGORA") {
          NotificationService.showNotification(
            title: '💧 Hora de Regar a Planta 💧',
            body: 'A umidade do solo está baixa. Sua planta precisa de água.',
            isEmergency: false,
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
          Tela2(
            mqttClient: mqttClient,
            umidadeSoloStream: _umidadeSoloController.stream,
          ),
          Tela3(
            mqttClient: mqttClient
          ),
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