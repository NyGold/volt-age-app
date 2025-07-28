/* TODO: 
* 1 criar os stream na home_page com os tópicos que ele vai ouvir
* 2 passar os streams para as telas que vão ouvir
* 3 criar os streams nas telas que vão ouvir
* 4 criar os listeners para atualizar o estado das telas
* 5 criar os métodos de publicar comandos para cada tela
* 6 criar os métodos de publicar comandos em background para cada tela 

* qualquer coisa é só ver o gemini ou ver tela_1 que já está quase tudo certo.
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';

class Tela3 extends StatelessWidget {
  const Tela3({super.key});

  @override
  Widget build(BuildContext context) {
    print("🔄 [TELA-3] Reconstruindo...");
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        print("💡 [TELA-3] Status atual da luz: ${provider.luzStatus}");
        
        // Calcula os valores uma vez para evitar recálculos
        final String luzStatus = provider.luzStatus;
        final bool isLuzAcesa = luzStatus.toUpperCase() == 'ACESA';
        final bool isConnected = provider.isConnected;

        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _buildCardStatus(luzStatus, isLuzAcesa),
                  const SizedBox(height: 30),
                  _buildCardControleManual(context, provider, isConnected),
                  const SizedBox(height: 20),
                  _buildCardModoAutomatico(context, provider, isConnected),
                  const SizedBox(height: 20),
                  _buildCardControleCor(context, provider, isConnected),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatus(String luzStatus, bool isLuzAcesa) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Icon(
              isLuzAcesa ? Icons.lightbulb : Icons.lightbulb_outline,
              size: 80,
              color: isLuzAcesa ? Colors.amber.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            const Text(
              'Status Atual da Iluminação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              luzStatus,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isLuzAcesa ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControleManual(BuildContext context, MqttProvider provider, bool isConnected) {
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
                  onPressed: isConnected ? () => provider.publicarComandoIluminacao('LIGAR_MANUAL') : null,
                  icon: const Icon(Icons.wb_sunny),
                  label: const Text('Ligar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: isConnected ? () => provider.publicarComandoIluminacao('DESLIGAR_MANUAL') : null,
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('Desligar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardModoAutomatico(BuildContext context, MqttProvider provider, bool isConnected) {
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
              onPressed: isConnected ? () => provider.publicarComandoIluminacao('AUTOMATICO') : null,
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

  Widget _buildCardControleCor(BuildContext context, MqttProvider provider, bool isConnected) {
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
                _buildColorButton(provider, Colors.red, '#FF0000', isConnected),
                _buildColorButton(provider, Colors.green, '#00FF00', isConnected),
                _buildColorButton(provider, Colors.blue, '#0000FF', isConnected),
                _buildColorButton(provider, Colors.yellow, '#FFFF00', isConnected),
                _buildColorButton(provider, Colors.purple, '#800080', isConnected),
                _buildColorButton(provider, Colors.white, '#FFFFFF', isConnected),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(MqttProvider provider, Color color, String hexCode, bool isConnected) {
    return InkWell(
      onTap: isConnected ? () => provider.publicarComandoIluminacao(hexCode) : null,
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