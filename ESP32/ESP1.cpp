// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <AdafruitIO_WiFi.h>
#include <pgmspace.h>

// --- Inclui o arquivo de segredos ---
#include "secrets.h"

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Pinos dos Sensores e Atuadores ---
const int PINO_SENSOR_GAS_AO     = 32;
const int PINO_SENSOR_CHAMA_DO   = 33;
const int PINO_SENSOR_PIR        = 27;
const int PINO_VALVULA_SOLENOIDE = 26;
const int PINO_FAROL_VERMELHO    = 13;
const int PINO_FAROL_AMARELO     = 12;
const int PINO_FAROL_VERDE       = 14;

// --- Feeds do Adafruit IO (5 Feeds Essenciais) ---
AdafruitIO_Feed *gasAlertaFeed        = io.feed("gas-alerta");
AdafruitIO_Feed *valvulaGasEstadoFeed = io.feed("valvula-gas-estado");

AdafruitIO_Feed *valvulaGasControleSub = io.feed("valvula-gas-controle");
AdafruitIO_Feed *fogoTimerResetSub     = io.feed("fogo-timer-reset");
AdafruitIO_Feed *fogoTimerAppSub       = io.feed("fogo-timer-app");

// --- Constantes de Controle e Timers ---
const int  LIMIAR_GAS_ALERTA = 1500;
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000;
const long SENSOR_READ_INTERVAL = 500;
const long BLINK_INTERVAL_FAST = 250;
const long BLINK_INTERVAL_SLOW = 1000;
const long STATUS_CHANGE_PUBLISH_RATE_LIMIT = 1000; // Delay de 1s entre publicações de status

// --- Variáveis de Estado do Sistema e Timers ---
int  valorGasAtual = 0;
bool chamaDetectada = false;
bool presencaDetectada = false;
bool valvulaGasAberta = false;
unsigned long timerFogoSemPresenca = 0;
bool timerFogoSemPresencaAtivo = false;
bool fogoTimerAppAtivo = false;
unsigned long lastSensorReadTime = 0;

// Variáveis para a lógica "Publish on Change"
bool lastValvulaGasState = false;
char lastGasAlertaPublishedString[50] = "";
unsigned long lastStatusChangePublishTime = 0;

enum SystemState { NORMAL, ALARME_VAZAMENTO_GAS, ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO, ALERTA_APLICATIVO };
SystemState currentState = NORMAL;

// Strings para publicação
static char VALVULA_ABERTA[] = "ABERTA";
static char VALVULA_FECHADA[] = "FECHADA";
static char ALARME_GAS_STR[] = "ALARME_GAS";
static char FOGO_SEM_PRESENCA_STR[] = "FOGO_SEM_PRESENCA";
static char ALERTA_APP_STR[] = "ALERTA_APP";
static char FOGO_TIMER_ATIVO_STR[] = "FOGO_TIMER_ATIVO";
static char OK_STR[] = "OK";

// --- Protótipos ---
void handleValvulaControlMessage(AdafruitIO_Data *data);
void handleFogoTimerResetMessage(AdafruitIO_Data *data);
void handleFogoTimerAppMessage(AdafruitIO_Data *data);
void readSensors();
void controlValvulaSolenoide(bool abrir);
void updateSystemState();
void publishStatusOnChange();
void updateVisuals();
String getStateString(SystemState state);
char* getGasAlertaString();

