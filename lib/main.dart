import 'package:flutter/material.dart';
import 'package:volt_age_app/tela_inicial.dart'; // Certifique-se de que o nome do pacote está correto em 'pubspec.yaml'

void main() {
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