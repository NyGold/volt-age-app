// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>
#include <pgmspace.h>

// --- Inclui o arquivo de segredos ---
#include "secrets.h"

// --- Pinos dos Sensores e Atuadores ---
const int PINO_SENSOR_GAS_AO     = 32;
const int PINO_SENSOR_CHAMA_DO   = 33;
const int PINO_SENSOR_PIR        = 27;
const int PINO_VALVULA_SOLENOIDE = 26;
const int PINO_BUZZER            = 25;
const int PINO_FAROL_VERMELHO    = 13;
const int PINO_FAROL_AMARELO     = 12;
const int PINO_FAROL_VERDE       = 14;

// --- Configuração do Buzzer para ESP32 (LEDC) ---
byte ledcChannelBuzzer; // Variável para armazenar o canal do buzzer (para Core v3.x.x)

// --- Definição das Notas Musicais ---
#define NOTE_C4 262
#define NOTE_G3 196
#define NOTE_E4 330

// --- Melodia de Alerta (armazenada na memória Flash para economizar RAM) ---
const int melody[] PROGMEM = {
  NOTE_E4, 8, NOTE_E4, 8, 0, 8, NOTE_E4, 8, 0, 8, NOTE_C4, 8, NOTE_E4, 8, 0, 8, NOTE_G3, 8, 0, 8, 0, 4,
  NOTE_G3, 8, 0, 8
};
int tempoBase = 60000 / 120;
const int NUM_MELODY = sizeof(melody) / sizeof(melody[0]);

// --- Instâncias de Cliente e MQTT ---
WiFiClientSecure client;
Adafruit_MQTT_Client mqtt(&client, IO_SERVER, IO_SERVERPORT, IO_USERNAME, IO_KEY);

// --- Feeds do Adafruit IO (Caminho Padrão, SEM GRUPOS) ---
Adafruit_MQTT_Publish gasConcentracaoFeed = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/gas-concentracao");
Adafruit_MQTT_Publish gasAlertaFeed       = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/gas-alerta");
Adafruit_MQTT_Publish valvulaGasEstadoFeed= Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/valvula-gas-estado");
Adafruit_MQTT_Publish fogoEstadoFeed      = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/fogo-estado");
Adafruit_MQTT_Publish presencaCozinhaFeed = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/presenca-cozinha");

Adafruit_MQTT_Subscribe valvulaGasControleSub = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/valvula-gas-controle");
Adafruit_MQTT_Subscribe fogoTimerResetSub     = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/fogo-timer-reset");
Adafruit_MQTT_Subscribe fogoTimerAppSub       = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/fogo-timer-app");

// --- Constantes de Controle e Timers ---
const int  LIMIAR_GAS_ALERTA = 1500;
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000;
const long SENSOR_READ_INTERVAL = 500;
const long PUBLISH_INTERVAL     = 16000; // Intervalo de 20s para respeitar limites
const long BLINK_INTERVAL       = 250;

// --- Variáveis de Estado do Sistema e Timers ---
int  valorGasAtual = 0;
bool chamaDetectada = false;
bool presencaDetectada = false;
bool valvulaGasAberta = false;
unsigned long timerFogoSemPresenca = 0;
bool timerFogoSemPresencaAtivo = false;
bool fogoTimerAppAtivo = false;
unsigned long lastSensorReadTime = 0;
unsigned long lastPublishTime = 0;

enum SystemState { NORMAL, ALARME_VAZAMENTO_GAS, ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO, ALERTA_APLICATIVO };
SystemState currentState = NORMAL;

// --- Protótipos de Funções ---
void MQTT_connect();
void readSensors();
void controlValvulaSolenoide(bool abrir);
void updateSystemState();
void tocarMelodiaAlerta();
void pararMelodiaAlerta();
void handleMQTTMessages();
void publishData();
void updateVisualsAndAlarms();

