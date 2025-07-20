import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Tela1 extends StatefulWidget {
  const Tela1({super.key});

  @override
  State<Tela1> createState() => _Tela1State();
}

class _Tela1State extends State<Tela1> {
  MqttClient? mqttClient;
  String gasAlerta = "Carregando...";
  String valvulaEstado = "Carregando...";
  bool logicaEsquecimentoAtivada = false;

  // Feeds da Cozinha
  final feedGasAlerta = "gas-alerta";
  final feedValvulaEstado = "valvula-gas-estado";
  final feedValvulaControle = "valvula-gas-controle";
  final feedFogoTimerApp = "fogo-timer-app";
  final feedFogoTimerReset = "fogo-timer-reset";

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
      if (mounted) {
        setState(() {
          gasAlerta = "Erro no .env";
          valvulaEstado = "Erro no .env";
        });
      }
      return;
    }

    // 1. Busca os valores iniciais via API REST para exibição imediata
    await _buscarValoresIniciais(usuario, key);

    // 2. Conecta ao Broker MQTT para receber atualizações em tempo real
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
      if (mounted) {
        setState(() {
          if (gasAlerta == "Carregando...") gasAlerta = "Erro de Conexão";
          if (valvulaEstado == "Carregando...") valvulaEstado = "Erro de Conexão";
        });
      }
    }
  }

  /// Busca o último valor de cada feed usando a API REST da Adafruit.
  Future<void> _buscarValoresIniciais(String usuario, String key) async {
    // Busca o último status de alerta de gás
    await _fetchLastValue(usuario, key, feedGasAlerta, (valor) {
      if (mounted) setState(() => gasAlerta = valor);
    });

    // Busca o último estado da válvula
    await _fetchLastValue(usuario, key, feedValvulaEstado, (valor) {
      if (mounted) setState(() => valvulaEstado = valor);
    });
  }

  /// Função auxiliar para fazer a chamada HTTP para um feed específico.
  Future<void> _fetchLastValue(String user, String key, String feed, Function(String) onValue) async {
    final url = 'https://io.adafruit.com/api/v2/$user/feeds/$feed/data/last';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'X-AIO-Key': key},
      );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final valor = data['value'].toString();
        print('Valor inicial para $feed: $valor');
        onValue(valor);
      } else {
        print('Não foi possível buscar valor inicial para $feed. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Exceção ao buscar valor inicial para $feed: $e');
    }
  }


  void _configurarMqttListeners(String usuario) {
    // Assinatura dos feeds de status para atualizações em tempo real
    mqttClient?.subscribe("$usuario/feeds/$feedGasAlerta", MqttQos.atLeastOnce);
    mqttClient?.subscribe("$usuario/feeds/$feedValvulaEstado", MqttQos.atLeastOnce);

    mqttClient?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      if (!mounted) return;

      setState(() {
        if (topic.endsWith(feedGasAlerta)) {
          gasAlerta = payload;
          if (payload == "FOGO_TIMER_ATIVO") {
            logicaEsquecimentoAtivada = true;
          }
        } else if (topic.endsWith(feedValvulaEstado)) {
          valvulaEstado = payload;
        }
      });
    });
  }

  void _publicarComando(String feed, String comando) {
    if (mqttClient == null || mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aguardando conexão... Tente novamente em alguns segundos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final comandoTopic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(comando);

    print('Publicando no tópico $comandoTopic: $comando');
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
            _buildCardStatusPrincipal(),
            const SizedBox(height: 20),
            _buildCardControleValvula(),
            const SizedBox(height: 20),
            _buildCardLogicaEsquecimento(),
          ],
        ),
      ),
    );
  }

  // A ÚNICA MUDANÇA ESTÁ NESTE WIDGET ABAIXO
  Widget _buildCardStatusPrincipal() {
    final bool isAlert = gasAlerta.contains("ALARME") || gasAlerta.contains("FOGO_SEM_PRESENCA");
    final Color statusColor = isAlert ? Colors.red.shade700 : Colors.green.shade700;
    final IconData statusIcon = isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;

    // Função para traduzir o status bruto para uma mensagem amigável
    String getMensagemStatus(String status) {
      if (status.startsWith("FOGO_CONTANDO")) {
        return "Contagem de segurança...";
      }
      switch (status) {
        case "OK":
          return "Tudo certo";
        case "ALARME_GAS":
          return "PERIGO: Gás vazando!";
        case "FOGO_SEM_PRESENCA":
          return "PERIGO: Fogão esquecido!";
        case "ALERTA_APP":
          return "Gás fechado pelo celular";
        case "FOGO_TIMER_ATIVO":
          return "Timer de segurança pausado";
        default:
          return status; // Retorna o status original se não for reconhecido
      }
    }

    return Card(
      elevation: 6,
      color: isAlert ? Colors.red.shade50 : Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(statusIcon, size: 60, color: statusColor),
            const SizedBox(height: 12),
            const Text(
              'Status Geral da Cozinha',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              getMensagemStatus(gasAlerta), // Exibe a mensagem traduzida
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControleValvula() {
    final bool isAberta = valvulaEstado.toUpperCase() == "ABERTA";

    // Define o texto, a cor e o ícone com base no estado
    final String statusTexto = isAberta ? "Gás Aberto" : "Gás Fechado";
    final Color statusCor = isAberta ? Colors.green.shade800 : Colors.red.shade800;
    final Color cardColor = isAberta ? Colors.green.shade100 : Colors.red.shade100;
    final IconData statusIcon = isAberta ? Icons.lock_open_rounded : Icons.lock_rounded;

    return Card(
      elevation: 4,
      color: cardColor, // Cor de fundo do card muda
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusCor, width: 1.5), // Borda para destaque
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Row para o status com ícone
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusCor, size: 32),
                const SizedBox(width: 12),
                Text(
                  statusTexto,
                  style: TextStyle(
                    fontSize: 26, // Fonte maior
                    fontWeight: FontWeight.bold,
                    color: statusCor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Mais espaço
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _publicarComando(feedValvulaControle, 'ABRIR_AGORA'),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('ABRIR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _publicarComando(feedValvulaControle, 'FECHAR_AGORA'),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('FECHAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLogicaEsquecimento() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Segurança Contra Esquecimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Pausar timer de segurança', style: TextStyle(fontSize: 16)),
              trailing: Switch(
                value: logicaEsquecimentoAtivada,
                onChanged: (bool value) {
                  setState(() {
                    logicaEsquecimentoAtivada = value;
                  });
                  final comando = value ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
                  _publicarComando(feedFogoTimerApp, comando);
                },
                activeTrackColor: Colors.orange.shade200,
                activeColor: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _publicarComando(feedFogoTimerReset, 'RESET_TIMER'),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Resetar Alerta de Fogo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}