// tela do modulo de fogo

import 'package:flutter/material.dart';

class Tela1 extends StatelessWidget {
  const Tela1({super.key});

  @override
  Widget build(BuildContext context) {
    // Substitua este widget pelo conteúdo real da sua tela.
    return Container(
       padding: const EdgeInsets.all(16.0),
       child: const Center(
         child: Text(
          'Conteúdo do modulo de cozinha',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
         ),
       ),
    );
  }
}