// --- Função setup() ---
void setup() {
  Serial.begin(115200);
  delay(10);
  Serial.println("\n===================================");
  Serial.println("  Módulo Fogão/Gás - ESP32 #1      ");
  Serial.println("  (Biochallenge 25 - Volt Age)     ");
  Serial.println("===================================");

  pinMode(PINO_SENSOR_GAS_AO, INPUT);
  pinMode(PINO_SENSOR_CHAMA_DO, INPUT);
  pinMode(PINO_SENSOR_PIR, INPUT);
  pinMode(PINO_VALVULA_SOLENOIDE, OUTPUT);
  pinMode(PINO_BUZZER, OUTPUT);
  pinMode(PINO_FAROL_VERMELHO, OUTPUT);
  pinMode(PINO_FAROL_AMARELO, OUTPUT);
  pinMode(PINO_FAROL_VERDE, OUTPUT);

  digitalWrite(PINO_VALVULA_SOLENOIDE, LOW);
  valvulaGasAberta = false;
  digitalWrite(PINO_FAROL_VERMELHO, LOW);
  digitalWrite(PINO_FAROL_AMARELO, LOW);
  digitalWrite(PINO_FAROL_VERDE, HIGH);

  // API do buzzer para ESP32 Core v3.x.x
  ledcChannelBuzzer = ledcAttach(PINO_BUZZER, 0, 10);
  pararMelodiaAlerta();
  
  // Solução para o problema de conexão SSL/TLS
  client.setInsecure();

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

  mqtt.subscribe(&valvulaGasControleSub);
  mqtt.subscribe(&fogoTimerResetSub);
  mqtt.subscribe(&fogoTimerAppSub);
}

// --- Função loop() ---
void loop() {
  MQTT_connect();
  handleMQTTMessages();
  if (millis() - lastSensorReadTime >= SENSOR_READ_INTERVAL) {
    readSensors();
    updateSystemState();
    lastSensorReadTime = millis();
  }
  updateVisualsAndAlarms();
  if (millis() - lastPublishTime >= PUBLISH_INTERVAL) {
    publishData();
    lastPublishTime = millis();
  }
  mqtt.ping();
}

// --- Implementação das Funções Auxiliares ---
void MQTT_connect() {
  if (mqtt.connected()) return;
  Serial.print("Conectando ao MQTT... ");
  uint8_t retries = 3;
  while (mqtt.connect() != 0) {
    Serial.println(mqtt.connectErrorString(mqtt.connect()));
    Serial.println("Tentando novamente em 5 segundos...");
    mqtt.disconnect();
    delay(5000);
    retries--;
    if (retries == 0) {
      Serial.println("Falha na conexão MQTT. Reiniciando ESP32...");
      ESP.restart();
    }
  }
  Serial.println("MQTT Conectado!");
}

void readSensors() {
  valorGasAtual = analogRead(PINO_SENSOR_GAS_AO);
  chamaDetectada = (digitalRead(PINO_SENSOR_CHAMA_DO) == LOW);
  presencaDetectada = (digitalRead(PINO_SENSOR_PIR) == HIGH);
  Serial.print("Gás: "); Serial.print(valorGasAtual);
  Serial.print(" | Chama: "); Serial.print(chamaDetectada ? "SIM" : "NAO");
  Serial.print(" | Presença: "); Serial.print(presencaDetectada ? "SIM" : "NAO");
  Serial.println();
}

void controlValvulaSolenoide(bool abrir) {
  if (abrir && !valvulaGasAberta) {
    digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH);
    valvulaGasAberta = true;
    Serial.println("Válvula de gás ABERTA.");
  } else if (!abrir && valvulaGasAberta) {
    digitalWrite(PINO_VALVULA_SOLENOIDE, LOW);
    valvulaGasAberta = false;
    Serial.println("Válvula de gás FECHADA.");
  }
}

void updateSystemState() {
  if (valorGasAtual > LIMIAR_GAS_ALERTA) {
    currentState = ALARME_VAZAMENTO_GAS;
    controlValvulaSolenoide(false);
    return;
  }
  if (chamaDetectada && !presencaDetectada && !fogoTimerAppAtivo) {
    if (!timerFogoSemPresencaAtivo) {
      timerFogoSemPresenca = millis();
      timerFogoSemPresencaAtivo = true;
    } else if (millis() - timerFogoSemPresenca >= TEMPO_MAX_FOGO_SEM_PRESENCA) {
      currentState = ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO;
      controlValvulaSolenoide(false);
      return;
    }
  } else {
    if (timerFogoSemPresencaAtivo) {
      timerFogoSemPresencaAtivo = false;
    }
  }
  if (currentState == ALERTA_APLICATIVO) { return; }
  currentState = NORMAL;
  if (currentState != ALERTA_APLICATIVO) {
    controlValvulaSolenoide(true);
  }
}