// --- Função setup() ---
void setup() {
  Serial.begin(115200);
  delay(10);
  Serial.println("\n--- Módulo Fogão/Gás v1.1 (5 Feeds) ---");

  pinMode(PINO_SENSOR_GAS_AO, INPUT);
  pinMode(PINO_SENSOR_CHAMA_DO, INPUT);
  pinMode(PINO_SENSOR_PIR, INPUT);
  pinMode(PINO_VALVULA_SOLENOIDE, OUTPUT);
  pinMode(PINO_FAROL_VERMELHO, OUTPUT);
  pinMode(PINO_FAROL_AMARELO, OUTPUT);
  pinMode(PINO_FAROL_VERDE, OUTPUT);

  digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH);
  valvulaGasAberta = false;
  digitalWrite(PINO_FAROL_VERMELHO, LOW);
  digitalWrite(PINO_FAROL_AMARELO, LOW);
  digitalWrite(PINO_FAROL_VERDE, HIGH);

  Serial.print("Conectando ao Adafruit IO...");
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

  // Sincroniza o estado inicial com o dashboard
  readSensors();
  controlValvulaSolenoide(true);
  updateSystemState();
  publishStatusOnChange();
}

// --- Função loop() ---
void loop() {
  io.run(); // Essencial para a comunicação e callbacks
  unsigned long currentTime = millis();

  if (currentTime - lastSensorReadTime >= SENSOR_READ_INTERVAL) {
    readSensors();
    updateSystemState();
    lastSensorReadTime = currentTime;
    
    Serial.print("["); Serial.print(millis()); Serial.print("ms] Gás: "); Serial.print(valorGasAtual);
    Serial.print(" | Chama: "); Serial.print(chamaDetectada ? "SIM" : "NAO");
    Serial.print(" | Presença: "); Serial.print(presencaDetectada ? "SIM" : "NAO");
    Serial.print(" | Válvula: "); Serial.print(valvulaGasAberta ? "ABERTA" : "FECHADA");
    Serial.print(" | Estado: "); Serial.println(getStateString(currentState));
  }

  publishStatusOnChange();
  updateVisuals();
}

// --- Implementação das Funções de Callback ---
void handleValvulaControlMessage(AdafruitIO_Data *data) {
  const char* comando = data->toChar();
  if (strcmp(comando, "FECHAR_AGORA") == 0) {
    controlValvulaSolenoide(false);
    currentState = ALERTA_APLICATIVO;
  } else if (strcmp(comando, "ABRIR_AGORA") == 0) {
    if (currentState == ALARME_VAZAMENTO_GAS) {
      if (valorGasAtual < LIMIAR_GAS_ALERTA) {
        currentState = NORMAL;
      } else {
        Serial.println("AVISO: Reset de alarme de gás negado! Nível de gás ainda está alto.");
      }
    } else if (currentState == ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
      Serial.println("AVISO: Abertura negada! Sistema em alarme de fogo. Use o reset de timer de fogo.");
    } else {
      currentState = NORMAL;
    }
  }
}

void handleFogoTimerResetMessage(AdafruitIO_Data *data) {
  if (strcmp(data->toChar(), "RESET_TIMER") == 0) {
    if (currentState == ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
      if (!chamaDetectada || presencaDetectada) {
        currentState = NORMAL;
      } else {
        Serial.println("AVISO: Reset de alarme de fogo negado! Condição de perigo ainda ativa.");
      }
    } else {
      timerFogoSemPresenca = millis();
    }
  }
}

void handleFogoTimerAppMessage(AdafruitIO_Data *data) {
  if (strcmp(data->toChar(), "ATIVAR_TIMER") == 0) {
    fogoTimerAppAtivo = true;
    timerFogoSemPresencaAtivo = false;
  } else if (strcmp(data->toChar(), "DESATIVAR_TIMER") == 0) {
    fogoTimerAppAtivo = false;
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
    digitalWrite(PINO_VALVULA_SOLENOIDE, LOW);
    valvulaGasAberta = true;
  } else if (!abrir && valvulaGasAberta) {
    digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH);
    valvulaGasAberta = false;
  }
}

