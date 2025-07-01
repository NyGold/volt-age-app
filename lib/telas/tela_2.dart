// tela do modulo de jardinagem

import 'package:flutter/material.dart';

class Tela2 extends StatelessWidget {
  const Tela2({super.key});

  @override
  Widget build(BuildContext context) {
    // Substitua este widget pelo conteúdo real da sua tela.
    return Container(
       padding: const EdgeInsets.all(16.0),
       child: const Center(
         child: Text(
          'Conteúdo do modulo de jardinagem',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
         ),
       ),
    );
  }
}