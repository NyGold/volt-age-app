// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <AdafruitIO_WiFi.h>
#include <FastLED.h>
#include <Wire.h>          // Biblioteca para comunicação I2C
#include <BH1750.h>        // Biblioteca para o sensor de luminosidade

// --- Inclui o arquivo de segredos ---
#include "secrets.h" // Deve conter WIFI_SSID, WIFI_PASS, IO_USERNAME, IO_KEY

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Feeds do Adafruit IO (Conforme especificação do projeto: 2 Feeds) ---
AdafruitIO_Feed *iluminacaoComandoSub = io.feed("iluminacao-comando"); // Feed de comando (Nuvem -> ESP32)
AdafruitIO_Feed *iluminacaoStatusFeed = io.feed("iluminacao-status");  // Feed de status (ESP32 -> Nuvem)

// --- Definição de strings estáticas para publicação (SOLUÇÃO DO ESP32#1) ---
static char ILUMINACAO_ACESA[] = "ACESA";
static char ILUMINACAO_APAGADA[] = "APAGADA";

// --- Pinos e Configurações ---
const int PINO_PIR      = 15; // Pino para o sensor de presença (D15)
const int PINO_FITA_LED = 2;  // Pino de dados da fita de LED WS2812B (D2)
const int NUM_LEDS      = 30; // Número de LEDs na sua fita
const int BRIGHTNESS    = 150; // Brilho da fita (0-255)

// Pinos I2C para o sensor BH1750
const int PINO_SDA = 21;  // Pino para comunicação SDA (Serial Data)
const int PINO_SCL = 22;  // Pino para comunicação SCL (Serial Clock)

// Configurações do BH1750
const float LIMIAR_ESCURO = 50.0; // Limiar de luminosidade em lux para considerar "escuro"
const long LEITURA_LUMINOSIDADE_INTERVALO = 2000; // Intervalo de leitura do sensor (2 segundos)

// --- Constantes de Lógica ---
const long TEMPO_LUZ_ACESA_APOS_MOVIMENTO = 5000; // 5 segundos em milissegundos
const long PUBLISH_STATUS_RATE_LIMIT    = 2000;  // Publica o status no máximo a cada 2 segundos
const long INTERVALO_RECONEXAO_MQTT = 10000; // Tenta reconectar a cada 10 segundos se desconectado

// --- Variáveis de Estado ---
enum IluminacaoMode { AUTOMATICO, MANUAL_LIGADO, MANUAL_DESLIGADO };
IluminacaoMode currentMode = AUTOMATICO;

CRGB leds[NUM_LEDS];
uint32_t corAtual = CRGB::White; // Cor padrão inicial
bool luzesEstaoAcesas = false;
unsigned long ultimoMovimentoDetectado = 0;
float luminosidadeAtual = 0.0;
unsigned long ultimoTempoLeituraLuminosidade = 0;
unsigned long ultimoTempoTentativaReconexao = 0;

// Variáveis para "publish on change"
bool ultimoStatusPublicado = false;
unsigned long ultimoPublishTime = 0;

// --- Instância do sensor BH1750 ---
BH1750 luzSensor;

// --- Protótipos ---
void handleIluminacaoComando(AdafruitIO_Data *data);
void ligarLuzes();
void desligarLuzes();
void parseHexColor(const char* hex);
void publishStatusOnChange();
void lerLuminosidade();
void verificarConexaoMQTT();

// --- Função setup() ---
void setup() {
  Serial.begin(115200);
  pinMode(PINO_PIR, INPUT);

  // Inicializa a comunicação I2C para o BH1750
  Wire.begin(PINO_SDA, PINO_SCL);
  
  // Inicializa o sensor BH1750
  if (!luzSensor.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println("Erro ao inicializar o sensor BH1750!");
    while (1); // Para a execução se não encontrar o sensor
  }
  Serial.println("Sensor BH1750 inicializado com sucesso");
  
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
  
  // Publica o estado inicial explicitamente
  iluminacaoStatusFeed->save(luzesEstaoAcesas ? ILUMINACAO_ACESA : ILUMINACAO_APAGADA);
  ultimoStatusPublicado = luzesEstaoAcesas;
  ultimoPublishTime = millis();
  Serial.println("Estado inicial publicado no feed iluminacao-status");
}

