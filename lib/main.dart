import 'package:flutter/material.dart';
import 'services/mqtt_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adafruit IO MQTT Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MqttService _mqttService = MqttService();
  final TextEditingController _textController = TextEditingController();
  String _receivedMessage = 'Nenhuma mensagem recebida ainda.';

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  void _connectAndListen() async {
    await _mqttService.connect(); 
    _mqttService.messages.listen((message) {
      setState(() {
        _receivedMessage = message;
      });
    });
  }

  void _publishMessage() {
    if (_textController.text.isNotEmpty) {
      _mqttService.publish(_textController.text);
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adafruit IO MQTT Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Mensagem Recebida do Feed:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _receivedMessage,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Mensagem para publicar',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _publishMessage,
              child: const Text('Publicar no Feed'),
            ),
          ],
        ),
      ),
    );
  }
}