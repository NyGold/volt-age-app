import 'package:flutter/material.dart';
import 'package:volt_age_app/tela_inicial.dart'; // Certifique-se de que o nome do pacote está correto em 'pubspec.yaml'
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificacaoService.inicializar();

  // Solicita permissão para notificações (Android 13+)
  final plugin = FlutterLocalNotificationsPlugin();
  // Para Android, permissões de notificação são geralmente solicitadas automaticamente.
  // Para iOS, você pode solicitar permissão assim:
  await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltApp',
      // Define o tema geral do aplicativo. Você pode personalizar as cores aqui.
      theme: ThemeData(
        // O `colorScheme` é a forma moderna de definir cores.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // Estilo global para a AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      // Esconde o banner de "Debug" no canto superior direito.
      debugShowCheckedModeBanner: false,
      // A primeira tela a ser exibida é a TelaInicial (splash screen).
      home: const TelaInicial(),
    );
  }
}

class NotificacaoService {
  static Future<void> inicializar() async {
    // Inicialização do serviço de notificações
  }
}