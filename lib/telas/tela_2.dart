// ARQUIVO: lib/telas/tela_2.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';

class Tela2 extends StatelessWidget {
  const Tela2({super.key});

  @override
  Widget build(BuildContext context) {
    print("🔄 [TELA-2] Reconstruindo...");
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        print("📊 [TELA-2] Valores atuais - Umidade: ${provider.umidadeSolo}%, Status: ${provider.statusRega}");
        
        // Calcula os valores uma vez para evitar recálculos
        final bool precisaRegar = provider.statusRega.toUpperCase() == "REGAR_AGORA";
        final double umidadeAtual = provider.umidadeSolo;
        final double limiarAtual = provider.limiarUmidade;

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildCardMedidorUmidade(context, umidadeAtual, precisaRegar),
                const SizedBox(height: 20),
                _buildCardAjusteSensibilidade(context, provider, limiarAtual),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardMedidorUmidade(BuildContext context, double umidadeAtual, bool precisaRegar) {
    final String statusTexto = precisaRegar ? "Regar Agora" : "Umidade OK";
    final Color corStatus = precisaRegar ? Colors.orange.shade800 : Colors.cyan.shade700;
    final IconData iconStatus = precisaRegar ? Icons.water_drop_rounded : Icons.check_circle_outline_rounded;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Umidade da Planta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 250,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    showLabels: false,
                    showTicks: false,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 0.2,
                      cornerStyle: CornerStyle.bothCurve,
                      color: Color.fromARGB(255, 222, 238, 244),
                      thicknessUnit: GaugeSizeUnit.factor,
                    ),
                    pointers: <GaugePointer>[
                      RangePointer(
                        value: umidadeAtual, // <-- DADO DO PROVIDER
                        cornerStyle: CornerStyle.bothCurve,
                        width: 0.2,
                        sizeUnit: GaugeSizeUnit.factor,
                        color: Colors.lightBlue.shade300,
                        enableAnimation: true,
                      )
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        positionFactor: 0.1,
                        angle: 90,
                        widget: Text(
                          '${umidadeAtual.toStringAsFixed(0)}%', // <-- DADO DO PROVIDER
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: corStatus.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: corStatus.withOpacity(0.5))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconStatus, color: corStatus, size: 24),
                  const SizedBox(width: 10),
                  Text(statusTexto, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: corStatus)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardAjusteSensibilidade(BuildContext context, MqttProvider provider, double limiarAtual) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Ajustar Sensibilidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Regar quando a umidade for menor que: ${limiarAtual.round()}%', // <-- DADO DO PROVIDER
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            Slider(
              value: limiarAtual, // <-- DADO DO PROVIDER
              min: 10,
              max: 70,
              divisions: 60,
              label: limiarAtual.round().toString(),
              onChanged: (double value) {
                // Para não sobrecarregar, podemos apenas atualizar o provider no final.
                // Mas se quiser a UI atualizando enquanto arrasta, chame um método no provider
                // que atualiza o valor e chama notifyListeners().
              },
              onChangeEnd: (double value) {
                // Chama a ação no provider
                provider.publicarLimiar(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}