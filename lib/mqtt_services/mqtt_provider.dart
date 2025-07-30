// ARQUIVO: lib/mqtt_services/mqtt_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:volt_age_app/services/notific_serv.dart';

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
  
  // *** CONTROLE DE RECONEXÃO ***
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionDelay = 60; // segundos (1 minuto)
  Timer? _reconnectionTimer;
  
  // *** CORREÇÃO 1: Trava de segurança para evitar que dados antigos (HTTP)
  // *** sobrescrevam dados novos (MQTT).
  final Set<String> _feedsWithRealtimeData = {};
  
  bool get isConnected => _mqttClient?.connectionStatus?.state == MqttConnectionState.connected;
  
  MqttProvider() {
    print("✅ [PROVIDER-LIFECYCLE] MqttProvider CRIADO!");
    _initialize();
  }
  
  Future<void> _initialize() async {
    // *** CORREÇÃO 2: Invertemos a ordem. Primeiro conectamos ao MQTT
    // *** para começar a ouvir o mais rápido possível.
    await _initializeMqttConnection();
    await _fetchInitialValues();
  }
  
  Future<void> _fetchInitialValues() async {
    print("🔄 [PROVIDER-FETCH] Buscando valores iniciais da API...");
    await Future.wait([
      _fetchFeedValue("gas-alerta", (value) => gasAlerta = value),
      _fetchFeedValue("valvula-gas-estado", (value) => valvulaEstado = value),
      _fetchFeedValue("jardim-umidade-solo", (value) => umidadeSolo = double.tryParse(value) ?? 0.0),
      _fetchFeedValue("jardim-status-rega", (value) => statusRega = value),
      _fetchFeedValue("jardim-limiar-umidade", (value) => limiarUmidade = double.tryParse(value) ?? limiarUmidade),
      _fetchFeedValue("iluminacao-status", (value) => iluminacaoStatus = value),
    ]);
    print("✅ [PROVIDER-FETCH] Valores iniciais processados! Notificando a UI...");
    notifyListeners();
  }
  
  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = c[0].topic;
    
    // Print global para qualquer mensagem MQTT recebida
    print("🌐 [PROVIDER-MQTT] RECEBIDO: Tópico=<$topic> | Payload=<$message>");
    
    // *** CORREÇÃO 3: Marcamos o feed como "atualizado em tempo real".
    final feedName = topic.split('/').last;
    _feedsWithRealtimeData.add(feedName);
    print("📬 [PROVIDER-MQTT] MENSAGEM RECEBIDA no tópico <$topic> | Payload: <-- $message -->");
    
    bool stateChanged = false; // Flag para verificar se algo mudou
    
    if (topic.endsWith('/feeds/gas-alerta') && gasAlerta != message) {
      // Disparar notificação para situações críticas
      if (message == "ALARME_GAS" || message == "FOGO_SEM_PRESENCA") {
        NotificationService.showNotification(
          title: "ALERTA DE SEGURANÇA!",
          body: message == "ALARME_GAS" 
              ? "Vazamento de gás detectado!" 
              : "Fogão esquecido sem presença!",
          isEmergency: true,
        );
      }
      
      gasAlerta = message; 
      stateChanged = true;
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
    } else if (topic.endsWith('/feeds/iluminacao-status')) {
      print('💡 [DEBUG] Chamando atualizarIluminacaoStatus com valor: $message');
      atualizarIluminacaoStatus(message);
    }
    
    if (stateChanged) {
      print("🔔 [PROVIDER-STATE] Estado alterado! Notificando listeners...");
      notifyListeners();
    } else {
      print("⚖️ [PROVIDER-STATE] Mensagem recebida, mas não alterou o estado atual.");
    }
  }
  
  // *** CORREÇÃO 4: Método de busca de dados agora é mais seguro.
  Future<void> _fetchFeedValue(String feed, Function(String) onValue) async {
    // Se já recebemos um dado em tempo real para este feed, não fazemos a busca HTTP.
    if (_feedsWithRealtimeData.contains(feed)) {
      print("👍 [PROVIDER-FETCH] Busca HTTP para '$feed' ignorada, pois já temos um valor em tempo real.");
      return;
    }
    
    await dotenv.load();
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    final key = dotenv.env["ADAFRUIT_IO_KEY"];
    final url = 'https://io.adafruit.com/api/v2/$usuario/feeds/$feed/data/last';
    print("📡 [PROVIDER-FETCH] Buscando valor HTTP para o feed: $feed");
    
    try {
      final response = await http.get(Uri.parse(url), headers: {'X-AIO-Key': key ?? ''});
      
      // Checamos a trava de segurança novamente, caso um valor MQTT tenha chegado
      // enquanto a requisição HTTP estava em andamento.
      if (_feedsWithRealtimeData.contains(feed)) {
        print("👍 [PROVIDER-FETCH] Valor HTTP para '$feed' ignorado, pois um dado em tempo real chegou durante a busca.");
        return;
      }
      
      if (response.statusCode == 200) {
        // Usando jsonDecode para mais segurança ao invés de Regex.
        final data = jsonDecode(response.body);
        final valor = data['value']?.toString() ?? '';
        onValue(valor);
      } else {
        print("❌ [PROVIDER-FETCH] Falha ao buscar feed $feed: status ${response.statusCode}");
      }
    } catch (e) {
      print("❌ [PROVIDER-FETCH] Erro na requisição HTTP para o feed $feed: $e");
    }
  }
  
  // --- MODIFICAÇÕES PARA RECONEXÃO ROBUSTA ABAIXO ---
  Future<void> _initializeMqttConnection() async {
    print("🔄 [PROVIDER-MQTT] Tentando conectar ao broker MQTT...");
    try {
      // Cancelar qualquer tentativa de reconexão pendente
      _reconnectionTimer?.cancel();
      
      _mqttClient = await connect();
      _mqttClient?.onDisconnected = _onDisconnected;
      _mqttClient?.onConnected = _onConnected;
      if (!isConnected) {
        print("❌ [PROVIDER-MQTT] Falha ao conectar após a chamada inicial.");
        _scheduleReconnection();
        return;
      }
      _subscribeToTopics();
      _mqttClient?.updates?.listen(_onMqttMessageReceived);
    } catch (e) {
      print('❌ [PROVIDER-MQTT] ERRO CRÍTICO na conexão: $e');
      _scheduleReconnection();
    }
  }
  
  void _scheduleReconnection() {
    _reconnectionAttempts++;
    
    // Calcular o tempo de espera com backoff exponencial
    final delaySeconds = _calculateReconnectionDelay();
    
    print("⚠️ [PROVIDER-MQTT] Agendando reconexão #$_reconnectionAttempts para $delaySeconds segundos...");
    
    _reconnectionTimer = Timer(Duration(seconds: delaySeconds), () {
      _initializeMqttConnection();
    });
    
    notifyListeners();
  }
  
  int _calculateReconnectionDelay() {
    // Backoff exponencial: 2^n, com limite máximo
    int delay = 2 * _reconnectionAttempts;
    
    // Aplicar limite máximo
    if (delay > _maxReconnectionDelay) {
      delay = _maxReconnectionDelay;
    }
    
    return delay;
  }
  
  void _onConnected() {
    print("✅ [PROVIDER-MQTT] Conectado ao broker!");
    _reconnectionAttempts = 0; // Resetar contador de tentativas
    _reconnectionTimer?.cancel(); // Cancelar qualquer tentativa de reconexão pendente
    _subscribeToTopics();
    notifyListeners();
  }
  
  void _onDisconnected() {
    print("❌ [PROVIDER-MQTT] Desconectado do broker!");
    _scheduleReconnection();
  }
  
  void _subscribeToTopics() {
    if (!isConnected) return;
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    print("🔄 [PROVIDER-MQTT] Inscrevendo-se nos tópicos...");
    final topics = [
      "gas-alerta", "valvula-gas-estado", "jardim-umidade-solo",
      "jardim-status-rega", "jardim-limiar-umidade", "iluminacao-status", "fogo-timer-app"
    ];
    for (var feed in topics) {
      final fullTopic = "$usuario/feeds/$feed";
      _mqttClient?.subscribe(fullTopic, MqttQos.atLeastOnce);
      print("🔔 [PROVIDER-MQTT] Subscrito em: $fullTopic");
    }
    print("✅ [PROVIDER-MQTT] Inscrições concluídas.");
  }
  
  void publicarComandoValvula(String comando) {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline. Tentando reconectar..."); 
      _scheduleReconnection();
      return; 
    }
    _publishMessage("valvula-gas-controle", comando);
  }
  
  void setLogicaEsquecimento(bool ativada) {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline. Tentando reconectar..."); 
      _scheduleReconnection();
      return; 
    }
    logicaEsquecimentoAtivada = ativada;
    final comando = ativada ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
    _publishMessage("fogo-timer-app", comando);
    print("🔔 [PROVIDER-STATE] Lógica de esquecimento ${ativada ? 'ativada' : 'desativada'}");
    notifyListeners();
  }
  
  void resetarAlertaDeFogo() {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline. Tentando reconectar..."); 
      _scheduleReconnection();
      return; 
    }
    _publishMessage("fogo-timer-reset", "RESET_TIMER");
  }
  
  void publicarLimiar(double valor) {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline. Tentando reconectar..."); 
      _scheduleReconnection();
      return; 
    }
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }
  
  void publicarComandoIluminacao(String comando) {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline. Tentando reconectar..."); 
      _scheduleReconnection();
      return; 
    }
    _publishMessage("iluminacao-comando", comando);
  }
  
  void atualizarIluminacaoStatus(String status) {
    print('💡 [DEBUG] Entrou em atualizarIluminacaoStatus. Status recebido: $status | Status atual: $iluminacaoStatus');
    if (iluminacaoStatus != status) {
      iluminacaoStatus = status;
      print('✅ [PROVIDER-STATE] Estado da iluminação atualizado para: $status');
      notifyListeners();
    } else {
      print('💡 [PROVIDER-STATE] Estado da iluminação recebido, mas não mudou.');
    }
  }
  
  // Método público para atualizar todos os feeds (para o pull to refresh)
  Future<void> refreshAllFeeds() async {
    return _fetchInitialValues();
  }
  
  void _publishMessage(String feed, String message) {
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    final topic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    print('🚀 [PROVIDER-MQTT] Publicando "$message" no tópico: $topic');
    _mqttClient?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
  
  @override
  void dispose() {
    print("❌ [PROVIDER-LIFECYCLE] MqttProvider DESCARTADO!");
    _reconnectionTimer?.cancel();
    _mqttClient?.disconnect();
    super.dispose();
  }
}