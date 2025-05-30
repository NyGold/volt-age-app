// --- Definição do Pino ---
const int PINO_SENSOR_UMIDADE_AO = 35; // Conecte o pino 'AOUT' do sensor ao GPIO35 do ESP32

void setup() {
  Serial.begin(115200);
  Serial.println("===================================");
  Serial.println("  Teste do Sensor de Umidade do Solo");
  Serial.println("  (Sensor Capacitivo, Lendo AOUT)  ");
  Serial.println("===================================");

  // O pino ADC já é configurado automaticamente como entrada quando analogRead() é usado.
}

void loop() {
  // Lê o valor analógico do pino do sensor
  int valorUmidade = analogRead(PINO_SENSOR_UMIDADE_AO);

  Serial.print("Leitura do Sensor de Umidade: ");
  Serial.println(valorUmidade);

  // --- Limiares de Calibração Ajustados ---
  // Com base nas suas leituras: 4095 (seco) a 2300 (molhado)
  // Vamos usar um valor intermediário para "seco" e "úmido o suficiente".
  // Esses valores podem ser ajustados novamente com testes em solo real.

  // Solo MUITO SECO: Se a leitura for próxima do valor máximo seco (4095)
  if (valorUmidade > 3500) { // Ex: acima de 3500 (metade entre 4095 e ~2900)
    Serial.println("Status: Solo MUITO SECO. Precisa de água!");
  } 
  // Solo Úmido o suficiente: Se a leitura estiver entre o "seco" e o "muito úmido"
  else if (valorUmidade > 2500) { // Ex: entre 2500 e 3500
    Serial.println("Status: Solo Úmido o suficiente.");
  } 
  // Solo MUITO ÚMIDO: Se a leitura for próxima do valor mínimo úmido (2300)
  else { // Abaixo de 2500 (incluindo 2300 e abaixo)
    Serial.println("Status: Solo MUITO ÚMIDO.");
  }

  delay(1000); // Espera 1 segundo entre as leituras para facilitar a visualização
}