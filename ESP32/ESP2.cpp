// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <AdafruitIO_WiFi.h>
#include <FastLED.h>
#include <Wire.h>
#include <BH1750.h>

// --- Inclui o arquivo de segredos ---
#include "secrets.h" 

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Feeds do Adafruit IO (2 Feeds) ---
AdafruitIO_Feed *iluminacaoComandoSub = io.feed("iluminacao-comando");
AdafruitIO_Feed *iluminacaoStatusFeed = io.feed("iluminacao-status");

// --- Pinos e Configurações ---
const int PINO_PIR      = 15; 
const int PINO_FITA_LED = 2;  
const int NUM_LEDS      = 30; 
const int BRIGHTNESS    = 150;

// --- Constantes de Lógica ---
const long TEMPO_LUZ_ACESA_APOS_MOVIMENTO = 30000; 
const float LIMIAR_ESCURO_LUX = 50.0;             
const long PUBLISH_STATUS_RATE_LIMIT = 2000;      

// --- Variáveis de Estado ---
enum IluminacaoMode { AUTOMATICO, MANUAL_LIGADO, MANUAL_DESLIGADO };
IluminacaoMode currentMode = AUTOMATICO;

CRGB leds[NUM_LEDS];
uint32_t corAtual = CRGB::FloralWhite; 
bool luzesEstaoAcesas = false;
unsigned long ultimoMovimentoDetectado = 0;
bool escuroDetectado = false;

// Variáveis para "publish on change"
bool ultimoStatusPublicado = false;
unsigned long ultimoPublishTime = 0;

// --- Instância dos Sensores ---
BH1750 lightSensor;

// --- Protótipos ---
void handleIluminacaoComando(AdafruitIO_Data *data);
void ligarLuzes();
void desligarLuzes();
void parseHexColor(const char* hex);
void publishStatusOnChange();

// --- Função setup() ---
void setup() {
  Serial.begin(115200);
  pinMode(PINO_PIR, INPUT);

  FastLED.addLeds<WS2812B, PINO_FITA_LED, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  desligarLuzes(); 

  Wire.begin();
  if (!lightSensor.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println(F("Erro ao encontrar o sensor BH1750! Verifique a fiação I2C."));
  }

  Serial.print("Conectando ao Adafruit IO...");
  io.connect();

  iluminacaoComandoSub->onMessage(handleIluminacaoComando);
  
  // *** CORREÇÃO APLICADA AQUI ***
  // Este loop agora chama io.run() para processar a conexão.
  while (io.status() < AIO_CONNECTED) {
    Serial.print(".");
    io.run(); // Permite que a biblioteca processe a conexão em segundo plano
    delay(500);
  }
  
  Serial.println();
  Serial.println(io.statusText());

  iluminacaoComandoSub->get(); 
  publishStatusOnChange(); 
}

// --- Função loop() ---
void loop() {
  io.run(); // Essencial para a comunicação e callbacks

  bool movimento = digitalRead(PINO_PIR) == HIGH;
  float lux = lightSensor.readLightLevel();
  escuroDetectado = (lux < LIMIAR_ESCURO_LUX);

  if (movimento) {
    ultimoMovimentoDetectado = millis();
  }

  switch (currentMode) {
    case AUTOMATICO:
      if ((millis() - ultimoMovimentoDetectado < TEMPO_LUZ_ACESA_APOS_MOVIMENTO) && escuroDetectado) {
        ligarLuzes();
      } else {
        desligarLuzes();
      }
      break;
    
    case MANUAL_LIGADO:
      ligarLuzes();
      break;

    case MANUAL_DESLIGADO:
      desligarLuzes();
      break;
  }

  publishStatusOnChange();
}

// --- Implementação das Funções de Callback ---
void handleIluminacaoComando(AdafruitIO_Data *data) {
  String comando = data->toString();
  Serial.print("CALLBACK Recebido: '");
  Serial.print(comando);
  Serial.println("'");

  if (comando.equalsIgnoreCase("LIGAR_MANUAL")) {
    currentMode = MANUAL_LIGADO;
  } else if (comando.equalsIgnoreCase("DESLIGAR_MANUAL")) {
    currentMode = MANUAL_DESLIGADO;
  } else if (comando.equalsIgnoreCase("AUTOMATICO")) {
    currentMode = AUTOMATICO;
  } else if (comando.startsWith("#")) {
    parseHexColor(comando.c_str());
  }
}

// --- Implementação das Funções Auxiliares ---
void ligarLuzes() {
  if (!luzesEstaoAcesas) {
    fill_solid(leds, NUM_LEDS, corAtual);
    FastLED.show();
    luzesEstaoAcesas = true;
  }
}

void desligarLuzes() {
  if (luzesEstaoAcesas) {
    FastLED.clear();
    FastLED.show();
    luzesEstaoAcesas = false;
  }
}

void parseHexColor(const char* hexstring) {
  long number = strtol(&hexstring[1], NULL, 16);
  corAtual = number;
  if (luzesEstaoAcesas && currentMode == MANUAL_LIGADO) {
    fill_solid(leds, NUM_LEDS, corAtual); 
    FastLED.show();
  }
}

void publishStatusOnChange() {
  unsigned long currentTime = millis();
  if (luzesEstaoAcesas != ultimoStatusPublicado && currentTime - ultimoPublishTime > PUBLISH_STATUS_RATE_LIMIT) {
    if (luzesEstaoAcesas) {
      iluminacaoStatusFeed->save("ACESA");
    } else {
      iluminacaoStatusFeed->save("APAGADA");
    }
    ultimoStatusPublicado = luzesEstaoAcesas;
    ultimoPublishTime = currentTime;
  }
}