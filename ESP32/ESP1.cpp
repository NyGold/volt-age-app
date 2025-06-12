// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include "Adafruit_IO_Arduino.h"  // Nova biblioteca Adafruit IO
#include <pgmspace.h>

// --- Inclui o arquivo de segredos ---
// ATENÇÃO: A nova biblioteca espera a senha do Wi-Fi na variável WIFI_PASS
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

// --- Configuração do Buzzer para ESP32 (LEDC) - API para Core v3.x.x ---
#define LEDC_RESOLUTION 10 // Resolução em bits para o PWM do LEDC

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

// --- Instância do Adafruit IO ---
AdafruitIO_MQTT io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Feeds do Adafruit IO (usando Adafruit_IO_Arduino) ---
AdafruitIO_Feed *gasConcentracaoFeed = io.feed("gas-concentracao");
AdafruitIO_Feed *gasAlertaFeed       = io.feed("gas-alerta");
AdafruitIO_Feed *valvulaGasEstadoFeed= io.feed("valvula-gas-estado");
AdafruitIO_Feed *fogoEstadoFeed      = io.feed("fogo-estado");
AdafruitIO_Feed *presencaCozinhaFeed = io.feed("presenca-cozinha");

AdafruitIO_Feed *valvulaGasControleSub = io.feed("valvula-gas-controle");
AdafruitIO_Feed *fogoTimerResetSub     = io.feed("fogo-timer-reset");
AdafruitIO_Feed *fogoTimerAppSub       = io.feed("fogo-timer-app");

// --- Constantes de Controle e Timers ---
const int  LIMIAR_GAS_ALERTA = 1500;
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000;
const long SENSOR_READ_INTERVAL = 500;
const long PUBLISH_INTERVAL     = 20000;
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

// --- Protótipos das Funções de Callback ---
void handleValvulaControlMessage(AdafruitIO_Data *data);
void handleFogoTimerResetMessage(AdafruitIO_Data *data);
void handleFogoTimerAppMessage(AdafruitIO_Data *data);

// --- Protótipos de Funções Auxiliares ---
void readSensors();
void controlValvulaSolenoide(bool abrir);
void updateSystemState();
void tocarMelodiaAlerta();
void pararMelodiaAlerta();
void publishData_IO();
void updateVisualsAndAlarms();

// --- Função setup() ---
void setup() {
  Serial.begin(115200);
  delay(10);
  Serial.println("\n===================================");
  Serial.println("  Módulo Fogão/Gás - ESP32 #1      ");
  Serial.println("  (Biochallenge 25 - Volt Age)     ");
  Serial.println("  Adafruit_IO_Arduino & Core v3.x.x");
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

  ledcAttach(PINO_BUZZER, 0, LEDC_RESOLUTION);
  pararMelodiaAlerta();

  Serial.print("Conectando ao Adafruit IO");
  io.connect();

  valvulaGasControleSub->onMessage(handleValvulaControlMessage);
  fogoTimerResetSub->onMessage(handleFogoTimerResetMessage);
  fogoTimerAppSub->onMessage(handleFogoTimerAppMessage);

  int connect_retries = 0;
  while (io.status() < AIO_CONNECTED) {
    Serial.print(".");
    delay(500);
    connect_retries++;
    if (connect_retries > 30) {
      Serial.println("\nFalha ao conectar ao Adafruit IO. Reiniciando...");
      ESP.restart();
    }
  }
  Serial.println();
  Serial.println(io.statusText());
  Serial.print("Endereço IP: ");
  Serial.println(WiFi.localIP());

  Serial.println("Buscando estados iniciais dos feeds de controle...");
  valvulaGasControleSub->get();
  fogoTimerResetSub->get();
  fogoTimerAppSub->get();
  Serial.println("------------------------------------");
}

// --- Função loop() ---
void loop() {
  io.run(); // Gerencia a conexão e dispara os callbacks.
  unsigned long currentTime = millis();
  if (currentTime - lastSensorReadTime >= SENSOR_READ_INTERVAL) {
    readSensors();
    updateSystemState();
    lastSensorReadTime = currentTime;
  }
  updateVisualsAndAlarms();
  if (currentTime - lastPublishTime >= PUBLISH_INTERVAL) {
    publishData_IO();
    lastPublishTime = currentTime;
  }
}