// --- Função loop() ---
void loop() {
  // Verifica e reconecta ao MQTT se necessário
  verificarConexaoMQTT();
  
  // Mantém a comunicação com o Adafruit IO
  io.run(); // Essencial para a comunicação e callbacks

  // Leitura do sensor de movimento
  bool movimento = digitalRead(PINO_PIR) == HIGH;

  // Se houver movimento, reinicia o temporizador
  if (movimento) {
    ultimoMovimentoDetectado = millis();
  }

  // Leitura periódica do sensor BH1750
  if (millis() - ultimoTempoLeituraLuminosidade > LEITURA_LUMINOSIDADE_INTERVALO) {
    lerLuminosidade();
    ultimoTempoLeituraLuminosidade = millis();
  }

  // --- Máquina de Estados da Iluminação ---
  switch (currentMode) {
    case AUTOMATICO:
      // Liga a luz se houver movimento, o tempo desde o último movimento for menor que o limite 
      // E a luminosidade estiver abaixo do limiar (ambiente escuro)
      if (millis() - ultimoMovimentoDetectado < TEMPO_LUZ_ACESA_APOS_MOVIMENTO && 
          luminosidadeAtual < LIMIAR_ESCURO) {
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

// --- Função para verificar e reconectar ao MQTT ---
void verificarConexaoMQTT() {
  // Verifica o status da conexão a cada INTERVALO_RECONEXAO_MQTT
  if (millis() - ultimoTempoTentativaReconexao > INTERVALO_RECONEXAO_MQTT) {
    // Usando io.status() para verificar conexão
    // AIO_DISCONNECTED = 0, AIO_IDLE = 1, AIO_CONNECTED = 2
    if (io.status() != AIO_CONNECTED) {
      Serial.println("Conexão MQTT perdida. Tentando reconectar...");
      
      // Atualiza o tempo da última tentativa
      ultimoTempoTentativaReconexao = millis();
      
      // Tenta reconectar
      io.connect();    // Tenta reconectar
      
      // Verifica se reconectou com sucesso
      if (io.status() == AIO_CONNECTED) {
        Serial.println("Reconectado com sucesso ao Adafruit IO!");
        // Reconecta aos feeds
        iluminacaoComandoSub->onMessage(handleIluminacaoComando);
        iluminacaoComandoSub->get(); // Atualiza com o último comando
      } else {
        Serial.print("Falha na reconexão ao Adafruit IO. Status: ");
        Serial.println(io.statusText());
      }
    }
  }
}

// --- Implementação das Funções de Callback ---
void handleIluminacaoComando(AdafruitIO_Data *data) {
  String comando = data->toString();
  Serial.print("CALLBACK Recebido: '");
  Serial.print(comando);
  Serial.println("'");

  if (comando.equalsIgnoreCase("LIGAR_MANUAL")) {
    currentMode = MANUAL_LIGADO;
    Serial.println("Modo MANUAL_LIGADO ativado");
  } else if (comando.equalsIgnoreCase("DESLIGAR_MANUAL")) {
    currentMode = MANUAL_DESLIGADO;
    Serial.println("Modo MANUAL_DESLIGADO ativado");
  } else if (comando.equalsIgnoreCase("AUTOMATICO")) {
    currentMode = AUTOMATICO;
    // Força o temporizador a um estado "expirado" para apagar a luz ao entrar no modo
    ultimoMovimentoDetectado = millis() - TEMPO_LUZ_ACESA_APOS_MOVIMENTO - 1;
    desligarLuzes();
    Serial.println("Modo AUTOMATICO ativado");
  } else if (comando.startsWith("#")) {
    parseHexColor(comando.c_str());
    Serial.print("Cor alterada para: ");
    Serial.println(comando);
  } else {
    Serial.print("Comando desconhecido recebido: ");
    Serial.println(comando);
  }
}

// --- Implementação das Funções Auxiliares ---
void ligarLuzes() {
  if (!luzesEstaoAcesas) {
    fill_solid(leds, NUM_LEDS, corAtual);
    FastLED.show();
    luzesEstaoAcesas = true;
    Serial.println("Luzes ligadas");
  }
}

void desligarLuzes() {
  if (luzesEstaoAcesas) {
    FastLED.clear();
    FastLED.show();
    luzesEstaoAcesas = false;
    Serial.println("Luzes desligadas");
  }
}

void parseHexColor(const char* hexstring) {
  // Remove o '#' se presente
  const char* hex = hexstring;
  if (hex[0] == '#') {
    hex++;
  }
  
  // Converte a string hexadecimal para um número inteiro
  long number = (long)strtol(hex, NULL, 16);
  
  // Define a cor atual
  corAtual = number;
  
  // Atualiza as luzes se estiverem acesas
  if (luzesEstaoAcesas && (currentMode == MANUAL_LIGADO || currentMode == AUTOMATICO)) {
    fill_solid(leds, NUM_LEDS, corAtual);
    FastLED.show();
  }
}

void publishStatusOnChange() {
  unsigned long currentTime = millis();
  
  // Verifica se o status mudou e se está dentro do rate limit
  if (luzesEstaoAcesas != ultimoStatusPublicado && currentTime - ultimoPublishTime > PUBLISH_STATUS_RATE_LIMIT) {
    // Publica o novo status usando as strings estáticas
    iluminacaoStatusFeed->save(luzesEstaoAcesas ? ILUMINACAO_ACESA : ILUMINACAO_APAGADA);
    
    ultimoStatusPublicado = luzesEstaoAcesas;
    ultimoPublishTime = currentTime;
    Serial.print("Publicado status: ");
    Serial.println(luzesEstaoAcesas ? "ACESA" : "APAGADA");
  }
}

// --- Função para ler luminosidade do BH1750 ---
void lerLuminosidade() {
  float nivelLuz = luzSensor.readLightLevel();
  
  // Verifica se a leitura é válida
  if (nivelLuz >= 0) {
    luminosidadeAtual = nivelLuz;
    
    Serial.print("Luminosidade atual: ");
    Serial.print(luminosidadeAtual);
    Serial.println(" lux");
  } else {
    Serial.println("Erro ao ler luminosidade do sensor BH1750");
  }
}