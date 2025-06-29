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
  // Controla o índice da tela atualmente selecionada.
  int _indiceAtual = 0;

  // Lista das 3 telas principais que serão exibidas.
  final List<Widget> _telas = [
    const Tela1(),
    const Tela2(),
    const Tela3(),
  ];

  // Lista dos títulos para a AppBar, correspondendo a cada tela.
  final List<String> _titulosAppBar = [
    'Cozinha',
    'Jardim',
    'Luz',
  ];

  // Função chamada quando um item da barra de navegação é tocado.
  void _aoTocarNoItem(int index) {
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          size: 512,
          color: Colors.white
        ),

        // O título da AppBar muda conforme a tela selecionada.
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child: Text(
              _titulosAppBar[_indiceAtual],
              style: TextStyle(fontFamily: "Roboto", fontWeight: FontWeight.bold, fontSize: 32),
            )),
        ),
      ),
      // O corpo da tela exibe a tela selecionada da lista _telas.
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      // Barra de navegação inferior.
      bottomNavigationBar: BottomNavigationBar(
        // O índice do item atualmente selecionado.
        currentIndex: _indiceAtual,
        // A função a ser chamada quando um item é tocado.
        onTap: _aoTocarNoItem,
        // Cor do ícone e texto do item selecionado.
        selectedItemColor: Colors.deepPurple,
        // Cor dos itens não selecionados.
        unselectedItemColor: Colors.grey[600],
        // Itens da barra de navegação.
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_outlined),
            label: 'Cozinha',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forest_outlined),
            label: 'Jardim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.light),
            label: 'Luz',
          ),
        ],
      ),
    );
  }
}