// --- Implementação das Funções de Callback ---
void handleValvulaControlMessage(AdafruitIO_Data *data) {
  Serial.print("CALLBACK Recebido: '");
  Serial.print(data->toString());
  Serial.println("'");

  const char *comando = data->toChar();
  if (strcmp(comando, "FECHAR_AGORA") == 0) {
    controlValvulaSolenoide(false);
    currentState = ALERTA_APLICATIVO;
  } else if (strcmp(comando, "ABRIR_AGORA") == 0) {
    if (currentState == ALARME_VAZAMENTO_GAS) {
      if (valorGasAtual < LIMIAR_GAS_ALERTA) {
        Serial.println("Alarme de gás resetado pelo app. Nível de gás seguro.");
        currentState = NORMAL;
        controlValvulaSolenoide(true);
      } else {
        Serial.println("AVISO: Reset negado! Nível de gás ainda está alto.");
      }
    } else if (currentState != ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
      controlValvulaSolenoide(true);
      currentState = NORMAL;
    } else {
      Serial.println("AVISO: Abertura negada devido a outro alarme ativo.");
    }
  }
}

void handleFogoTimerResetMessage(AdafruitIO_Data *data) {
  if (strcmp(data->toChar(), "RESET_TIMER") == 0) {
    timerFogoSemPresenca = millis();
    Serial.println("Timer de Fogo sem Presença RESETADO pelo app.");
  }
}

void handleFogoTimerAppMessage(AdafruitIO_Data *data) {
  if (strcmp(data->toChar(), "ATIVAR_TIMER") == 0) {
    fogoTimerAppAtivo = true;
    timerFogoSemPresencaAtivo = false;
    Serial.println("Timer de Fogo do App ATIVADO.");
  } else if (strcmp(data->toChar(), "DESATIVAR_TIMER") == 0) {
    fogoTimerAppAtivo = false;
    Serial.println("Timer de Fogo do App DESATIVADO.");
  }
}

// --- Implementação das Funções Auxiliares ---
void readSensors() {
  valorGasAtual = analogRead(PINO_SENSOR_GAS_AO);
  chamaDetectada = (digitalRead(PINO_SENSOR_CHAMA_DO) == LOW);
  presencaDetectada = (digitalRead(PINO_SENSOR_PIR) == HIGH);
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
  if (currentState == ALARME_VAZAMENTO_GAS) {
    controlValvulaSolenoide(false);
    return;
  }
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
  if (currentState == ALERTA_APLICATIVO) {
    controlValvulaSolenoide(false);
    return;
  }
  currentState = NORMAL;
  controlValvulaSolenoide(true);
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
      ledcWriteTone(PINO_BUZZER, nota);
    } else {
      ledcWriteTone(PINO_BUZZER, 0);
    }
    currentNoteIndex += 2;
    if (currentNoteIndex >= NUM_MELODY) {
      currentNoteIndex = 0;
    }
    lastNoteTime = millis();
  }
}

void pararMelodiaAlerta() {
  ledcWriteTone(PINO_BUZZER, 0);
}

void publishData_IO() {
  Serial.println("Publicando dados no Adafruit IO...");
  gasConcentracaoFeed->save(valorGasAtual);
  valvulaGasEstadoFeed->save(valvulaGasAberta ? "ABERTA" : "FECHADA");
  fogoEstadoFeed->save(chamaDetectada ? "DETECTADO" : "NAO_DETECTADO");
  presencaCozinhaFeed->save(presencaDetectada ? "PRESENCA" : "AUSENCIA");

  switch (currentState) {
    case ALARME_VAZAMENTO_GAS:
      gasAlertaFeed->save("ALARME_GAS");
      break;
    case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
      gasAlertaFeed->save("FOGO_SEM_PRESENCA");
      break;
    case ALERTA_APLICATIVO:
      gasAlertaFeed->save("ALERTA_APP");
      break;
    case NORMAL:
    default:
      if (fogoTimerAppAtivo) {
        gasAlertaFeed->save("FOGO_TIMER_ATIVO");
      } else if (timerFogoSemPresencaAtivo) {
        char buffer[50]; // Correção do estouro de buffer
        unsigned long tempoDecorrido = millis() - timerFogoSemPresenca;
        long tempoRestanteMs = TEMPO_MAX_FOGO_SEM_PRESENCA - tempoDecorrido;
        if (tempoRestanteMs < 0) tempoRestanteMs = 0;
        unsigned long tempoRestanteSeg = tempoRestanteMs / 1000;
        sprintf(buffer, "FOGO_CONTANDO (%lu s)", tempoRestanteSeg);
        gasAlertaFeed->save(buffer);
      } else {
        gasAlertaFeed->save("OK");
      }
      break;
  }
}