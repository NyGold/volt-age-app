// ARQUIVO: lib/mqtt_services/mqtt_provider.dart (VERSÃO COMPLETAMENTE ATUALIZADA)
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
  
  // *** CORREÇÃO 1: Trava de segurança para evitar que dados antigos (HTTP)
  // *** sobrescrevam dados novos (MQTT).
  final Set<String> _feedsWithRealtimeData = {};
  
  // Novas propriedades para o modo de cozimento interno
  int _tempoModoCozimento = 15; // Padrão 15 minutos
  DateTime? _tempoInicioModo;
  Timer? _modoCozimentoTimer;
  
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
    } else if (topic.endsWith('/feeds/iluminacao-status')) {
      print('💡 [DEBUG] Chamando atualizarIluminacaoStatus com valor: $message');
      atualizarIluminacaoStatus(message);
    }
    
    if (topic.endsWith('/feeds/iluminacao-status')) {
      print('💡 [DEBUG] Mensagem de status da iluminação processada. Estado atual: $iluminacaoStatus');
    }
    
    if (stateChanged) {
      print("🔔 [PROVIDER-STATE] Estado alterado! Notificando listeners...");
      notifyListeners();
    } else if (!topic.endsWith('/feeds/iluminacao-status')) {
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
  
  // --- Métodos específicos para o modo de cozimento interno ---
  int get tempoModoCozimento => _tempoModoCozimento;
  
  int get tempoRestanteModo {
    if (!logicaEsquecimentoAtivada || _tempoInicioModo == null) return 0;
    
    // Calcula o tempo restante com base no tempo de início
    final tempoDecorrido = DateTime.now().difference(_tempoInicioModo!).inMinutes;
    return (_tempoModoCozimento - tempoDecorrido).clamp(0, _tempoModoCozimento);
  }
  
  void setTempoModoCozimento(int minutos) {
    _tempoModoCozimento = minutos;
    notifyListeners();
  }
  
  void ativarModoCozimento() {
    logicaEsquecimentoAtivada = true;
    _tempoInicioModo = DateTime.now();
    
    // Publica o comando para o ESP32 (se estiver conectado)
    if (isConnected) {
      _publishMessage("fogo-timer-app", "ATIVAR_TIMER");
    }
    
    // Configura o temporizador para atualizar a UI
    _modoCozimentoTimer?.cancel();
    _modoCozimentoTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      notifyListeners();
      
      // Verifica se o tempo expirou
      if (tempoRestanteModo <= 0) {
        desativarModoCozimento();
        timer.cancel();
      }
    });
    
    notifyListeners();
  }
  
  void desativarModoCozimento() {
    logicaEsquecimentoAtivada = false;
    _modoCozimentoTimer?.cancel();
    
    // Publica o comando para o ESP32 (se estiver conectado)
    if (isConnected) {
      _publishMessage("fogo-timer-app", "DESATIVAR_TIMER");
    }
    
    notifyListeners();
  }
  
  void resetarAlertaDeFogo() {
    if (!isConnected) {
      // Se não estiver conectado, apenas reinicia o temporizador local
      _tempoInicioModo = DateTime.now();
      notifyListeners();
      return;
    }
    
    _publishMessage("fogo-timer-reset", "RESET_TIMER");
    // Mesmo se estiver conectado, reinicia o temporizador local
    _tempoInicioModo = DateTime.now();
    notifyListeners();
  }
  
  // --- Nenhuma alteração necessária abaixo desta linha ---
  Future<void> _initializeMqttConnection() async {
    print("🔄 [PROVIDER-MQTT] Tentando conectar ao broker MQTT...");
    try {
      _mqttClient = await connect();
      _mqttClient?.onDisconnected = _onDisconnected;
      _mqttClient?.onConnected = _onConnected;
      if (!isConnected) {
        print("❌ [PROVIDER-MQTT] Falha ao conectar após a chamada inicial.");
        return;
      }
      _subscribeToTopics();
      _mqttClient?.updates?.listen(_onMqttMessageReceived);
    } catch (e) {
      print('❌ [PROVIDER-MQTT] ERRO CRÍTICO na conexão: $e');
    }
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
  
  void _onConnected() {
    print("✅ [PROVIDER-MQTT] Conectado ao broker!");
    _subscribeToTopics();
  }
  
  void _onDisconnected() {
    print("❌ [PROVIDER-MQTT] Desconectado do broker! Tentando reconectar em 5 segundos...");
    Future.delayed(const Duration(seconds: 5), _initializeMqttConnection);
    notifyListeners();
  }
  
  void publicarComandoValvula(String comando) {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("valvula-gas-controle", comando);
  }
  
  void setLogicaEsquecimento(bool ativada) {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    if (ativada) {
      ativarModoCozimento();
    } else {
      desativarModoCozimento();
    }
  }
  
  void publicarLimiar(double valor) {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }
  
  // CORREÇÃO PRINCIPAL: Mudança de "iluminacao-controle" para "iluminacao-comando"
  void publicarComandoIluminacao(String comando) {
    if (!isConnected) { 
      print("⚠️ Ação ignorada: offline."); 
      return; 
    }
    _publishMessage("iluminacao-comando", comando);
  }
  
  void atualizarIluminacaoStatus(String status) {
    print('💡 [DEBUG] Entrou em atualizarIluminacaoStatus. Status recebido: $status | Status atual: $iluminacaoStatus');
    if (iluminacaoStatus != status) {
      iluminacaoStatus = status;
      print('💡 [PROVIDER-STATE] Estado da iluminação atualizado: $iluminacaoStatus');
      notifyListeners();
    } else {
      print('💡 [PROVIDER-STATE] Estado da iluminação recebido, mas não mudou.');
    }
  }
  
  void _publishMessage(String feed, String message) {
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    final topic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    print('🚀 [PROVIDER-MQTT] Publicando "$message" no tópico: $topic');
    _mqttClient?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }
  
  // CORREÇÃO PRINCIPAL: Método refreshAllFeeds retorna Future<void>
  Future<void> refreshAllFeeds() async {
    await _fetchInitialValues();
  }
  
  @override
  void dispose() {
    print("❌ [PROVIDER-LIFECYCLE] MqttProvider DESCARTADO!");
    _modoCozimentoTimer?.cancel();
    _mqttClient?.disconnect();
    super.dispose();
  }
}