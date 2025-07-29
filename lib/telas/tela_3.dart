import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';

class Tela3 extends StatelessWidget {
  const Tela3({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        final isLuzAcesa = provider.iluminacaoStatus.toUpperCase() == "ACESA";
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildCardStatus(provider, isLuzAcesa, context),
                const SizedBox(height: 30),
                _buildCardControleManual(provider, context),
                const SizedBox(height: 20),
                _buildCardModoAutomatico(provider, context),
                const SizedBox(height: 20),
                _buildCardControleCor(provider, context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatus(MqttProvider provider, bool isLuzAcesa, BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isLuzAcesa ? Colors.yellow.shade50 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              isLuzAcesa ? Icons.lightbulb : Icons.lightbulb_outline,
              size: 80,
              color: isLuzAcesa ? Colors.yellow.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
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
            Text(
              'Última atualização: ${provider.iluminacaoStatus}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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

  Widget _buildCardControleManual(MqttProvider provider, BuildContext context) {
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
                      ? () => provider.publicarComandoIluminacao('LIGAR_MANUAL')
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
                      ? () => provider.publicarComandoIluminacao('DESLIGAR_MANUAL')
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

  Widget _buildCardModoAutomatico(MqttProvider provider, BuildContext context) {
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
                  ? () => provider.publicarComandoIluminacao('AUTOMATICO')
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

  Widget _buildCardControleCor(MqttProvider provider, BuildContext context) {
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
                _buildColorButton(provider, Colors.red, '#FF0000', context),
                _buildColorButton(provider, Colors.green, '#00FF00', context),
                _buildColorButton(provider, Colors.blue, '#0000FF', context),
                _buildColorButton(provider, Colors.yellow, '#FFFF00', context),
                _buildColorButton(provider, Colors.purple, '#800080', context),
                _buildColorButton(provider, Colors.white, '#FFFFFF', context),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(MqttProvider provider, Color color, String hexCode, BuildContext context) {
    return InkWell(
      onTap: provider.isConnected
          ? () => provider.publicarComandoIluminacao(hexCode)
          : null,
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