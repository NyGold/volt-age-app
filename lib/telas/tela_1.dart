// ARQUIVO: lib/telas/tela_1.dart (VERSÃO FINAL E ROBUSTA)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart'; // Corrija para o caminho do seu provider

class Tela1 extends StatelessWidget {
  const Tela1({super.key});

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
                const SizedBox(height: 20),
                _buildCardStatusPrincipal(provider),
                const SizedBox(height: 20),
                _buildCardControleValvula(provider),
                const SizedBox(height: 20),
                _buildCardLogicaEsquecimento(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Card que exibe o Status Geral da Cozinha.
  Widget _buildCardStatusPrincipal(MqttProvider provider) {
    final status = provider.gasAlerta;
    
    // --- LÓGICA DE UI APRIMORADA ---
    bool isAlert = status.contains("ALARME") || status.contains("FOGO_SEM_PRESENCA");
    bool isLoading = status == "Carregando...";
    
    Color statusColor;
    IconData statusIcon;
    Color cardBackgroundColor;

    if (isLoading) {
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.hourglass_empty_rounded;
      cardBackgroundColor = Colors.grey.shade200;
    } else if (isAlert) {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.warning_amber_rounded;
      cardBackgroundColor = Colors.red.shade50;
    } else {
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle_outline_rounded;
      cardBackgroundColor = Colors.green.shade50;
    }

    String getMensagemStatus() {
      if (status.startsWith("FOGO_CONTANDO")) return "Contagem de segurança...";
      switch (status) {
        case "OK": return "Tudo certo";
        case "ALARME_GAS": return "PERIGO: Gás vazando!";
        case "FOGO_SEM_PRESENCA": return "PERIGO: Fogão esquecido!";
        case "ALERTA_APP": return "Gás fechado pelo celular";
        case "FOGO_TIMER_ATIVO": return "Timer de segurança pausado";
        case "Carregando...": return "Verificando...";
        default: return "Status: $status"; // Mostra o status desconhecido
      }
    }

    return Card(
      elevation: 6,
      color: cardBackgroundColor, // Usa a cor de fundo definida
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(statusIcon, size: 60, color: statusColor),
            const SizedBox(height: 12),
            const Text(
              'Status Geral da Cozinha',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              getMensagemStatus(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Card para controle manual da válvula de gás.
  Widget _buildCardControleValvula(MqttProvider provider) {
    final bool isAberta = provider.valvulaEstado.toUpperCase() == "ABERTA";
    final bool isOnline = provider.isConnected;

    final String statusTexto = isAberta ? "Gás Aberto" : "Gás Fechado";
    final Color statusCor = isAberta ? Colors.green.shade800 : Colors.red.shade800;
    final Color cardColor = isAberta ? Colors.green.shade100 : Colors.red.shade100;
    final IconData statusIcon = isAberta ? Icons.lock_open_rounded : Icons.lock_rounded;

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusCor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusCor, size: 32),
                const SizedBox(width: 12),
                Text(
                  statusTexto,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: statusCor),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isOnline ? () => provider.publicarComandoValvula('ABRIR_AGORA') : null,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('ABRIR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isOnline ? () => provider.publicarComandoValvula('FECHAR_AGORA') : null,
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('FECHAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Card para gerenciar a lógica de segurança contra esquecimento.
  Widget _buildCardLogicaEsquecimento(MqttProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Segurança Contra Esquecimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Pausar timer de segurança', style: TextStyle(fontSize: 16)),
              trailing: Switch(
                value: provider.logicaEsquecimentoAtivada,
                onChanged: provider.isConnected
                    ? (bool value) {
                        provider.setLogicaEsquecimento(value);
                      }
                    : null,
                activeTrackColor: Colors.orange.shade200,
                activeColor: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: provider.isConnected ? () => provider.resetarAlertaDeFogo() : null,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Resetar Alerta de Fogo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}