// ARQUIVO: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';
import 'package:volt_age_app/services/notific_serv.dart';
import 'package:volt_age_app/home_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:ui' as ui;

// Precisamos de uma GlobalKey para acessar o contexto em qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Variável para armazenar comandos pendentes
SharedPreferences? _prefs;
bool _isAppInitialized = false;
final List<String> _pendingCommands = [];

// Função de callback para quando uma notificação é selecionada em background
void notificationTapBackground(NotificationResponse notificationResponse) async {
  try {
    final payload = notificationResponse.payload;
    debugPrint('Notificação tocada em background. Payload: $payload');
    
    if (notificationResponse.actionId == 'FECHAR_GAS_ACTION') {
      debugPrint('Botão "FECHAR GÁS" pressionado em background');
      
      // Armazene o comando para ser processado quando o app for aberto
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fechar_gas', true);
      
      // Inicie o app se estiver em background
      WidgetsFlutterBinding.ensureInitialized();
    }
  } catch (e) {
    // Não faça nada - não podemos registrar erros aqui durante a inicialização
  }
}

void main() {
  // Primeiro, configure o tratamento básico de erros
  _setupBasicErrorHandling();
  
  // Execute a inicialização real em um Future para evitar problemas de sync
  Future.microtask(() => _initializeApp());
}

void _setupBasicErrorHandling() {
  // Tratamento MÍNIMO de erros para evitar loops infinitos
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      // Tente registrar o erro de forma MUITO SIMPLES
      // NÃO use debugPrint ou qualquer coisa complexa aqui
      // Isso evita loops de erros
      // print("ERRO CRÍTICO: ${details.exception}");
    } catch (e) {
      // Não faça nada - não podemos registrar erros aqui
    }
  };
  
  // Tratamento MÍNIMO de exceções não capturadas
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      // print("EXCEÇÃO NÃO TRATADA: $error");
    } catch (e) {
      // Não faça nada
    }
    return true;
  };
}

Future<void> _initializeApp() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Tente obter SharedPreferences de forma super segura
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Não registre o erro - poderia causar loop
      _prefs = null;
    }
    
    // Tente carregar o .env
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // Não registre o erro
    }
    
    // Verifique comandos pendentes se _prefs está disponível
    if (_prefs != null) {
      try {
        final fecharGas = _prefs!.getBool('fechar_gas') ?? false;
        if (fecharGas) {
          await _prefs!.setBool('fechar_gas', false);
          _pendingCommands.add('FECHAR_GAS');
        }
      } catch (e) {
        // Não registre o erro
      }
    }
    
    // Inicialize o NotificationService com tratamento de erros extra
    try {
      await NotificationService.initialize(
        onSelectNotification: (notificationResponse) async {
          try {
            if (notificationResponse.actionId == 'FECHAR_GAS_ACTION') {
              if (_isAppInitialized) {
                _processCloseGasCommand();
              } else {
                _pendingCommands.add('FECHAR_GAS');
              }
            }
          } catch (e) {
            // Não registre o erro
          }
        },
      );
    } catch (e) {
      // Não registre o erro
    }
    
    // Execute o runApp com tratamento de erros mínimo
    try {
      runApp(
        ChangeNotifierProvider(
          create: (context) => MqttProvider(),
          child: const MyApp(),
        ),
      );
      
      _isAppInitialized = true;
      _processPendingCommands();
    } catch (e) {
      // Se tudo mais falhar, mostre uma tela de erro simples
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                "Erro crítico de inicialização",
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
  } catch (e) {
    // Se tudo mais falhar, mostre uma tela de erro simples
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              "Erro crítico de inicialização",
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

void _processCloseGasCommand() {
  try {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
        mqttProvider.publicarComandoValvula('FECHAR_AGORA');
        
        // Mostrar feedback visual
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Válvula de gás fechada com segurança!'),
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          // Não registre o erro
        }
      } catch (e) {
        // Provider não disponível
        _pendingCommands.add('FECHAR_GAS');
      }
    } else {
      _pendingCommands.add('FECHAR_GAS');
    }
  } catch (e) {
    // Não registre o erro
  }
}

void _processPendingCommands() {
  Future.delayed(const Duration(milliseconds: 300), () {
    try {
      for (var command in List<String>.from(_pendingCommands)) {
        if (command == 'FECHAR_GAS') {
          _processCloseGasCommand();
        }
      }
      _pendingCommands.clear();
    } catch (e) {
      // Não registre o erro
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Processar comandos pendentes quando o app é construído
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingCommands();
    });
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Volt Age',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}