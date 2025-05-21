import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() { // só vai rodar o aplicativo para testar
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: '@Volt Age',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

// seta e coloca o state do app por aquela rodada
// alguns widgets mudam suas propriedades com state
// a classe MyAppState guarda qualquer metodo

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
}

// Widget sempre tem a função build() para manter ele atualizado
// rastreia as mudanças com .watch<MyAppState>()

// tipo de corpo
// as "crianças" da coluna, elas estão associadas a coluna
// cada metodo build() retorna um widget o que é o caso para esse
// scaffold é um widget, assim como column que recebe seus "Filhos"

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    return Scaffold(
      body: Center(
        child: Column(
        
          mainAxisAlignment: MainAxisAlignment.center,
        
          children: [
            TextSuperior(),
            BigCard(pair: pair),
        
            ElevatedButton(
                onPressed: () {
                    appState.getNext();
                  },
                child: Text("Próxima"))
          ],
        ),
      ),
    );
  }
}

// depois de apertar  Ctrl + . você seleciona para extrair o widget
// coloca um nome que faz faz sentido
// ele vai criar uma nova classe aqui em baixo que faz tudo automatico
// ele tira a complexidade do código "main", e coloca em outro lugar para mais fácil manutenção

class BigCard extends StatelessWidget { 
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  // esse padding é outro widget, então ele pode ser adicionado em tudo qualquer coisa
  // ele foi adicionado com um método parecido com o anterior de "refracionar" o pair com o BigCard
  // Digitando Ctrl + . e selecionando "wrap with padding", ou algo parecido

  @override
  Widget build(BuildContext context) {

    // theme pega a cor base do site definida lá em cima (linha 20)

    final theme = Theme.of(context);

    // theme.textTheme possui diversas coisas de texto dentro dele, incluindo o exemplo aqui embaixo
    // .onPrimary coloca a cor do texto para uma cor adequada para a cor de fundo (no caso roxo com branco de texto)

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      // "color: theme.colorScheme.primary" pega a cor primaria da paleta de cores definida

      color: theme.colorScheme.primary,

      child: Padding(
        padding: const EdgeInsets.all(20),

        // ajuda o leitor de tela a falar as palavras
        // flutter tem diversas funções de acessibilidade, talvez seja legal ver depois 
        // https://docs.flutter.dev/development/accessibility-and-localization/accessibility

        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}

class TextSuperior extends StatelessWidget {
  const TextSuperior({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final style = theme.textTheme.displaySmall!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.secondary,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
                      "Duas palavras muito daoras!",
                      style: style,
                    ),
      ),
    );
  }
}