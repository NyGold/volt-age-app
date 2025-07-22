// ARQUIVO: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart'; // Importe o Provider
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart'; // Importe o nosso Provider
import 'package:volt_age_app/services/notific_serv.dart';
import 'package:volt_age_app/home_page.dart'; // Importe a HomePage
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Função de callback para quando uma notificação é selecionada em background
Future<void> notificationTapBackground(NotificationResponse notificationResponse) async {
  // Implemente aqui o que deve acontecer quando a notificação for tocada
  final payload = notificationResponse.payload;
  debugPrint('Notificação tocada em background. Payload: $payload');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Carregue o .env aqui
  await NotificationService.initialize(onSelectNotification: notificationTapBackground);

  runApp(
    // Envolvemos o App com o ChangeNotifierProvider
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
      title: 'Volt-Age App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // A home agora será a HomePage, que gerencia a navegação
      home: const HomePage(),
    );
  }
}