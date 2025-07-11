// tela do modulo de fogo

// TODO: atualziar a lógica de esquecimento

import 'package:flutter/material.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:volt_age_app/services/notific_serv.dart';

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
    inicializarEstado();
  }

  Future<void> inicializarEstado() async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final feed = "cozinha.valvula-gas-estado";

    // Busca o último valor via REST API
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-AIO-Key': key!},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final valor = data['value'];
        setState(() {
          isValvulaAberta = valor == "ABERTA";
          estadoValvulaTexto = isValvulaAberta
              ? 'Válvula de gás está ABERTA'
              : 'Válvula de gás está FECHADA';
        });
      }
    } catch (e) {
      print('Erro ao buscar valor inicial: $e');
    }

    // Depois conecta ao MQTT normalmente
    await inicializarMqtt(usuario!);
  }

  Future<void> inicializarMqtt(String usuario) async {
    await connect().then((client) {
      print('Conectado ao MQTT com sucesso');

      client.subscribe("$usuario/feeds/cozinha.valvula-gas-estado", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-app", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.fogo-timer-reset", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.gas-alerta", MqttQos.atLeastOnce);
      client.subscribe("$usuario/feeds/cozinha.valvula-gas-controle", MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) async {
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

          // lógica de enviar notificação quando receber alerta de gás

          if (topico.endsWith('gas-alerta')) {
            print('Alerta recebido: $payload');
            if (payload == "ALARME_GAS") {
              await NotificacaoService.enviarNotificacaoGasAberto();
            }
          }


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
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // muda o icone dependendo do estado da válvula
              isValvulaAberta
                  ? SvgPicture.asset(
                      'assets/icons/fogao_ligado_certo.svg',
                      width: 160,
                      height: 160,
                      colorFilter: ColorFilter.mode(
                        Colors.deepOrange,
                        BlendMode.srcIn,
                      ),
                    )
                    // todo: adicionar icone de alerta quando a válvula estiver fechada, condizente ao icone acima
                  : Icon(
                      Icons.lock,
                      color: Colors.green,
                      size: 60,
                    ),
              const SizedBox(height: 16),
              Text(
                estadoValvulaTexto,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: isValvulaAberta ? Colors.deepOrange : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isValvulaAberta ? Colors.green : Colors.deepOrange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
                final key = dotenv.env["ADAFRUIT_IO_KEY"];
                final feed = "cozinha.valvula-gas-controle";
                final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data';
                final valor = isValvulaAberta ? "FECHAR_AGORA" : "ABRIR_AGORA"; // <-- ajuste aqui!
                final body = json.encode({"value": valor});
                http.post(
                  Uri.parse(url),
                  headers: {
                    'X-AIO-Key': key!,
                    'Content-Type': 'application/json',
                  },
                  body: body,
                ).then((response) {
                  if (response.statusCode == 200) {
                    print('Comando enviado com sucesso: $valor');
                    // Não altere o estado local aqui, espere o MQTT atualizar!
                  } else {
                    print('Erro ao enviar comando: ${response.body}');
                  }
                }).catchError((error) {
                  print('Erro ao enviar comando: $error');
                });
              },
              child: Text(
                isValvulaAberta ? 'Fechar Válvula' : 'Abrir Válvula',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.deepPurple,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) {
                    bool timerAtivo = false; // estado do toggle
                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Configuração do Timer de Fogo',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      timerAtivo ? 'Timer Ativado' : 'Timer Desativado',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Switch(
                                      value: timerAtivo,
                                      activeColor: Colors.deepPurple,
                                          onChanged: (value) async {
                                            setModalState(() {
                                              timerAtivo = value;
                                            });
                                            final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
                                            final key = dotenv.env["ADAFRUIT_IO_KEY"];
                                            // Toggle publica ATIVAR_TIMER ou DESATIVAR_TIMER no fogo-timer-app
                                            final feedTimer = "cozinha.fogo-timer-app";
                                            final urlTimer = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feedTimer/data';
                                            final valor = value ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
                                            final body = json.encode({"value": valor});
                                            await http.post(
                                              Uri.parse(urlTimer),
                                              headers: {
                                                'X-AIO-Key': key!,
                                                'Content-Type': 'application/json',
                                              },
                                              body: body,
                                            );
                                          },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                  ),
                                  onPressed: () async {
                                    // Apenas envia o estado do toggle ao fechar
                                    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
                                    final key = dotenv.env["ADAFRUIT_IO_KEY"];
                                    final feed = "cozinha.fogo-timer-app";
                                    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data';
                                    final valorToggle = timerAtivo ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
                                    final bodyToggle = json.encode({"value": valorToggle});
                                    await http.post(
                                      Uri.parse(url),
                                      headers: {
                                        'X-AIO-Key': key!,
                                        'Content-Type': 'application/json',
                                      },
                                      body: bodyToggle,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Fechar', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              child: const Text(
                'Configurações de Alerta',
                style: TextStyle(fontSize: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
      ),
    );
  }
}