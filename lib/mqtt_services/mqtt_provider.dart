// ARQUIVO: lib/mqtt_provider.dart (COM CORREÇÃO PONTUAL, MANTENDO A ESTRUTURA ORIGINAL)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart'; // Mantenha o seu import

class MqttProvider extends ChangeNotifier {
  MqttClient? _mqttClient;
  StreamSubscription? _mqttSubscription; // <--- ADICIONADO

  // Estados
  String gasAlerta = "Carregando...";
  String valvulaEstado = "Carregando...";
  String luzStatus = "Carregando..."; // <--- ADICIONADO
  bool logicaEsquecimentoAtivada = false;
  double umidadeSolo = 0.0;
  String statusRega = "Carregando...";
  double limiarUmidade = 35.0;

  final Set<String> _feedsWithRealtimeData = {};

  bool get isConnected => _mqttClient?.connectionStatus?.state == MqttConnectionState.connected;

  MqttProvider() {
    print("✅ [PROVIDER-LIFECYCLE] MqttProvider CRIADO!");
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeMqttConnection();
    await _fetchInitialValues();
  }
  
  Future<void> _fetchInitialValues() async {
    print("🔄 [PROVIDER-FETCH] Buscando valores iniciais da API...");
    // --- MUDANÇA PRINCIPAL AQUI ---
    // Em vez de atualizar as variáveis silenciosamente e notificar apenas no final,
    // agora verificamos a mudança e notificamos para cada valor individualmente.
    // Isso garante que a UI reflita o dado assim que ele chega do HTTP.
    await Future.wait([
      _fetchFeedValue("gas-alerta", (value) {
        if (gasAlerta != value) {
          gasAlerta = value;
          notifyListeners(); // Notifica imediatamente para este feed
        }
      }),
      _fetchFeedValue("valvula-gas-estado", (value) {
        if (valvulaEstado != value) {
          valvulaEstado = value;
          notifyListeners(); // Notifica imediatamente para este feed
        }
      }),
      _fetchFeedValue("iluminacao-status", (value) { // <--- ADICIONADO
        if (luzStatus != value) {
          luzStatus = value;
          notifyListeners();
        }
      }),
      _fetchFeedValue("jardim-umidade-solo", (value) {
        final newValue = double.tryParse(value) ?? 0.0;
        if (umidadeSolo != newValue) {
          umidadeSolo = newValue;
          notifyListeners();
        }
      }),
      _fetchFeedValue("jardim-status-rega", (value) {
        if (statusRega != value) {
          statusRega = value;
          notifyListeners();
        }
      }),
      _fetchFeedValue("jardim-limiar-umidade", (value) {
        final newValue = double.tryParse(value) ?? limiarUmidade;
        if (limiarUmidade != newValue) {
          limiarUmidade = newValue;
          notifyListeners();
        }
      }),
    ]);
    // A chamada `notifyListeners()` que existia aqui foi removida, pois agora
    // as notificações são feitas individualmente acima.
    print("✅ [PROVIDER-FETCH] Processamento de valores iniciais concluído!");
  }
  
