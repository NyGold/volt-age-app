// --- Definição dos Pinos ---
const int PINO_SENSOR_GAS_DO = 27; // Conecte o pino 'DO' do sensor MQ-5 ao GPIO27 do ESP32
const int PINO_LED_VERMELHO  = 25; // Conecte o LED Vermelho ao GPIO25 do ESP32 (com resistor!)

void setup() {
  Serial.begin(115200);
  Serial.println("===================================");
  Serial.println("  Detector de Gás MQ-5             ");
  Serial.println("  (Alerta com LED Vermelho)        ");
  Serial.println("===================================");

  // Configura o pino do sensor como ENTRADA
  pinMode(PINO_SENSOR_GAS_DO, INPUT);
  
  // Configura o pino do LED como SAÍDA
  pinMode(PINO_LED_VERMELHO, OUTPUT);

  // Garante que o LED esteja desligado no início
  digitalWrite(PINO_LED_VERMELHO, LOW); // LED desligado (se for ativo em alto)
  // Se o seu LED precisar de HIGH para desligar (ativo em baixo), mude para HIGH.
  // Mas a maioria dos LEDs ligados a um GPIO comum são "ativo em alto".
}

void loop() {
  // Lê o estado digital do pino do sensor MQ-5
  int estadoGas = digitalRead(PINO_SENSOR_GAS_DO);

  // A lógica de detecção de gás pode variar entre os módulos MQ-x:
  // Alguns módulos enviam LOW quando detectam gás (ACIMA do limite)
  // Outros módulos enviam HIGH quando detectam gás (ACIMA do limite)

  // O mais comum para sensores MQ é serem "ativo em baixo" para alarme:
  // LOW = GÁS DETECTADO (perigo)
  // HIGH = NENHUM GÁS (seguro)
  if (estadoGas == LOW) {
    Serial.println("!!! GÁS DETECTADO - PERIGO !!!");
    digitalWrite(PINO_LED_VERMELHO, HIGH); // Acende o LED Vermelho (se for ativo em alto)
  } else {
    Serial.println("Nenhum gás detectado.");
    digitalWrite(PINO_LED_VERMELHO, LOW);  // Desliga o LED Vermelho
  }

  delay(500); // Pequeno atraso para não lotar o Monitor Serial
}