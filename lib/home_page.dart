// ARQUIVO: lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:volt_age_app/telas/tela_1.dart';
import 'package:volt_age_app/telas/tela_2.dart';
import 'package:volt_age_app/telas/tela_3.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _paginaAtual = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Não precisamos mais de `initState` ou lógica de MQTT aqui!

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Volt-Age',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _paginaAtual = index;
          });
        },
        // As telas agora são `const`, pois não recebem mais parâmetros
        children: const [
          Tela1(),
          Tela2(),
          Tela3(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_rounded),
            label: 'Cozinha',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist_rounded),
            label: 'Jardim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_rounded),
            label: 'Iluminação',
          ),
        ],
      ),
    );
  }
}