// --- Bibliotecas Necessárias ---
#include <WiFi.h>                 // Para comunicação Wi-Fi do ESP32
#include <Adafruit_MQTT.h>        // Para MQTT
#include <Adafruit_MQTT_Client.h> // Para o cliente MQTT da Adafruit
#include <pgmspace.h>             // Para usar a memória Flash (PROGMEM)

// --- Inclui o arquivo de segredos ---
#include "secrets.h"

// --- Pinos dos Sensores e Atuadores ---
const int PINO_SENSOR_GAS_AO     = 32; // Sensor MQ-5, Saída Analógica (AO)
const int PINO_SENSOR_CHAMA_DO   = 33; // Sensor de Chama, Saída Digital (DO)
const int PINO_SENSOR_PIR        = 27; // Sensor PIR, Saída Digital (OUT)
const int PINO_VALVULA_SOLENOIDE = 26; // Válvula Solenoide (Normalmente Fechada)
const int PINO_BUZZER            = 25; // Buzzer Passivo
const int PINO_FAROL_VERMELHO    = 13; // Módulo Semáforo - LED Vermelho
const int PINO_FAROL_AMARELO     = 12; // Módulo Semáforo - LED Amarelo
const int PINO_FAROL_VERDE       = 14; // Módulo Semáforo - LED Verde

// --- Configuração do Buzzer para ESP32 (LEDC) ---
#define LEDC_CHANNEL_BUZZER 0
#define LEDC_RESOLUTION 10

// --- Definição das Notas Musicais (para o Buzzer) ---
#define NOTE_C4 262
#define NOTE_G3 196
#define NOTE_E4 330
// ... (outras notas podem ser adicionadas aqui se necessário)

// --- Melodia de Alerta (armazenada na memória Flash para economizar RAM) ---
const int melody[] PROGMEM = {
  NOTE_E4, 8, NOTE_E4, 8, 0, 8, NOTE_E4, 8, 0, 8, NOTE_C4, 8, NOTE_E4, 8, 0, 8, NOTE_G3, 8, 0, 8, 0, 4,
  NOTE_G3, 8, 0, 8
};
int tempoBase = 60000 / 120; // BPM = 120 (ajustável)
const int NUM_MELODY = sizeof(melody) / sizeof(melody[0]);


// --- Instâncias de Cliente e MQTT ---
WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, IO_SERVER, IO_SERVERPORT, IO_USERNAME, IO_KEY);

// --- Feeds do Adafruit IO (Publicação) ---
Adafruit_MQTT_Publish gasConcentracaoFeed = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/gas-concentracao");
Adafruit_MQTT_Publish gasAlertaFeed       = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/gas-alerta");
Adafruit_MQTT_Publish valvulaGasEstadoFeed= Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/valvula-gas-estado");
Adafruit_MQTT_Publish fogoEstadoFeed      = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/fogo-estado");
Adafruit_MQTT_Publish presencaCozinhaFeed = Adafruit_MQTT_Publish(&mqtt, IO_USERNAME "/feeds/presenca-cozinha");

// --- Feeds do Adafruit IO (Assinatura - Receber Comandos do App) ---
Adafruit_MQTT_Subscribe valvulaGasControleSub = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/valvula-gas-controle");
Adafruit_MQTT_Subscribe fogoTimerResetSub     = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/fogo-timer-reset");
Adafruit_MQTT_Subscribe fogoTimerAppSub       = Adafruit_MQTT_Subscribe(&mqtt, IO_USERNAME "/feeds/fogo-timer-app");


// --- Constantes de Controle e Timers ---
const int  LIMIAR_GAS_ALERTA = 1500; // Ajuste este valor MQ-5 após calibração real!
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000; // 5 minutos em ms
const long SENSOR_READ_INTERVAL = 500;   // Leitura de sensores a cada 500ms
const long PUBLISH_INTERVAL     = 5000;  // Publica dados a cada 5 segundos
const long BLINK_INTERVAL       = 250;   // Intervalo para piscar o LED de alarme (250ms)

// --- Variáveis de Estado do Sistema e Timers ---
int  valorGasAtual = 0;
bool chamaDetectada = false;
bool presencaDetectada = false;
bool alarmeGasAtivo = false;
bool valvulaGasAberta = false;
unsigned long timerFogoSemPresenca = 0;
bool timerFogoSemPresencaAtivo = false;
bool fogoTimerAppAtivo = false;
unsigned long lastSensorReadTime = 0;
unsigned long lastPublishTime = 0;

// Estados do Sistema (para controle geral)
enum SystemState {
  NORMAL,
  ALARME_VAZAMENTO_GAS,
  ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO,
  ALERTA_APLICATIVO // Estado para quando o app controla (fechou gás ou ativou timer)
};
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

  // Garante estado inicial seguro
  digitalWrite(PINO_VALVULA_SOLENOIDE, LOW); // LOW = Válvula Fechada
  valvulaGasAberta = false;
  digitalWrite(PINO_FAROL_VERMELHO, LOW);
  digitalWrite(PINO_FAROL_AMARELO, LOW);
  digitalWrite(PINO_FAROL_VERDE, HIGH); // Verde aceso indica sistema OK

  ledcSetup(LEDC_CHANNEL_BUZZER, 0, LEDC_RESOLUTION);
  ledcAttachPin(PINO_BUZZER, LEDC_CHANNEL_BUZZER);
  pararMelodiaAlerta(); // Garante buzzer desligado

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
    updateSystemState(); // Avalia as condições e atualiza o estado do sistema
    lastSensorReadTime = millis();
  }

  updateVisualsAndAlarms(); // Controla LEDs e Buzzer com base no estado atual

  if (millis() - lastPublishTime >= PUBLISH_INTERVAL) {
    publishData();
    lastPublishTime = millis();
  }
  
  mqtt.ping(); // Mantém a conexão MQTT ativa
}


