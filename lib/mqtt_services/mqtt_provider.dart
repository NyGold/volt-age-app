// ARQUIVO: lib/mqtt_provider.dart (VERSÃO FINAL)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';

class MqttProvider extends ChangeNotifier {
  MqttClient? _mqttClient;

  // Estados
  String gasAlerta = "Carregando...";
  String valvulaEstado = "Carregando...";
  bool logicaEsquecimentoAtivada = false;
  double umidadeSolo = 0.0;
  String statusRega = "Carregando...";
  double limiarUmidade = 35.0;
  String iluminacaoStatus = "Carregando...";

  // Trava de segurança para evitar dados antigos (HTTP) sobrescreverem dados novos (MQTT)
  final Set<String> _feedsWithRealtimeData = {};
  bool get isConnected => _mqttClient?.connectionStatus?.state == MqttConnectionState.connected;

  MqttProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeMqttConnection();
    await _fetchInitialValues();
  }

  Future<void> _fetchInitialValues() async {
    await Future.wait([
      _fetchFeedValue("gas-alerta", (value) => gasAlerta = value),
      _fetchFeedValue("valvula-gas-estado", (value) => valvulaEstado = value),
      _fetchFeedValue("jardim-umidade-solo", (value) => umidadeSolo = double.tryParse(value) ?? 0.0),
      _fetchFeedValue("jardim-status-rega", (value) => statusRega = value),
      _fetchFeedValue("jardim-limiar-umidade", (value) => limiarUmidade = double.tryParse(value) ?? limiarUmidade),
      _fetchFeedValue("iluminacao-status", (value) => iluminacaoStatus = value),
    ]);
    notifyListeners();
  }

  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = c[0].topic;
    final feedName = topic.split('/').last;
    _feedsWithRealtimeData.add(feedName);

    bool stateChanged = false;

    if (topic.endsWith('/feeds/gas-alerta') && gasAlerta != message) {
      gasAlerta = message; stateChanged = true;
    } else if (topic.endsWith('/feeds/valvula-gas-estado') && valvulaEstado != message) {
      valvulaEstado = message; stateChanged = true;
    } else if (topic.endsWith('/feeds/fogo-timer-app') && logicaEsquecimentoAtivada != (message == "ATIVAR_TIMER")) {
      logicaEsquecimentoAtivada = (message == "ATIVAR_TIMER"); stateChanged = true;
    } else if (topic.endsWith('/feeds/jardim-umidade-solo')) {
      final newValue = double.tryParse(message) ?? 0.0;
      if (umidadeSolo != newValue) { umidadeSolo = newValue; stateChanged = true; }
    } else if (topic.endsWith('/feeds/jardim-status-rega') && statusRega != message) {
      statusRega = message; stateChanged = true;
    } else if (topic.endsWith('/feeds/jardim-limiar-umidade')) {
      final newValue = double.tryParse(message) ?? limiarUmidade;
      if (limiarUmidade != newValue) { limiarUmidade = newValue; stateChanged = true; }
    } else if (topic.endsWith('/feeds/iluminacao-status') && iluminacaoStatus != message) {
      iluminacaoStatus = message; stateChanged = true;
    }
    
    if (stateChanged) notifyListeners();
  }

  Future<void> _fetchFeedValue(String feed, Function(String) onValue) async {
    if (_feedsWithRealtimeData.contains(feed)) return;

    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';

    try {
      final response = await http.get(Uri.parse(url), headers: {'X-AIO-Key': key ?? ''});
      if (_feedsWithRealtimeData.contains(feed)) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final valor = data['value']?.toString() ?? '';
        onValue(valor);
      }
    } catch (e) {
      print("❌ [PROVIDER-FETCH] Erro na requisição HTTP para o feed $feed: $e");
    }
  }

  Future<void> _initializeMqttConnection() async {
    try {
      _mqttClient = await connect();
      _mqttClient?.onDisconnected = _onDisconnected;
      _mqttClient?.onConnected = _onConnected;
      if (!isConnected) return;

      _subscribeToTopics();
      _mqttClient?.updates?.listen(_onMqttMessageReceived);
    } catch (e) {
      print('❌ [PROVIDER-MQTT] ERRO CRÍTICO na conexão: $e');
    }
  }

  void _subscribeToTopics() {
    if (!isConnected) return;
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    final topics = [
      "gas-alerta", "valvula-gas-estado", "jardim-umidade-solo",
      "jardim-status-rega", "jardim-limiar-umidade", "iluminacao-status",
      "fogo-timer-app", "iluminacao-comando"
    ];

    for (var feed in topics) {
      _mqttClient?.subscribe("$usuario/feeds/$feed", MqttQos.atLeastOnce);
    }
  }

  void _onConnected() {
    _subscribeToTopics();
    notifyListeners();
  }

  void _onDisconnected() {
    Future.delayed(const Duration(seconds: 5), _initializeMqttConnection);
    notifyListeners();
  }

  void publicarComandoValvula(String comando) {
    if (!isConnected) return;
    _publishMessage("valvula-gas-controle", comando);
  }

  void setLogicaEsquecimento(bool ativada) {
    if (!isConnected) return;
    logicaEsquecimentoAtivada = ativada;
    final comando = ativada ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
    _publishMessage("fogo-timer-app", comando);
    notifyListeners();
  }

  void resetarAlertaDeFogo() {
    if (!isConnected) return;
    _publishMessage("fogo-timer-reset", "RESET_TIMER");
  }

  void publicarLimiar(double valor) {
    if (!isConnected) return;
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }

  void publicarComandoIluminacao(String comando) {
    if (!isConnected) return;
    _publishMessage("iluminacao-comando", comando);
  }

  void _publishMessage(String feed, String message) {
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    final topic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _mqttClient?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  void dispose() {
    _mqttClient?.disconnect();
    super.dispose();
  }
}