// --- Bibliotecas Necessárias ---
#include <WiFi.h>          // Para comunicação Wi-Fi do ESP32
#include <Adafruit_MQTT.h> // Para MQTT
#include <Adafruit_MQTT_Client.h> // Para o cliente MQTT da Adafruit

// --- Configurações de Wi-Fi ---
#define WIFI_SSID       "CAL SILVA"       // SEU NOME DA REDE WI-FI
#define WIFI_PASSWORD   "18CALS46"        // SUA SENHA DA REDE WI-FI

// --- Configurações do Adafruit IO ---
#define IO_SERVER       "io.adafruit.com"
#define IO_SERVERPORT   1883 // Porta padrão para MQTT
#define IO_USERNAME     "VoltAge_Silva"   // SEU IO USERNAME
#define IO_KEY          "aio_kHpr09XaRzyeBw1HFhM1OREhKJvm" // SUA IO KEY

// --- Definição do Pino do Sensor PIR ---
const int PINO_SENSOR_PIR = 27; // Conecte o pino 'OUT' do sensor PIR ao GPIO27 do ESP32

// --- CORREÇÃO AQUI: Declaração da instância WiFiClient e do Adafruit_MQTT_Client ANTES do Feed ---
WiFiClient client; // Declara uma instância de WiFiClient
Adafruit_MQTT_Client mqtt(&client, IO_SERVER, IO_SERVERPORT, IO_USERNAME, IO_KEY);

// --- Feed do Adafruit IO (AGORA 'mqtt' JÁ ESTÁ DECLARADO) ---
Adafruit_MQTT_Publish movimentoFeed = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/movimento-pir");


// Variáveis de estado
int lastPirState = LOW; // Armazena o último estado do sensor PIR
unsigned long lastPublishTime = 0; // Para controlar o tempo entre publicações
const long PUBLISH_INTERVAL = 5000; // Publica a cada 5 segundos se houver mudança

void setup() {
  Serial.begin(115200);
  delay(10); // Pequeno atraso para a serial iniciar
  Serial.println("===================================");
  Serial.println("  Detector PIR com Adafruit IO MQTT");
  Serial.println("===================================");

  // Configura o pino do sensor PIR como ENTRADA
  pinMode(PINO_SENSOR_PIR, INPUT);

  // Conecta-se ao Wi-Fi
  Serial.print("Conectando ao WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Conectado!");
  Serial.print("Endereço IP: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Garante que a conexão MQTT esteja ativa
  MQTT_connect();

  // Lê o estado atual do sensor PIR
  int currentPirState = digitalRead(PINO_SENSOR_PIR);

  // Publica "DETECTADO" ou "NÃO DETECTADO"
  if (currentPirState != lastPirState) { // Se o estado mudou
    if (currentPirState == HIGH) {
      Serial.println("Movimento Detectado! Publicando...");
      movimentoFeed.publish("DETECTADO"); // Publica "DETECTADO" no feed
    } else {
      Serial.println("Movimento Cessou. Publicando...");
      movimentoFeed.publish("NÃO DETECTADO"); // Publica "NÃO DETECTADO" no feed
    }
    lastPirState = currentPirState; // Atualiza o último estado
  }

  // Mantenha o loop rodando para o cliente MQTT processar mensagens
  mqtt.ping(); 
  delay(100); // Pequeno atraso para não lotar a CPU e permitir outras operações
}

// Função para reconectar ao MQTT se a conexão cair
void MQTT_connect() {
  int8_t ret;

  // Se já conectado, retorna
  if (mqtt.connected()) {
    return;
  }

  Serial.print("Conectando ao MQTT... ");

  uint8_t retries = 3;
  while ((ret = mqtt.connect()) != 0) { // Tenta conectar
    Serial.println(mqtt.connectErrorString(ret));
    Serial.println("Tentando novamente em 5 segundos...");
    mqtt.disconnect();
    delay(5000); // Espera 5 segundos antes de tentar novamente
    retries--;
    if (retries == 0) {
      // Falha total, reinicia o ESP32 (pode ser problema de Wi-Fi ou credenciais)
      Serial.println("Falha na conexão MQTT após várias tentativas. Reiniciando ESP32...");
      ESP.restart();
    }
  }
  Serial.println("MQTT Conectado!");
}