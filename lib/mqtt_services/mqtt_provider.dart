// ARQUIVO: lib/mqtt_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:volt_age_app/services/notific_serv.dart';

class MqttProvider extends ChangeNotifier {
  MqttClient? _mqttClient;

  // Feeds da Cozinha (Tela1)
  String gasAlerta = "Carregando...";
  String valvulaEstado = "Carregando...";
  bool logicaEsquecimentoAtivada = false;

  // Feeds do Jardim (Tela2)
  double umidadeSolo = 0.0;
  String statusRega = "Carregando...";
  double limiarUmidade = 35.0; // Valor inicial padrão

  // Feeds da Iluminação (Tela3)
  // Adicione aqui os estados da Tela3 se necessário

  bool get isConnected => _mqttClient?.connectionStatus?.state == MqttConnectionState.connected;

  MqttProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Carrega os valores iniciais da API
    await _fetchInitialValues();
    // Conecta e se inscreve nos tópicos MQTT
    await _initializeMqttConnection();
  }

  Future<void> _fetchInitialValues() async {
    await _fetchFeedValue("gas-alerta", (value) {
      gasAlerta = value;
    });
    await _fetchFeedValue("valvula-gas-estado", (value) {
      valvulaEstado = value;
    });
    // Busca os valores iniciais para a Tela2
    await _fetchFeedValue("jardim-umidade-solo", (value) {
      umidadeSolo = double.tryParse(value) ?? 0.0;
    });
    await _fetchFeedValue("jardim-status-rega", (value) {
      statusRega = value;
    });
    await _fetchFeedValue("jardim-limiar-umidade", (value) {
      limiarUmidade = double.tryParse(value) ?? limiarUmidade;
    });

    // Adicione aqui a busca de valores para outras telas se necessário

    // Notifica os widgets que os valores iniciais chegaram
    notifyListeners();
  }

  Future<void> _initializeMqttConnection() async {
    try {
      _mqttClient = await connect();
      if (!isConnected) return;

      final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
      print("--- [PROVIDER] INICIANDO INSCRIÇÃO NOS TÓPICOS ---");

      // Tópicos
      final topics = [
        "gas-alerta",
        "valvula-gas-estado",
        "jardim-umidade-solo",
        "jardim-status-rega",
        "jardim-limiar-umidade",
        "iluminacao-status",
        "fogo-timer-app"
      ];

      for (var feed in topics) {
        final topic = "$usuario/feeds/$feed";
        print("Inscrevendo-se em: $topic");
        _mqttClient?.subscribe(topic, MqttQos.atLeastOnce);
      }

      print("--- [PROVIDER] INSCRIÇÕES CONCLUÍDAS ---");

      _mqttClient?.updates?.listen(_onMqttMessageReceived);
    } catch (e) {
      print('[PROVIDER] ERRO NA CONEXÃO MQTT: $e');
    }
  }

  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = c[0].topic;

    print('[PROVIDER] MQTT_RECEBIDO:: Tópico: <$topic>, Payload: <-- $message -->');

    // Mapeia o tópico para a variável de estado correta
    if (topic.endsWith('/feeds/jardim-umidade-solo')) {
      umidadeSolo = double.tryParse(message) ?? 0.0;
    } else if (topic.endsWith('/feeds/jardim-status-rega')) {
      statusRega = message;
      if (message == "REGAR_AGORA") {
        NotificationService.showNotification(
            title: '💧 Hora de Regar a Planta 💧',
            body: 'A umidade do solo está baixa. Sua planta precisa de água.');
      }
    } else if (topic.endsWith('/feeds/jardim-limiar-umidade')) {
      limiarUmidade = double.tryParse(message) ?? limiarUmidade;
    } else if (topic.endsWith('/feeds/gas-alerta')) {
      gasAlerta = message;
      // Lógica de notificação de gás
    } else if (topic.endsWith('/feeds/valvula-gas-estado')) {
      valvulaEstado = message;
    } else if (topic.endsWith('/feeds/fogo-timer-app')) {
      logicaEsquecimentoAtivada = (message == "ATIVAR_TIMER");
    }
    // Adicione outros `else if` para os demais tópicos...

    // A mágica acontece aqui! Notifica todos os `Consumer` widgets.
    notifyListeners();
  }

  void setLogicaEsquecimento(bool ativada) {
    logicaEsquecimentoAtivada = ativada;
    final comando = ativada ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
    _publishMessage("fogo-timer-app", comando);
    notifyListeners(); // Notifica a UI sobre a mudança imediata do switch
  }

  void resetarAlertaDeFogo() {
    _publishMessage("fogo-timer-reset", "RESET_TIMER");
  }

  // Ação de publicar o limiar (antes estava na Tela2)
  void publicarLimiar(double valor) {
    if (!isConnected) return;
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }

  // Ação de publicar o comando da válvula (exemplo, antes na Tela1)
  void publicarComandoValvula(String comando) {
     if (!isConnected) return;
    _publishMessage("valvula-gas-controle", comando);
  }

  // Método genérico para publicar mensagens
  void _publishMessage(String feed, String message) {
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    final topic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    print('[PROVIDER] Publicando "$message" no tópico: $topic');
    _mqttClient?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  // Método para buscar valor inicial de um feed (antes na Tela2)
  Future<void> _fetchFeedValue(String feed, Function(String) onValue) async {
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';

    try {
      final response = await http.get(Uri.parse(url), headers: {'X-AIO-Key': key ?? ''});
      if (response.statusCode == 200) {
        final data = response.body;
        final match = RegExp('"value":"(.*?)"').firstMatch(data);
        final valor = match?.group(1) ?? data;
        onValue(valor);
      }
    } catch (e) {
      print('[PROVIDER] Erro ao buscar valor inicial do feed $feed: $e');
    }
  }

  @override
  void dispose() {
    _mqttClient?.disconnect();
    super.dispose();
  }
}