  // =======================================================================
  // NENHUMA OUTRA ALTERAÇÃO NOS MÉTODOS ABAIXO
  // =======================================================================

  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty) {
      print("⚠️ [PROVIDER-MQTT] Mensagem recebida vazia!");
      return;
    }

    try {
      final recMess = c[0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print("📬 [PROVIDER-MQTT] Mensagem recebida:");
      print("  - Tópico: $topic");
      print("  - Conteúdo: $message");

      final feedName = topic.split('/').last;
      _feedsWithRealtimeData.add(feedName);

      bool stateChanged = false;
      if (topic.endsWith('/feeds/gas-alerta') && gasAlerta != message) {
        gasAlerta = message; stateChanged = true;
      } else if (topic.endsWith('/feeds/valvula-gas-estado') && valvulaEstado != message) {
        valvulaEstado = message; stateChanged = true;
      } else if (topic.endsWith('/feeds/iluminacao-status') && luzStatus != message) { // <--- ADICIONADO
        luzStatus = message; stateChanged = true;
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
      }

      if (stateChanged) {
        print("🔔 [PROVIDER-STATE] Estado alterado! Notificando listeners...");
        notifyListeners();
      } else {
        print("⚖️ [PROVIDER-STATE] Mensagem recebida, mas não alterou o estado atual.");
      }
    } catch (e, stackTrace) {
      print("❌ [PROVIDER-MQTT] Erro ao processar mensagem:");
      print("Erro: $e");
      print("Stack: $stackTrace");
    }
  }

  Future<void> _fetchFeedValue(String feed, Function(String) onValue) async {
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
      
      if (_feedsWithRealtimeData.contains(feed)) {
        print("👍 [PROVIDER-FETCH] Valor HTTP para '$feed' ignorado, pois um dado em tempo real chegou durante a busca.");
        return;
      }

      if (response.statusCode == 200) {
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

  Future<void> _initializeMqttConnection() async {
    print("🔄 [PROVIDER-MQTT] Tentando conectar ao broker MQTT...");
    try {
      // Desconecta cliente anterior se existir
      _mqttClient?.disconnect();
      _mqttSubscription?.cancel();

      _mqttClient = await connect();
      
      if (_mqttClient == null || !isConnected) {
        print("❌ [PROVIDER-MQTT] Cliente MQTT nulo ou não conectado!");
        return;
      }

      print("✅ [PROVIDER-MQTT] Cliente MQTT conectado com sucesso!");
      
      // Configura callbacks
      _mqttClient!.onDisconnected = _onDisconnected;
      _mqttClient!.onConnected = _onConnected;
      _mqttClient!.onSubscribed = (String topic) {
        print("✅ [PROVIDER-MQTT] Inscrito no tópico: $topic");
      };

      _subscribeToTopics();
      
      // Configura o listener de mensagens
      _mqttSubscription = _mqttClient!.updates!.listen(
        _onMqttMessageReceived,
        onError: (error) {
          print("❌ [PROVIDER-MQTT] Erro no listener: $error");
        },
        cancelOnError: false,
      );

      print("✅ [PROVIDER-MQTT] Listener MQTT configurado com sucesso!");
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ [PROVIDER-MQTT] ERRO CRÍTICO na conexão:');
      print('Erro: $e');
      print('Stack: $stackTrace');
    }
  }

  void _subscribeToTopics() {
    if (!isConnected) {
      print("❌ [PROVIDER-MQTT] Tentativa de subscribe com cliente desconectado!");
      return;
    }

    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"]!;
    print("🔄 [PROVIDER-MQTT] Inscrevendo-se nos tópicos...");
    
    final topics = [
      "gas-alerta", "valvula-gas-estado", "iluminacao-status",
      "jardim-umidade-solo", "jardim-status-rega", "jardim-limiar-umidade",
      "fogo-timer-app"
    ];

    for (var feed in topics) {
      final topic = "$usuario/feeds/$feed";
      try {
        _mqttClient!.subscribe(topic, MqttQos.atLeastOnce);
        print("🔔 [PROVIDER-MQTT] Subscribe realizado: $topic");
      } catch (e) {
        print("❌ [PROVIDER-MQTT] Erro ao subscrever em $topic: $e");
      }
    }
  }

  void _onConnected() {
    print("✅ [PROVIDER-MQTT] Conectado ao broker!");
    _subscribeToTopics();
    // --- GARANTA QUE O LISTENER É ÚNICO E ATIVO TAMBÉM NA RECONEXÃO ---
    _mqttSubscription?.cancel();
    _mqttSubscription = _mqttClient?.updates?.listen(_onMqttMessageReceived);
    print("✅ [PROVIDER-MQTT] Listener de updates MQTT ativado (onConnected)!");
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
    logicaEsquecimentoAtivada = ativada;
    final comando = ativada ? "ATIVAR_TIMER" : "DESATIVAR_TIMER";
    _publishMessage("fogo-timer-app", comando);
    print("🔔 [PROVIDER-STATE] Ação do usuário (Switch). Notificando listeners...");
    notifyListeners();
  }

  void resetarAlertaDeFogo() {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("fogo-timer-reset", "RESET_TIMER");
  }

  void publicarLimiar(double valor) {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }

  void publicarComandoIluminacao(String comando) { // <--- ADICIONADO
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("iluminacao-comando", comando);
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
    _mqttSubscription?.cancel(); // <--- ADICIONADO
    _mqttClient?.disconnect();
    super.dispose();
  }
}