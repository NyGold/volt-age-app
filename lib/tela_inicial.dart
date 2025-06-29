// ARQUIVO: lib/tela_inicial.dart
// Versão atualizada com animação de fade-out.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:volt_age_app/home_page.dart'; // Mantenha a importação correta

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  // Variável para controlar a opacidade do conteúdo da tela.
  // Começa com 1.0 (totalmente visível).
  double _opacidade = 1.0;

  @override
  void initState() {
    super.initState();
    // Inicia o processo de transição da tela.
    _iniciarTransicao();
  }

  void _iniciarTransicao() async {
    // 1. Espera por 2 segundos com a tela totalmente visível.
    await Future.delayed(const Duration(seconds: 2));

    // 2. Altera a opacidade para 0.0 para iniciar a animação de fade-out.
    // A verificação `mounted` garante que o widget ainda está na tela.
    if (mounted) {
      setState(() {
        _opacidade = 0.0;
      });
    }

    // 3. Espera a animação de fade-out terminar (a duração é de 1 segundo,
    //    definida no AnimatedOpacity abaixo).
    await Future.delayed(const Duration(seconds: 1));

    // 4. Navega para a HomePage.
    if (mounted) {
      Navigator.of(context).pushReplacement(
        // Usamos PageRouteBuilder para uma transição suave (fade-in)
        // para a próxima tela, complementando nossa animação.
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O corpo da tela agora é envolvido pelo widget AnimatedOpacity.
      body: AnimatedOpacity(
        // A opacidade é controlada pela nossa variável de estado `_opacidade`.
        opacity: _opacidade,
        // Duração da animação de fade-out.
        duration: const Duration(seconds: 1),
        // O conteúdo da sua tela (o que vai desaparecer).
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bolt, size: 100, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Bem-vindo ao VoltApp',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 16),
                // O indicador de progresso pode ser removido se preferir,
                // já que a animação já dá um feedback de que algo está acontecendo.
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
