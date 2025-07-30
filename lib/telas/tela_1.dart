// ARQUIVO: lib/telas/tela_1.dart (CORREÇÃO FINAL)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';

class Tela1 extends StatelessWidget {
  const Tela1({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tela1Content();
  }
}

class Tela1Content extends StatefulWidget {
  const Tela1Content({super.key});

  @override
  State<Tela1Content> createState() => _Tela1ContentState();
}

class _Tela1ContentState extends State<Tela1Content> with TickerProviderStateMixin {
  int _tempoSelecionado = 15; // Tempo padrão em minutos
  final List<int> _opcoesTempo = [1, 15, 30, 60];
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  String _formatarStatus(String status) {
    if (status == "OK") return "Sistema operando normalmente";
    if (status == "ALARME_GAS") return "ALERTA: Vazamento de gás detectado!";
    if (status == "FOGO_SEM_PRESENCA") return "PERIGO: Fogão esquecido!";
    if (status == "ALERTA_APP") return "Gás fechado pelo celular";
    if (status == "FOGO_TIMER_ATIVO") return "Timer de segurança pausado";
    if (status.startsWith("FOGO_CONTANDO")) return "Contagem regressiva para alerta";
    if (status == "Carregando...") return "Verificando...";
    return "Status: $status";
  }

  Color _obterCorStatus(String status) {
    if (status == "OK" || status == "Carregando...") return Colors.green.shade700;
    if (status == "ALARME_GAS" || status == "FOGO_SEM_PRESENCA") return Colors.red.shade700;
    return Colors.orange.shade700;
  }

  String _obterTempoRestante(String status) {
    if (status.startsWith("FOGO_CONTANDO (")) {
      final startIndex = status.indexOf('(') + 1;
      final endIndex = status.indexOf(' s)');
      if (startIndex > 0 && endIndex > startIndex) {
        return status.substring(startIndex, endIndex);
      }
    }
    return "";
  }

  bool _estaNaContagem(String status) {
    return status.startsWith("FOGO_CONTANDO");
  }