void updateVisualsAndAlarms() {
    static unsigned long lastBlinkTime = 0;
    static bool ledState = false;
    switch (currentState) {
        case NORMAL:
            digitalWrite(PINO_FAROL_VERMELHO, LOW);
            digitalWrite(PINO_FAROL_AMARELO, fogoTimerAppAtivo ? HIGH : LOW);
            digitalWrite(PINO_FAROL_VERDE, fogoTimerAppAtivo ? LOW : HIGH);
            pararMelodiaAlerta();
            break;
        case ALARME_VAZAMENTO_GAS:
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
            digitalWrite(PINO_FAROL_VERDE, LOW);
            digitalWrite(PINO_FAROL_AMARELO, LOW);
            tocarMelodiaAlerta();
            if (millis() - lastBlinkTime >= BLINK_INTERVAL) {
                ledState = !ledState;
                digitalWrite(PINO_FAROL_VERMELHO, ledState);
                lastBlinkTime = millis();
            }
            break;
        case ALERTA_APLICATIVO:
            digitalWrite(PINO_FAROL_VERMELHO, LOW);
            digitalWrite(PINO_FAROL_AMARELO, HIGH);
            digitalWrite(PINO_FAROL_VERDE, LOW);
            pararMelodiaAlerta();
            break;
    }
}

void tocarMelodiaAlerta() {
  static unsigned long lastNoteTime = 0;
  static int currentNoteIndex = 0;
  int noteDuration = tempoBase / abs(pgm_read_word_near(melody + currentNoteIndex + 1));
  if (millis() - lastNoteTime >= noteDuration) {
    int nota = pgm_read_word_near(melody + currentNoteIndex);
    if (nota > 0) {
      ledcWriteTone(ledcChannelBuzzer, nota);
    } else {
      pararMelodiaAlerta();
    }
    currentNoteIndex += 2;
    if (currentNoteIndex >= NUM_MELODY) {
      currentNoteIndex = 0;
    }
    lastNoteTime = millis();
  }
}

void pararMelodiaAlerta() {
  ledcWriteTone(ledcChannelBuzzer, 0);
}

void handleMQTTMessages() {
  Adafruit_MQTT_Subscribe *subscription;
  if ((subscription = mqtt.readSubscription(500))) {
    if (subscription == &valvulaGasControleSub) {
      if (strcmp((char *)subscription->lastread, "FECHAR_AGORA") == 0) {
        controlValvulaSolenoide(false);
        currentState = ALERTA_APLICATIVO;
      } else if (strcmp((char *)subscription->lastread, "ABRIR_AGORA") == 0) {
        if (valorGasAtual <= LIMIAR_GAS_ALERTA && currentState != ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
          controlValvulaSolenoide(true);
          currentState = NORMAL;
        } else {
          Serial.println("AVISO: Abertura negada devido a alarme ativo.");
        }
      }
    } else if (subscription == &fogoTimerResetSub) {
      if (strcmp((char *)subscription->lastread, "RESET_TIMER") == 0) {
          timerFogoSemPresenca = millis();
          Serial.println("Timer de Fogo sem Presença RESETADO pelo app.");
      }
    } else if (subscription == &fogoTimerAppSub) {
      if (strcmp((char *)subscription->lastread, "ATIVAR_TIMER") == 0) {
        fogoTimerAppAtivo = true;
        timerFogoSemPresencaAtivo = false;
        Serial.println("Timer de Fogo do App ATIVADO.");
      } else if (strcmp((char *)subscription->lastread, "DESATIVAR_TIMER") == 0) {
        fogoTimerAppAtivo = false;
        Serial.println("Timer de Fogo do App DESATIVADO.");
      }
    }
  }
}

void publishData() {
  gasConcentracaoFeed.publish((int32_t)valorGasAtual); 
  valvulaGasEstadoFeed.publish(valvulaGasAberta ? "ABERTA" : "FECHADA");
  fogoEstadoFeed.publish(chamaDetectada ? "DETECTADO" : "NAO_DETECTADO");
  presencaCozinhaFeed.publish(presencaDetectada ? "PRESENCA" : "AUSENCIA");
  switch (currentState) {
    case ALARME_VAZAMENTO_GAS:
      gasAlertaFeed.publish("ALARME_GAS");
      break;
    case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
      gasAlertaFeed.publish("FOGO_SEM_PRESENCA");
      break;
    default:
      if (fogoTimerAppAtivo) {
        gasAlertaFeed.publish("FOGO_TIMER_ATIVO");
      } else if (timerFogoSemPresencaAtivo) {
        gasAlertaFeed.publish("FOGO_SEM_PRESENCA_CONTANDO");
      } else {
        gasAlertaFeed.publish("OK");
      }
      break;
  }
  Serial.println("Dados publicados no Adafruit IO.");
}