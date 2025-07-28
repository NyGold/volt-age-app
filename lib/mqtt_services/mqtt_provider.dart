// ARQUIVO: lib/mqtt_services/mqtt_provider.dart (COM A SUGESTÃO APLICADA)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';

class MqttProvider extends ChangeNotifier {
  MqttClient? _mqttClient;
  StreamSubscription? _mqttSubscription;

  // Estados
  String gasAlerta = "Carregando...";
  String valvulaEstado = "Carregando...";
  String luzStatus = "Carregando...";
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
    await Future.wait([
      _fetchFeedValue("gas-alerta", (value) {
        if (gasAlerta != value) {
          gasAlerta = value;
          notifyListeners();
        }
      }),
      _fetchFeedValue("valvula-gas-estado", (value) {
        if (valvulaEstado != value) {
          valvulaEstado = value;
          notifyListeners();
        }
      }),
      _fetchFeedValue("iluminacao-status", (value) {
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
    print("✅ [PROVIDER-FETCH] Processamento de valores iniciais concluído!");
  }
  
  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty) return;

    try {
      final recMess = c[0].payload as MqttPublishMessage;
      final topic = c[0].topic;
      final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('📬 [PROVIDER-MQTT] Mensagem recebida:');
      print('Tópico: $topic');
      print('Mensagem: $message');

      bool stateChanged = false;
      final feedName = topic.split('/feeds/').last;
      print('🔍 [PROVIDER-MQTT] Feed identificado: $feedName');

      switch (feedName) {
        case 'gas-alerta':
          if (gasAlerta != message) {
            print('🔄 [PROVIDER-STATE] Atualizando gas-alerta: $gasAlerta -> $message');
            gasAlerta = message;
            stateChanged = true;
          }
          break;

        case 'valvula-gas-estado':
          if (valvulaEstado != message) {
            print('🔄 [PROVIDER-STATE] Atualizando valvula-estado: $valvulaEstado -> $message');
            valvulaEstado = message;
            stateChanged = true;
          }
          break;

        case 'iluminacao-status':
          if (luzStatus != message) {
            print('🔄 [PROVIDER-STATE] Atualizando luz-status: $luzStatus -> $message');
            luzStatus = message;
            stateChanged = true;
          }
          break;

        case 'jardim-umidade-solo':
          final newValue = double.tryParse(message) ?? 0.0;
          if (umidadeSolo != newValue) {
            print('🔄 [PROVIDER-STATE] Atualizando umidade-solo: $umidadeSolo -> $newValue');
            umidadeSolo = newValue;
            stateChanged = true;
          }
          break;

        case 'jardim-status-rega':
          if (statusRega != message) {
            print('🔄 [PROVIDER-STATE] Atualizando status-rega: $statusRega -> $message');
            statusRega = message;
            stateChanged = true;
          }
          break;

        case 'jardim-limiar-umidade':
          final newValue = double.tryParse(message) ?? limiarUmidade;
          if (limiarUmidade != newValue) {
            print('🔄 [PROVIDER-STATE] Atualizando limiar-umidade: $limiarUmidade -> $newValue');
            limiarUmidade = newValue;
            stateChanged = true;
          }
          break;

        case 'fogo-timer-app':
          final shouldBeActive = message == "ATIVAR_TIMER";
          if (logicaEsquecimentoAtivada != shouldBeActive) {
            print('🔄 [PROVIDER-STATE] Atualizando timer: $logicaEsquecimentoAtivada -> $shouldBeActive');
            logicaEsquecimentoAtivada = shouldBeActive;
            stateChanged = true;
          }
          break;
      }

      _feedsWithRealtimeData.add(feedName);

      if (stateChanged) {
        print('🔔 [PROVIDER-STATE] Notificando listeners após mudança em: $feedName');
        notifyListeners();
      } else {
        print('ℹ️ [PROVIDER-STATE] Nenhuma mudança necessária para: $feedName');
      }
    } catch (e, stack) {
      print('❌ [PROVIDER-MQTT] Erro processando mensagem:');
      print('Erro: $e');
      print('Stack: $stack');
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
      _mqttClient?.disconnect();
      _mqttSubscription?.cancel();

      _mqttClient = await connect();
      
      if (_mqttClient == null || !isConnected) {
        print("❌ [PROVIDER-MQTT] Cliente MQTT nulo ou não conectado!");
        return;
      }

      print("✅ [PROVIDER-MQTT] Cliente MQTT conectado com sucesso!");
      
      _mqttSubscription = _mqttClient!.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage?>>? c) {
          print("📥 [PROVIDER-MQTT] Mensagem recebida no listener principal");
          _onMqttMessageReceived(c);
        },
        onError: (error) {
          print("❌ [PROVIDER-MQTT] Erro no listener: $error");
          _reconnect();
        },
        cancelOnError: false,
      );

      _subscribeToTopics();

    } catch (e, stack) {
      print('❌ [PROVIDER-MQTT] Erro na conexão: $e\n$stack');
      _reconnect();
    }
  }

  void _reconnect() {
    print("🔄 [PROVIDER-MQTT] Tentando reconectar...");
    Future.delayed(const Duration(seconds: 5), _initializeMqttConnection);
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

  // --- MUDANÇA APLICADA AQUI ---
  /// Atualiza o estado do limiar na UI para um feedback visual instantâneo.
  void atualizarLimiarVisualmente(double novoValor) {
    if (limiarUmidade != novoValor) {
      limiarUmidade = novoValor;
      notifyListeners(); // Notifica a UI para redesenhar o slider e o texto
    }
  }

  /// Publica o valor final do limiar de umidade no broker MQTT.
  void publicarLimiar(double valor) {
    if (!isConnected) { print("⚠️ Ação ignorada: offline."); return; }
    _publishMessage("jardim-limiar-umidade", valor.round().toString());
  }
  // --- FIM DA MUDANÇA ---

  void publicarComandoIluminacao(String comando) {
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
    _mqttSubscription?.cancel();
    _mqttClient?.disconnect();
    super.dispose();
  }
}