void updateSystemState() {
  if (currentState == ALARME_VAZAMENTO_GAS || currentState == ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO) {
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

void updateVisuals() {
  static unsigned long lastFastBlinkTime = 0;
  static unsigned long lastSlowBlinkTime = 0;
  static bool ledStateFast = false;
  static bool ledStateSlow = false;
  
  digitalWrite(PINO_FAROL_VERMELHO, LOW);
  digitalWrite(PINO_FAROL_AMARELO, LOW);
  digitalWrite(PINO_FAROL_VERDE, LOW);

  switch (currentState) {
    case NORMAL:
      if (fogoTimerAppAtivo) {
        digitalWrite(PINO_FAROL_AMARELO, HIGH);
      } else if (timerFogoSemPresencaAtivo) {
        if (millis() - lastSlowBlinkTime >= BLINK_INTERVAL_SLOW) {
          ledStateSlow = !ledStateSlow;
          digitalWrite(PINO_FAROL_AMARELO, ledStateSlow);
          lastSlowBlinkTime = millis();
        }
      } else {
        digitalWrite(PINO_FAROL_VERDE, HIGH);
      }
      break;
    case ALARME_VAZAMENTO_GAS:
    case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
      if (millis() - lastFastBlinkTime >= BLINK_INTERVAL_FAST) {
        ledStateFast = !ledStateFast;
        digitalWrite(PINO_FAROL_VERMELHO, ledStateFast);
        lastFastBlinkTime = millis();
      }
      break;
    case ALERTA_APLICATIVO:
      digitalWrite(PINO_FAROL_AMARELO, HIGH);
      break;
  }
}

void publishStatusOnChange() {
    unsigned long currentTime = millis();
    if (currentTime - lastStatusChangePublishTime < STATUS_CHANGE_PUBLISH_RATE_LIMIT) {
        return;
    }
    bool publishedSomething = false;

    if (valvulaGasAberta != lastValvulaGasState) {
        valvulaGasEstadoFeed->save(valvulaGasAberta ? VALVULA_ABERTA : VALVULA_FECHADA);
        lastValvulaGasState = valvulaGasAberta;
        publishedSomething = true;
    }
    char* currentAlertaString = getGasAlertaString();
    if (strcmp(currentAlertaString, lastGasAlertaPublishedString) != 0) {
        gasAlertaFeed->save(currentAlertaString);
        strcpy(lastGasAlertaPublishedString, currentAlertaString);
        publishedSomething = true;
    }
    if (publishedSomething) {
        lastStatusChangePublishTime = currentTime;
    }
}

char* getGasAlertaString() {
    static char currentGasAlertaString[50];
    switch (currentState) {
        case ALARME_VAZAMENTO_GAS: strcpy(currentGasAlertaString, ALARME_GAS_STR); break;
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO: strcpy(currentGasAlertaString, FOGO_SEM_PRESENCA_STR); break;
        case ALERTA_APLICATIVO: strcpy(currentGasAlertaString, ALERTA_APP_STR); break;
        case NORMAL:
        default:
            if (fogoTimerAppAtivo) {
                strcpy(currentGasAlertaString, FOGO_TIMER_ATIVO_STR);
            } else if (timerFogoSemPresencaAtivo) {
                unsigned long tempoDecorrido = millis() - timerFogoSemPresenca;
                long tempoRestanteMs = TEMPO_MAX_FOGO_SEM_PRESENCA - tempoDecorrido;
                if (tempoRestanteMs < 0) tempoRestanteMs = 0;
                unsigned long tempoRestanteSeg = tempoRestanteMs / 1000;
                sprintf(currentGasAlertaString, "FOGO_CONTANDO (%lu s)", tempoRestanteSeg);
            } else {
                strcpy(currentGasAlertaString, OK_STR);
            }
            break;
    }
    return currentGasAlertaString;
}

// Removida: publishData_IO_Periodic() pois todos os dados agora são publicados por mudança.
// (Se você quisesse manter gas-concentracao periódico, a função seria necessária)

String getStateString(SystemState state) {
    switch (state) {
        case NORMAL: return "NORMAL";
        case ALARME_VAZAMENTO_GAS: return "ALARME_VAZAMENTO_GAS";
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO: return "FOGO_SEM_PRESENCA";
        case ALERTA_APLICATIVO: return "ALERTA_APLICATIVO";
        default: return "DESCONHECIDO";
    }
}