  bool _estaEmAlarme(String status) {
    return status == "FOGO_SEM_PRESENCA";
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<MqttProvider>(context, listen: false);
    
    // Método CORRETO para atualizar os dados
    await provider.refreshAllFeeds();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        final status = provider.gasAlerta;
        final isLigada = provider.valvulaEstado.toUpperCase() == "ABERTA";
        final statusColor = _obterCorStatus(status);
        final statusText = _formatarStatus(status);
        final tempoRestante = _obterTempoRestante(status);
        final estaNaContagem = _estaNaContagem(status);
        final estaEmAlarme = _estaEmAlarme(status);

        return RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildCardStatus(status, statusText, statusColor, tempoRestante, estaNaContagem, estaEmAlarme),
                const SizedBox(height: 30),
                _buildCardValvulaGas(provider, isLigada, estaEmAlarme),
                const SizedBox(height: 20),
                _buildCardTempoLogicaEsquecimento(provider, estaNaContagem, estaEmAlarme),
                if (estaNaContagem || estaEmAlarme)
                  _buildCardExpansaoTempo(provider, estaNaContagem, estaEmAlarme),
                const SizedBox(height: 20),
                _buildCardControleLogicaEsquecimento(provider, estaNaContagem, estaEmAlarme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatus(String status, String statusText, Color statusColor, String tempoRestante, bool estaNaContagem, bool estaEmAlarme) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: status == "OK" || status == "Carregando..." 
          ? Colors.green.shade50 
          : status == "ALARME_GAS" || status == "FOGO_SEM_PRESENCA" 
              ? Colors.red.shade50 
              : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              status == "OK" || status == "Carregando..." 
                  ? Icons.check_circle 
                  : status == "ALARME_GAS" || status == "FOGO_SEM_PRESENCA"
                      ? Icons.warning_amber_rounded
                      : Icons.info,
              size: 60,
              color: statusColor,
            ),
            const SizedBox(height: 12),
            Text(
              status == "OK" || status == "Carregando..." 
                  ? "Sistema Seguro" 
                  : status == "ALARME_GAS" || status == "FOGO_SEM_PRESENCA"
                      ? "ATENÇÃO!" 
                      : "Aviso",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (estaNaContagem && tempoRestante.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Tempo restante: $tempoRestante segundos",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardValvulaGas(MqttProvider provider, bool isLigada, bool estaEmAlarme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Válvula de Gás', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Icon(
              isLigada ? Icons.local_gas_station : Icons.local_gas_station_outlined,
              size: 50,
              color: isLigada ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              isLigada ? 'ABERTA' : 'FECHADA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLigada ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: provider.isConnected && !isLigada && !estaEmAlarme
                      ? () => provider.publicarComandoValvula('ABRIR_AGORA')
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Abrir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLigada || estaEmAlarme ? Colors.grey.shade400 : Colors.green.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: provider.isConnected && isLigada
                      ? () => provider.publicarComandoValvula('FECHAR_AGORA')
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Fechar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLigada ? Colors.red.shade400 : Colors.grey.shade400,
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

  Widget _buildCardTempoLogicaEsquecimento(MqttProvider provider, bool estaNaContagem, bool estaEmAlarme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tempo da Lógica de Esquecimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: _tempoSelecionado,
              isExpanded: true,
              onChanged: provider.isConnected && !estaNaContagem && !estaEmAlarme
                  ? (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _tempoSelecionado = newValue;
                        });
                      }
                    }
                  : null,
              items: _opcoesTempo.map((minutos) {
                String label = minutos == 1 ? '$minutos minuto (demonstração)' : '$minutos minutos';
                return DropdownMenuItem(
                  value: minutos,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Tempo selecionado: $_tempoSelecionado minuto${_tempoSelecionado != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            if (estaNaContagem || estaEmAlarme)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Não é possível alterar o tempo durante a contagem ou em estado de alarme',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardExpansaoTempo(MqttProvider provider, bool estaNaContagem, bool estaEmAlarme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              estaNaContagem 
                  ? 'Tempo Restante' 
                  : 'Tempo Expirado - Ação Necessária',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (estaNaContagem)
              Text(
                'Deseja expandir o tempo para continuar cozinhando?',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            if (estaEmAlarme)
              Text(
                'O tempo de segurança expirou. Deseja fechar a válvula ou expandir o tempo?',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (estaNaContagem)
                  ElevatedButton(
                    onPressed: provider.isConnected
                        ? () => _expandirTempo(provider)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Expandir Tempo'),
                  ),
                if (estaEmAlarme)
                  ElevatedButton(
                    onPressed: provider.isConnected
                        ? () => provider.publicarComandoValvula('FECHAR_AGORA')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Fechar Válvula'),
                  ),
                if (estaEmAlarme)
                  ElevatedButton(
                    onPressed: provider.isConnected
                        ? () => _expandirTempo(provider)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Expandir Tempo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardControleLogicaEsquecimento(MqttProvider provider, bool estaNaContagem, bool estaEmAlarme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Lógica de Esquecimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Ativar lógica de segurança', style: TextStyle(fontSize: 16)),
              subtitle: Text('Desativa após $_tempoSelecionado minuto${_tempoSelecionado != 1 ? 's' : ''} sem presença'),
              trailing: Switch(
                value: provider.logicaEsquecimentoAtivada,
                onChanged: provider.isConnected && !estaNaContagem && !estaEmAlarme
                    ? (bool value) {
                        provider.setLogicaEsquecimento(value);
                      }
                    : null,
                activeTrackColor: Colors.orange.shade200,
                activeColor: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              provider.logicaEsquecimentoAtivada
                  ? estaNaContagem
                      ? 'A lógica de segurança está ATIVA\n(Desativa após $_tempoSelecionado minuto${_tempoSelecionado != 1 ? 's' : ''} sem presença)'
                      : estaEmAlarme
                          ? 'O tempo de segurança expirou!\nSelecione uma ação acima'
                          : 'A lógica de segurança está ATIVA\n(Desativa após $_tempoSelecionado minuto${_tempoSelecionado != 1 ? 's' : ''} sem presença)'
                  : 'A lógica de segurança está DESATIVADA\n(O fogão permanecerá ligado sem supervisão)',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _expandirTempo(MqttProvider provider) {
    // Usamos o feed fogo-timer-reset para reiniciar a contagem
    provider.resetarAlertaDeFogo();
    
    // Se estiver em estado de alarme, precisamos reativar a lógica de esquecimento
    if (provider.gasAlerta == "FOGO_SEM_PRESENCA") {
      provider.setLogicaEsquecimento(true);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tempo expandido! Mais $_tempoSelecionado minutos adicionados.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}