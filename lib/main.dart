import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:volt_age_app/mqtt_services/mqtt.dart';
import 'package:volt_age_app/services/notific_serv.dart';
import 'package:volt_age_app/tela_inicial.dart';
// Importação adicionada para corrigir o erro
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Esta função precisa ficar fora de qualquer classe (top-level)
// para que o sistema possa chamá-la quando o app estiver em segundo plano.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('Ação de notificação recebida em background: ${notificationResponse.actionId}');
  
  // Verifica se o botão com o ID 'FECHAR_GAS_ACTION' foi pressionado
  if (notificationResponse.actionId == 'FECHAR_GAS_ACTION') {
    print('Comando para fechar o gás acionado pela notificação.');
    // Tenta publicar o comando para fechar o gás
    _publicarComandoBackground('valvula-gas-controle', 'FECHAR_AGORA');
  }
}

/// Função auxiliar para se conectar e publicar um comando MQTT em segundo plano.
Future<void> _publicarComandoBackground(String feed, String comando) async {
  try {
    // Carrega as variáveis de ambiente para obter as credenciais
    await dotenv.load(fileName: ".env");
    
    // Conecta ao broker com um ID de cliente único para evitar conflitos
    final client = await connect(isBackground: true); 
    
    final usuario = dotenv.env["ADAFRUIT_IO_USERNAME"];
    if (usuario == null) {
      print("Erro: Usuário não encontrado no .env em background.");
      return;
    }

    final comandoTopic = "$usuario/feeds/$feed";
    final builder = MqttClientPayloadBuilder();
    builder.addString(comando);
    
    print('Publicando comando em background no tópico: $comandoTopic');
    client.publishMessage(comandoTopic, MqttQos.atLeastOnce, builder.payload!);
    
    // Aguarda um instante para garantir o envio antes de desconectar
    await Future.delayed(const Duration(seconds: 2));
    client.disconnect();
    print("Cliente MQTT de background desconectado com sucesso.");

  } catch (e) {
    print('ERRO ao publicar comando em background: $e');
  }
}

void main() async {
  // Garante que todos os plugins do Flutter sejam inicializados antes do app rodar
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o serviço de notificação, passando a função de background
  await NotificationService.initialize(onSelectNotification: notificationTapBackground);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Volt-Age App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}