// --- Funções Auxiliares ---

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

  // Log para depuração
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
  // PRIORIDADE 1: VAZAMENTO DE GÁS
  if (valorGasAtual > LIMIAR_GAS_ALERTA) {
    currentState = ALARME_VAZAMENTO_GAS;
    controlValvulaSolenoide(false);
    return;
  }
  
  // PRIORIDADE 2: FOGO SEM PRESENÇA (E SEM OVERRIDE DO APP)
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
    // Reseta o timer se a condição não se aplica mais
    if (timerFogoSemPresencaAtivo) {
      timerFogoSemPresencaAtivo = false;
    }
  }
  
  // PRIORIDADE 3: ESTADOS CONTROLADOS PELO APP
  if (currentState == ALERTA_APLICATIVO) {
      // Permanece neste estado até um comando explícito para abrir o gás
      // A válvula é controlada diretamente em handleMQTTMessages
      return;
  }

  // ESTADO NORMAL: Se nenhum alarme ou trava do app estiver ativa
  currentState = NORMAL;
  if (!fogoTimerAppAtivo) { // Só abre a válvula automaticamente se o app não tiver fechado
      controlValvulaSolenoide(true);
  }
}

void updateVisualsAndAlarms() {
    static unsigned long lastBlinkTime = 0;
    static bool ledState = false;

    switch (currentState) {
        case NORMAL:
            digitalWrite(PINO_FAROL_VERMELHO, LOW);
            digitalWrite(PINO_FAROL_AMARELO, fogoTimerAppAtivo ? HIGH : LOW); // Amarelo se timer do app ativo
            digitalWrite(PINO_FAROL_VERDE, fogoTimerAppAtivo ? LOW : HIGH); // Verde se normal
            pararMelodiaAlerta();
            break;

        case ALARME_VAZAMENTO_GAS:
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
            digitalWrite(PINO_FAROL_VERDE, LOW);
            digitalWrite(PINO_FAROL_AMARELO, LOW);
            tocarMelodiaAlerta();
            // Pisca o LED vermelho
            if (millis() - lastBlinkTime >= BLINK_INTERVAL) {
                ledState = !ledState;
                digitalWrite(PINO_FAROL_VERMELHO, ledState);
                lastBlinkTime = millis();
            }
            break;

        case ALERTA_APLICATIVO: // App fechou o gás
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

  // Lê a duração da nota da memória PROGMEM
  int noteDuration = tempoBase / abs(pgm_read_word_near(melody + currentNoteIndex + 1));
  
  if (millis() - lastNoteTime >= noteDuration) {
    // Lê a frequência da nota da memória PROGMEM
    int nota = pgm_read_word_near(melody + currentNoteIndex);
    
    if (nota > 0) {
      ledcWriteTone(LEDC_CHANNEL_BUZZER, nota);
    } else {
      pararMelodiaAlerta(); // Pausa
    }
    
    currentNoteIndex += 2;
    if (currentNoteIndex >= NUM_MELODY) {
      currentNoteIndex = 0; // Reinicia
    }
    lastNoteTime = millis();
  }
}

void pararMelodiaAlerta() {
  ledcWriteTone(LEDC_CHANNEL_BUZZER, 0);
}

void handleMQTTMessages() {
  Adafruit_MQTT_Subscribe *subscription;
  if ((subscription = mqtt.readSubscription(500))) { // Timeout curto para não bloquear
    if (subscription == &valvulaGasControleSub) {
      Serial.print("Comando Válvula: "); Serial.println((char *)subscription->lastread);
      // Uso de strcmp para evitar criar objetos String
      if (strcmp((char *)subscription->lastread, "FECHAR_AGORA") == 0) {
        controlValvulaSolenoide(false);
        currentState = ALERTA_APLICATIVO;
      } else if (strcmp((char *)subscription->lastread, "ABRIR_AGORA") == 0) {
        // Só abre se não houver alarme ativo
        if (valorGasAtual <= LIMIAR_GAS_ALERTA && currentState != ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
          controlValvulaSolenoide(true);
          currentState = NORMAL;
        } else {
          Serial.println("AVISO: Abertura negada devido a alarme ativo.");
        }
      }
    } else if (subscription == &fogoTimerResetSub) {
      if (strcmp((char *)subscription->lastread, "RESET_TIMER") == 0) {
          timerFogoSemPresenca = millis(); // Reseta o timer de esquecimento
          Serial.println("Timer de Fogo sem Presença RESETADO pelo app.");
      }
    } else if (subscription == &fogoTimerAppSub) {
      if (strcmp((char *)subscription->lastread, "ATIVAR_TIMER") == 0) {
        fogoTimerAppAtivo = true;
        timerFogoSemPresencaAtivo = false; // Override do app desativa o timer de segurança
        Serial.println("Timer de Fogo do App ATIVADO.");
      } else if (strcmp((char *)subscription->lastread, "DESATIVAR_TIMER") == 0) {
        fogoTimerAppAtivo = false;
        Serial.println("Timer de Fogo do App DESATIVADO.");
      }
    }
  }
}

void publishData() {
  gasConcentracaoFeed.publish(valorGasAtual);
  valvulaGasEstadoFeed.publish(valvulaGasAberta ? "ABERTA" : "FECHADA");
  fogoEstadoFeed.publish(chamaDetectada ? "DETECTADO" : "NAO_DETECTADO");
  presencaCozinhaFeed.publish(presencaDetectada ? "PRESENCA" : "AUSENCIA");

  // Publica o estado geral do sistema
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