// ARQUIVO: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';
import 'package:volt_age_app/services/notific_serv.dart';
import 'package:volt_age_app/home_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Função de callback para quando uma notificação é selecionada em background
void notificationTapBackground(NotificationResponse notificationResponse) async {
  final payload = notificationResponse.payload;
  debugPrint('Notificação tocada em background. Payload: $payload');
  
  if (notificationResponse.actionId == 'FECHAR_GAS_ACTION') {
    debugPrint('Botão "FECHAR GÁS" pressionado em background');
    
    // Armazene o comando para ser processado quando o app for aberto
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fechar_gas', true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Inicializa as notificações ANTES de rodar o app
  await NotificationService.initialize(
    onSelectNotification: notificationTapBackground
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => MqttProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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