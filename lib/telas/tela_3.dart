/* TODO: 
* 1 criar os stream na home_page com os tópicos que ele vai ouvir
* 2 passar os streams para as telas que vão ouvir
* 3 criar os streams nas telas que vão ouvir
* 4 criar os listeners para atualizar o estado das telas
* 5 criar os métodos de publicar comandos para cada tela
* 6 criar os métodos de publicar comandos em background para cada tela 

* qualquer coisa é só ver o gemini ou ver tela_1 que já está quase tudo certo.
*/

// ARQUIVO: lib/telas/tela_3.dart (VERSÃO FINAL)
// ARQUIVO: lib/telas/tela_3.dart (VERSÃO FINAL CORRIGIDA)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart'; // ✅ Certifique-se de que o caminho está correto

class Tela3 extends StatelessWidget {
  const Tela3({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tela3Content();
  }
}

class Tela3Content extends StatefulWidget {
  const Tela3Content({super.key});

  @override
  State<Tela3Content> createState() => _Tela3ContentState();
}

class _Tela3ContentState extends State<Tela3Content> {
  String luzStatus = "Carregando...";
  late MqttProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<MqttProvider>(context, listen: false);
    _provider.iluminacaoStatus = "Carregando...";
    _subscribeToIluminacaoStatus();
  }

  void _subscribeToIluminacaoStatus() {
    // Não precisamos assinar manualmente, o MqttProvider já faz isso
  }

  void _publicarComando(String comando) {
    if (_provider.isConnected) {
      _provider.publicarComandoIluminacao(comando);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MQTT não conectado. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildCardStatus(provider),
                const SizedBox(height: 30),
                _buildCardControleManual(provider),
                const SizedBox(height: 20),
                _buildCardModoAutomatico(provider),
                const SizedBox(height: 20),
                _buildCardControleCor(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatus(MqttProvider provider) {
  final isLuzAcesa = provider.iluminacaoStatus.toUpperCase() == "ACESA";
  return Card(
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    color: isLuzAcesa ? Colors.yellow.shade50 : Colors.grey.shade200,
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Ícone dinâmico
          Icon(
            isLuzAcesa ? Icons.lightbulb : Icons.lightbulb_outline,
            size: 80,
            color: isLuzAcesa ? Colors.yellow.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          // Texto de status
          Text(
            isLuzAcesa ? 'Luzes Acesas' : 'Luzes Apagadas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isLuzAcesa ? Colors.green.shade700 : Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Detalhe do feed
          Text(
            'Última atualização: ${provider.iluminacaoStatus}',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Botão de toggle (opcional)
          if (provider.isConnected)
            ElevatedButton.icon(
              onPressed: () {
                _publicarComando(isLuzAcesa ? 'DESLIGAR_MANUAL' : 'LIGAR_MANUAL');
              },
              icon: Icon(isLuzAcesa ? Icons.power_settings_new : Icons.power_settings_new_rounded),
              label: Text(isLuzAcesa ? 'Desligar Luz' : 'Ligar Luz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLuzAcesa ? Colors.red.shade400 : Colors.green.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          if (!provider.isConnected)
            const Text(
              "⚠️ Offline: Conecte-se para controlar a iluminação.",
              style: TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    ),
  );
}

  Widget _buildCardControleManual(MqttProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Controle Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: provider.isConnected
                      ? () => _publicarComando('LIGAR_MANUAL')
                      : null,
                  icon: const Icon(Icons.wb_sunny),
                  label: const Text('Ligar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: provider.isConnected
                      ? () => _publicarComando('DESLIGAR_MANUAL')
                      : null,
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('Desligar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardModoAutomatico(MqttProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Modo Automático', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.isConnected
                  ? () => _publicarComando('AUTOMATICO')
                  : null,
              icon: const Icon(Icons.brightness_auto),
              label: const Text('Ativar Modo Automático'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControleCor(MqttProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Controle de Cor (Fita LED)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildColorButton(Colors.red, '#FF0000'),
                _buildColorButton(Colors.green, '#00FF00'),
                _buildColorButton(Colors.blue, '#0000FF'),
                _buildColorButton(Colors.yellow, '#FFFF00'),
                _buildColorButton(Colors.purple, '#800080'),
                _buildColorButton(Colors.white, '#FFFFFF'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color, String hexCode) {
    return InkWell(
      onTap: () => _publicarComando(hexCode),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    );
  }
}