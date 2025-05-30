// --- Definição do Pino ---
const int PINO_SENSOR_PIR = 27; // Conecte o pino 'OUT' do sensor PIR ao GPIO27 do ESP32

void setup() {
  Serial.begin(115200);
  Serial.println("===================================");
  Serial.println("  Teste do Sensor PIR de Movimento ");
  Serial.println("  (Lendo Saída Digital - OUT)      ");
  Serial.println("===================================");

  // Configura o pino do sensor PIR como ENTRADA
  // O sensor envia o sinal para o ESP32
  pinMode(PINO_SENSOR_PIR, INPUT);
}

void loop() {
  // Lê o estado digital do pino do sensor PIR
  int estadoMovimento = digitalRead(PINO_SENSOR_PIR);

  // Sensores PIR geralmente enviam HIGH quando detectam movimento
  if (estadoMovimento == HIGH) {
    Serial.println(">>> MOVIMENTO DETECTADO! <<<");
    // Você pode adicionar um pequeno delay aqui para evitar múltiplas mensagens rapidamente
    // após a detecção inicial, dependendo do ajuste de tempo do PIR.
    delay(500); // Exemplo: Espera um pouco após a detecção
  } else {
    Serial.println("Nenhum movimento.");
  }

  // Pequeno atraso para não lotar o Monitor Serial, se o PIR não estiver em estado HIGH
  delay(100); 
}