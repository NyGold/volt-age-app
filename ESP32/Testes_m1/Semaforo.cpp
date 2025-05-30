#include <Arduino.h>

// Definição dos pinos onde os LEDs do módulo semáforo estão conectados no ESP32
// GPIO27 (R), GPIO26 (Y), GPIO25 (G)
// Módulo ativo em alto: HIGH = LIGA, LOW = DESLIGA
const int LED_VERMELHO = 27;
const int LED_AMARELO  = 26;
const int LED_VERDE    = 25;

const int TEMPO_VERMELHO = 5000;
const int TEMPO_AMARELO  = 2000;
const int TEMPO_VERDE    = 5000;

void setup() {
  Serial.begin(115200);
  Serial.println("===================================");
  Serial.println("  Iniciando Semáforo Simples       ");
  Serial.println("  (R -> Y -> G, Um LED por Vez)    ");
  Serial.println("===================================");

  pinMode(LED_VERMELHO, OUTPUT);
  pinMode(LED_AMARELO, OUTPUT);
  pinMode(LED_VERDE, OUTPUT);

  desligarTodos(); // Garante que tudo comece desligado
}

// Função auxiliar para desligar todos os LEDs (LOW = DESLIGA)
void desligarTodos() {
  digitalWrite(LED_VERMELHO, LOW);
  digitalWrite(LED_AMARELO, LOW);
  digitalWrite(LED_VERDE, LOW);
}

void loop() {
  // --- FASE: VERMELHO ---
  Serial.println("Fase: VERMELHO");
  desligarTodos();
  digitalWrite(LED_VERMELHO, HIGH);  // LIGA Vermelho
  delay(TEMPO_VERMELHO);

  // --- FASE: AMARELO ---
  Serial.println("Fase: AMARELO");
  desligarTodos();
  digitalWrite(LED_AMARELO, HIGH);   // LIGA Amarelo
  delay(TEMPO_AMARELO);

  // --- FASE: VERDE ---
  Serial.println("Fase: VERDE");
  desligarTodos();
  digitalWrite(LED_VERDE, HIGH);     // LIGA Verde
  delay(TEMPO_VERDE);
}
