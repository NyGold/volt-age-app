#include <FastLED.h>

// --- CONFIGURAÇÕES DA FITA ---
#define LED_PIN     2
#define NUM_LEDS    30
#define BRIGHTNESS  150
#define LED_TYPE    WS2812B
#define COLOR_ORDER GRB

// --- CONFIGURAÇÕES DO SENSOR PIR ---
#define PIR_PIN     15 // Pino D15 onde o pino OUT do sensor está conectado

CRGB leds[NUM_LEDS];

void setup() {
  Serial.begin(115200);
  delay(2000);

  // Configuração da FastLED
  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(BRIGHTNESS);
  
  // Configura o pino do sensor PIR como entrada
  pinMode(PIR_PIN, INPUT);

  // Garante que os LEDs comecem apagados
  FastLED.clear();
  FastLED.show();
  
  Serial.println("Sistema iniciado. Aguardando movimento...");
}

void loop() {
  // Verifica se o sensor detectou movimento
  if (digitalRead(PIR_PIN) == HIGH) {
    // Se detectou movimento...
    Serial.println("Movimento detectado! Acendendo os LEDs por 5 segundos...");
    
    // 1. Acende as luzes com a animação que você quiser
    acenderLuzes();
    
    // 2. Espera EXATAMENTE 5 segundos com as luzes acesas.
    // O programa para aqui durante esse tempo.
    delay(5000);
    
    // 3. Apaga as luzes
    apagarLuzes();
    Serial.println("LEDs apagados. Aguardando novo movimento...");

    // 4. Uma pequena pausa para o sensor PIR se estabilizar antes da próxima leitura.
    // Isso ajuda a evitar que ele dispare em falso logo em seguida.
    delay(1000); 
  }
  
  // Se não houver movimento (digitalRead == LOW), o código não entra no 'if' e o loop
  // simplesmente recomeça, mantendo os LEDs apagados e verificando novamente.
}

// Função para ACENDER os LEDs (você pode colocar qualquer animação aqui!)
void acenderLuzes() {
  // Exemplo: Acende todos os LEDs com uma cor branca morna
  fill_solid(leds, NUM_LEDS, CRGB::FloralWhite);
  FastLED.show();
}

// Função para APAGAR os LEDs
void apagarLuzes() {
  FastLED.clear();
  FastLED.show();
}
