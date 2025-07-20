// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <AdafruitIO_WiFi.h>
#include <FastLED.h>
#include <Wire.h>
#include <Adafruit_BH1750.h>

// --- Inclui o arquivo de segredos ---
#include "secrets.h" // Deve conter WIFI_SSID, WIFI_PASS, IO_USERNAME, IO_KEY

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Feeds do Adafruit IO (2 Feeds) ---
AdafruitIO_Feed *iluminacaoComandoSub = io.feed("iluminacao-comando");
AdafruitIO_Feed *iluminacaoStatusFeed = io.feed("iluminacao-status");

// --- Pinos e Configurações ---
const int PINO_PIR      = 15; // Pino para o sensor de presença
const int PINO_FITA_LED = 2;  // Pino de dados da fita de LED WS2812B
const int NUM_LEDS      = 30; // Número de LEDs na sua fita

// --- Constantes de Lógica ---
const long TEMPO_LUZ_ACESA_APOS_MOVIMENTO = 30000; // 30 segundos em milissegundos
const float LIMIAR_ESCURO_LUX = 50.0;             // Abaixo deste valor em Lux, é considerado "escuro"
const long PUBLISH_STATUS_RATE_LIMIT = 2000;      // Publica o status no máximo a cada 2 segundos

// --- Variáveis de Estado ---
enum IluminacaoMode { AUTOMATICO, MANUAL_LIGADO, MANUAL_DESLIGADO };
IluminacaoMode currentMode = AUTOMATICO;

CRGB leds[NUM_LEDS];
uint32_t corAtual = CRGB::FloralWhite; // Cor padrão
bool luzesEstaoAcesas = false;
unsigned long ultimoMovimentoDetectado = 0;
bool escuroDetectado = false;

// Variáveis para "publish on change"
bool ultimoStatusPublicado = false;
unsigned long ultimoPublishTime = 0;

// --- Instância dos Sensores ---
Adafruit_BH1750 lightSensor;

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

  // Inicializa a fita de LED
  FastLED.addLeds<WS2812B, PINO_FITA_LED, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(150);
  desligarLuzes(); // Garante que começa desligada

  // Inicializa o sensor de luz BH1750
  if (!lightSensor.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println(F("Erro ao encontrar o sensor BH1750! Verifique a fiação I2C."));
  }

  Serial.print("Conectando ao Adafruit IO...");
  io.connect();

  iluminacaoComandoSub->onMessage(handleIluminacaoComando);
  
  while (io.status() < AIO_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.println(io.statusText());

  iluminacaoComandoSub->get(); // Busca o último comando ao iniciar
  publishStatusOnChange(); // Publica o estado inicial
}

// --- Função loop() ---
void loop() {
  io.run(); // Essencial para a comunicação e callbacks

  // Leitura dos sensores
  bool movimento = digitalRead(PINO_PIR) == HIGH;
  float lux = lightSensor.readLightLevel();
  escuroDetectado = (lux < LIMIAR_ESCURO_LUX);

  if (movimento) {
    ultimoMovimentoDetectado = millis();
  }

  // --- Máquina de Estados da Iluminação ---
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

  if (comando == "LIGAR_MANUAL") {
    currentMode = MANUAL_LIGADO;
  } else if (comando == "DESLIGAR_MANUAL") {
    currentMode = MANUAL_DESLIGADO;
  } else if (comando == "AUTOMATICO") {
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
  // Converte a string hexadecimal (ex: "#FF0000") para um número de 32 bits
  long number = strtol(&hexstring[1], NULL, 16);
  corAtual = number;
  // Se as luzes já estiverem acesas no modo manual, atualiza a cor imediatamente
  if (luzesEstaoAcesas && currentMode == MANUAL_LIGADO) {
    ligarLuzes();
  }
}

void publishStatusOnChange() {
  unsigned long currentTime = millis();
  // Publica o status da luz apenas se ele mudou E passou o tempo de rate limit
  if (luzesEstaoAcesas != ultimoStatusPublicado && currentTime - ultimoPublishTime > PUBLISH_STATUS_RATE_LIMIT) {
    Serial.print("Publicando novo status da luz: ");
    if (luzesEstaoAcesas) {
      Serial.println("ACESA");
      iluminacaoStatusFeed->save("ACESA");
    } else {
      Serial.println("APAGADA");
      iluminacaoStatusFeed->save("APAGADA");
    }
    ultimoStatusPublicado = luzesEstaoAcesas;
    ultimoPublishTime = currentTime;
  }
}