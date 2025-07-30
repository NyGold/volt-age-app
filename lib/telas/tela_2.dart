// ARQUIVO: lib/telas/tela_2.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:volt_age_app/mqtt_services/mqtt_provider.dart';

class Tela2 extends StatelessWidget {
  const Tela2({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tela2Content();
  }
}

class Tela2Content extends StatefulWidget {
  const Tela2Content({super.key});

  @override
  State<Tela2Content> createState() => _Tela2ContentState();
}

class _Tela2ContentState extends State<Tela2Content> {
  Future<void> _refreshData() async {
    final provider = Provider.of<MqttProvider>(context, listen: false);
    await provider.refreshAllFeeds();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _buildCardMedidorUmidade(context, provider),
                  const SizedBox(height: 20),
                  _buildCardAjusteSensibilidade(context, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardMedidorUmidade(BuildContext context, MqttProvider provider) {
    final bool precisaRegar = provider.statusRega.toUpperCase() == "REGAR_AGORA";
    final String statusTexto = precisaRegar 
        ? "Regue o Solo!" 
        : "Solo úmido";
    
    Color corStatus;
    IconData iconStatus;
    
    if (precisaRegar) {
      corStatus = Colors.red.shade700;
      iconStatus = Icons.water_drop;
    } else {
      corStatus = Colors.green.shade700;
      iconStatus = Icons.water;
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Umidade do Solo', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
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
                        value: provider.umidadeSolo,
                        cornerStyle: CornerStyle.bothCurve,
                        width: 0.2,
                        sizeUnit: GaugeSizeUnit.factor,
                        color: precisaRegar ? Colors.red.shade300 : Colors.green.shade300,
                        enableAnimation: true,
                      )
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        positionFactor: 0.1,
                        angle: 90,
                        widget: Text(
                          '${provider.umidadeSolo.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 48, 
                            fontWeight: FontWeight.bold, 
                            color: Color(0xFF0D47A1)
                          ),
                        ),
                      ),
                      GaugeAnnotation(
                        positionFactor: 0.7,
                        angle: 90,
                        widget: Text(
                          'Limiar: ${provider.limiarUmidade.round()}%',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: corStatus.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                // ignore: deprecated_member_use
                border: Border.all(color: corStatus.withOpacity(0.5))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconStatus, color: corStatus, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    statusTexto, 
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: corStatus
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAjusteSensibilidade(BuildContext context, MqttProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Ajustar Sensibilidade', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Regar quando a umidade for menor que: ${provider.limiarUmidade.round()}%', 
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Slider(
              value: provider.limiarUmidade,
              min: 10,
              max: 70,
              divisions: 60,
              label: provider.limiarUmidade.round().toString(),
              onChanged: (double value) {
                // Atualiza o valor visualmente enquanto arrasta
                // Mas não atualiza no ESP32 ainda
                provider.limiarUmidade = value;
                setState(() {}); // Atualiza a UI para mostrar o novo valor
              },
              onChangeEnd: (double value) {
                // Chama a ação no provider para atualizar no ESP32
                provider.publicarLimiar(value);
                
                // Mostrar feedback visual
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Limiar de umidade atualizado para ${value.round()}%'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Menos sensível', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text('Mais sensível', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}