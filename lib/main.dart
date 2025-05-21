import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      body: Column( // tipo de corpo
        children: [ // as "crianças" da coluna, elas estão associadas a coluna
          Text("Estado das plantas ! 90%"),
          Text("Elas estão tudo bem!"),
          Text(appState.current.asLowerCase),

          ElevatedButton(
            onPressed: () {print("Hello, World");},
            child: Text("next"))
        ],
      ),
    );
  }
}
