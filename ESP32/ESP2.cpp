// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <AdafruitIO_WiFi.h>
#include <FastLED.h>

// --- Inclui o arquivo de segredos ---
#include "secrets.h" // Deve conter WIFI_SSID, WIFI_PASS, IO_USERNAME, IO_KEY

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Feeds do Adafruit IO (2 Feeds) ---
AdafruitIO_Feed *iluminacaoComandoSub = io.feed("iluminacao-comando");
AdafruitIO_Feed *iluminacaoStatusFeed = io.feed("iluminacao-status");

// --- Pinos e Configurações ---
const int PINO_PIR      = 15; // Pino para o sensor de presença (D15)
const int PINO_FITA_LED = 2;  // Pino de dados da fita de LED WS2812B (D2)
const int NUM_LEDS      = 30; // Número de LEDs na sua fita
const int BRIGHTNESS    = 150;// Brilho da fita (0-255)

// --- Constantes de Lógica ---
// ===== ALTERAÇÃO AQUI =====
const long TEMPO_LUZ_ACESA_APOS_MOVIMENTO = 5000; // 5 segundos em milissegundos
const long PUBLISH_STATUS_RATE_LIMIT    = 2000;  // Publica o status no máximo a cada 2 segundos

// --- Variáveis de Estado ---
enum IluminacaoMode { AUTOMATICO, MANUAL_LIGADO, MANUAL_DESLIGADO };
IluminacaoMode currentMode = AUTOMATICO;

CRGB leds[NUM_LEDS];
uint32_t corAtual = CRGB::FloralWhite; // Cor padrão inicial
bool luzesEstaoAcesas = false;
unsigned long ultimoMovimentoDetectado = 0;

// Variáveis para "publish on change"
bool ultimoStatusPublicado = false;
unsigned long ultimoPublishTime = 0;

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
  FastLED.setBrightness(BRIGHTNESS);
  desligarLuzes(); // Garante que começa desligada

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
  publishStatusOnChange();     // Publica o estado inicial
}

// --- Função loop() ---
void loop() {
  io.run(); // Essencial para a comunicação e callbacks

  // Leitura do sensor de movimento
  bool movimento = digitalRead(PINO_PIR) == HIGH;

  // Se houver movimento, reinicia o temporizador
  if (movimento) {
    ultimoMovimentoDetectado = millis();
  }

  // --- Máquina de Estados da Iluminação ---
  switch (currentMode) {
    case AUTOMATICO:
      // Liga a luz se o tempo desde o ÚLTIMO movimento for menor que o limite
      if (millis() - ultimoMovimentoDetectado < TEMPO_LUZ_ACESA_APOS_MOVIMENTO) {
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
    // Força o temporizador a um estado "expirado" para apagar a luz ao entrar no modo
    ultimoMovimentoDetectado = millis() - TEMPO_LUZ_ACESA_APOS_MOVIMENTO - 1;
    desligarLuzes();
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
  if (luzesEstaoAcesas && (currentMode == MANUAL_LIGADO || currentMode == AUTOMATICO)) {
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
