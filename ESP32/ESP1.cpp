// --- Bibliotecas Necessárias (mesmas de antes) ---
#include <WiFi.h>
#include <pgmspace.h>
#include <AdafruitIO_WiFi.h> // Adiciona a biblioteca do Adafruit IO

// --- Inclui o arquivo de segredos (mesmo de antes) ---
#include "secrets.h"

// --- Instância do Adafruit IO (mesma de antes) ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Pinos dos Sensores e Atuadores (mesmos de antes) ---
const int PINO_SENSOR_GAS_AO = 32;
const int PINO_SENSOR_CHAMA_DO = 33;
const int PINO_SENSOR_PIR = 27;
const int PINO_VALVULA_SOLENOIDE = 26;
const int PINO_BUZZER = 25;
const int PINO_FAROL_VERMELHO = 13;
const int PINO_FAROL_AMARELO = 12;
const int PINO_FAROL_VERDE = 14;

// --- Configuração do Buzzer para ESP32 (LEDC) - API para Core v3.x.x (mesma de antes) ---
#define LEDC_RESOLUTION 10 // Resolução em bits para o PWM do LEDC

// --- Definição das Notas Musicais ---
// Adicionando mais notas para maior variedade
#define NOTE_C4 262
#define NOTE_G3 196
#define NOTE_E4 330
#define NOTE_A4 440
#define NOTE_B4 494
#define NOTE_C5 523
#define NOTE_D5 587
#define NOTE_E5 659
#define NOTE_F5 698
#define NOTE_G5 784

// --- Melodia de Alerta (Melodia do Mario - primeiro trecho) ---
// Formato: Nota, Duração (1 = inteira, 2 = metade, 4 = um quarto, 8 = um oitavo, etc.)
// 0 representa uma pausa
const int melody[] PROGMEM = {
    NOTE_E5, 8, NOTE_E5, 8, 0, 8, NOTE_E5, 8, // E5 E5 - E5
    0, 8, NOTE_C5, 8, NOTE_E5, 8, 0, 8,       // - C5 E5 -
    NOTE_G5, 8, 0, 8, 0, 4,                   // G5 - - (pausa mais longa)
    NOTE_G3, 8, 0, 8                          // G3 - (nota final baixa)
};
#define NUM_MELODY (sizeof(melody) / sizeof(melody[0]))
const int tempoBase = 180; // Duração base da nota em milissegundos. Ajuste para mais lento/rápido.
                           // Reduzi um pouco para manter o ritmo do Mario, mas você pode experimentar valores maiores (ex: 250) para notas mais longas.

// --- Feeds do Adafruit IO (mesmos de antes) ---
AdafruitIO_Feed *gasConcentracaoFeed = io.feed("gas-concentracao");
AdafruitIO_Feed *gasAlertaFeed = io.feed("gas-alerta");
AdafruitIO_Feed *valvulaGasEstadoFeed = io.feed("valvula-gas-estado");
AdafruitIO_Feed *fogoEstadoFeed = io.feed("fogo-estado");
AdafruitIO_Feed *presencaCozinhaFeed = io.feed("presenca-cozinha");

AdafruitIO_Feed *valvulaGasControleSub = io.feed("valvula-gas-controle");
AdafruitIO_Feed *fogoTimerResetSub = io.feed("fogo-timer-reset");
AdafruitIO_Feed *fogoTimerAppSub = io.feed("fogo-timer-app");

// --- Constantes de Controle e Timers (mesmas de antes) ---
const int LIMIAR_GAS_ALERTA = 1500;
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000;
const long SENSOR_READ_INTERVAL = 500;
const long PUBLISH_INTERVAL = 20000;
const long BLINK_INTERVAL = 250;

// --- Variáveis de Estado do Sistema e Timers (mesmas de antes) ---
int valorGasAtual = 0;
bool chamaDetectada = false;
bool presencaDetectada = false;
bool valvulaGasAberta = false;
unsigned long timerFogoSemPresenca = 0;
bool timerFogoSemPresencaAtivo = false;
bool fogoTimerAppAtivo = false;
unsigned long lastSensorReadTime = 0;
unsigned long lastPublishTime = 0;

enum SystemState
{
  NORMAL,
  ALARME_VAZAMENTO_GAS,
  ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO,
  ALERTA_APLICATIVO
};
SystemState currentState = NORMAL;

// --- Protótipos das Funções de Callback (mesmos de antes) ---
void handleValvulaControlMessage(AdafruitIO_Data *data);
void handleFogoTimerResetMessage(AdafruitIO_Data *data);
void handleFogoTimerAppMessage(AdafruitIO_Data *data);

// --- Protótipos de Funções Auxiliares (mesmos de antes) ---
void readSensors();
void controlValvulaSolenoide(bool abrir);
void updateSystemState();
void tocarMelodiaAlerta();
void pararMelodiaAlerta();
void publishData_IO();
void updateVisualsAndAlarms();

// --- Função setup() (mesma de antes, com as depurações) ---
void setup()
{
  Serial.begin(115200);
  delay(10);
  Serial.println("\n===================================");
  Serial.println("  Módulo Fogão/Gás - ESP32 #1      ");
  Serial.println("  (Biochallenge 25 - Volt Age)     ");
  Serial.println("  Adafruit_IO_Arduino & Core v3.x.x");
  Serial.println("===================================");

  pinMode(PINO_SENSOR_GAS_AO, INPUT);
  pinMode(PINO_SENSOR_CHAMA_DO, INPUT);
  pinMode(PINO_SENSOR_PIR, INPUT);
  pinMode(PINO_VALVULA_SOLENOIDE, OUTPUT);
  pinMode(PINO_BUZZER, OUTPUT);
  pinMode(PINO_FAROL_VERMELHO, OUTPUT);
  pinMode(PINO_FAROL_AMARELO, LOW); // Garante que a luz amarela está desligada na inicialização
  pinMode(PINO_FAROL_VERDE, OUTPUT);

  digitalWrite(PINO_VALVULA_SOLENOIDE, LOW);
  valvulaGasAberta = false;
  digitalWrite(PINO_FAROL_VERMELHO, LOW);
  digitalWrite(PINO_FAROL_AMARELO, LOW); // Certifica que o farol amarelo está LOW
  digitalWrite(PINO_FAROL_VERDE, HIGH);

  ledcAttachPin(PINO_BUZZER, 0);
  ledcSetup(0, 2000, LEDC_RESOLUTION); // 2000 Hz as example, adjust as needed
  pararMelodiaAlerta();

  Serial.print("Conectando ao Adafruit IO");
  io.connect();

  valvulaGasControleSub->onMessage(handleValvulaControlMessage);
  fogoTimerResetSub->onMessage(handleFogoTimerResetMessage);
  fogoTimerAppSub->onMessage(handleFogoTimerAppMessage);

  int connect_retries = 0;
  while (io.status() < AIO_CONNECTED)
  {
    Serial.print(".");
    delay(500);
    connect_retries++;
    if (connect_retries > 30)
    {
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

// --- Função loop() (mesma de antes, com as depurações) ---
void loop()
{
  io.run(); // Gerencia a conexão e dispara os callbacks.
  unsigned long currentTime = millis();

  if (currentTime - lastSensorReadTime >= SENSOR_READ_INTERVAL)
  {
    readSensors();
    updateSystemState();

    // --- ADIÇÃO PARA DEBUG: Imprime o valor do gás e o estado atual ---
    Serial.print("DEBUG LOOP: Valor Gas Atual: ");
    Serial.print(valorGasAtual);
    Serial.print(" | Estado Atual: ");
    switch (currentState)
    {
    case NORMAL:
      Serial.println("NORMAL");
      break;
    case ALARME_VAZAMENTO_GAS:
      Serial.println("ALARME_VAZAMENTO_GAS");
      break;
    case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
      Serial.println("ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO");
      break;
    case ALERTA_APLICATIVO:
      Serial.println("ALERTA_APLICATIVO");
      break;
    default:
      Serial.println("ESTADO_DESCONHECIDO");
      break;
    }
    // -----------------------------------------------------------------

    lastSensorReadTime = currentTime;
  }
  updateVisualsAndAlarms();
  if (currentTime - lastPublishTime >= PUBLISH_INTERVAL)
  {
    publishData_IO();
    lastPublishTime = currentTime;
  }
}

// --- Implementação das Funções de Callback (mesmas de antes, com as depurações) ---
void handleValvulaControlMessage(AdafruitIO_Data *data)
{
  // --- ADIÇÃO PARA DEBUG: Confirma que o callback foi chamado ---
  Serial.println("===================================");
  Serial.println("handleValvulaControlMessage FOI CHAMADO!");
  // -------------------------------------------------------------

  Serial.print("CALLBACK Recebido: '");
  Serial.print(data->toString());
  Serial.println("'");

  const char *comando = data->toChar();
  if (strcmp(comando, "FECHAR_AGORA") == 0)
  {
    Serial.println("Comando FECHAR_AGORA recebido."); // DEBUG
    controlValvulaSolenoide(false);
    currentState = ALERTA_APLICATIVO;
  }
  else if (strcmp(comando, "ABRIR_AGORA") == 0)
  {
    Serial.println("Comando ABRIR_AGORA recebido."); // DEBUG

    if (currentState == ALARME_VAZAMENTO_GAS)
    {
      // --- ADIÇÃO PARA DEBUG: Mostra valores para decisão de reset ---
      Serial.print("DEBUG: Tentando sair do alarme de gás. Valor Gas: ");
      Serial.print(valorGasAtual);
      Serial.print(" | Limiar: ");
      Serial.println(LIMIAR_GAS_ALERTA);
      // -------------------------------------------------------------

      if (valorGasAtual < LIMIAR_GAS_ALERTA)
      {
        Serial.println("Alarme de gás resetado pelo app. Nível de gás seguro.");
        currentState = NORMAL;
        controlValvulaSolenoide(true);
      }
      else
      {
        Serial.println("AVISO: Reset negado! Nível de gás ainda está alto.");
      }
    }
    else if (currentState != ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO)
    {
      Serial.println("Abrindo válvula, não há alarme de fogo ativo."); // DEBUG
      controlValvulaSolenoide(true);
      currentState = NORMAL;
    }
    else
    {
      Serial.println("AVISO: Abertura negada devido a outro alarme ativo (fogo).");
    }
  }
  Serial.println("==================================="); // DEBUG
}

void handleFogoTimerResetMessage(AdafruitIO_Data *data)
{
  Serial.println("handleFogoTimerResetMessage FOI CHAMADO!"); // DEBUG
  const char *msg = data->toChar();
  if (strcmp(msg, "RESET_TIMER") == 0)
  {
    timerFogoSemPresenca = millis();
    Serial.println("Timer de Fogo sem Presença RESETADO pelo app.");
  }
}

void handleFogoTimerAppMessage(AdafruitIO_Data *data)
{
  Serial.println("handleFogoTimerAppMessage FOI CHAMADO!"); // DEBUG
  const char *msg = data->toChar();
  if (strcmp(msg, "ATIVAR_TIMER") == 0)
  {
    fogoTimerAppAtivo = true;
    timerFogoSemPresencaAtivo = false;
    Serial.println("Timer de Fogo do App ATIVADO.");
  }
  else if (strcmp(msg, "DESATIVAR_TIMER") == 0)
  {
    fogoTimerAppAtivo = false;
    Serial.println("Timer de Fogo do App DESATIVADO.");
  }
}

// --- Implementação das Funções Auxiliares (mesmas de antes, com as depurações) ---
void readSensors()
{
  valorGasAtual = analogRead(PINO_SENSOR_GAS_AO);
  chamaDetectada = (digitalRead(PINO_SENSOR_CHAMA_DO) == LOW);
  presencaDetectada = (digitalRead(PINO_SENSOR_PIR) == HIGH);
}

void controlValvulaSolenoide(bool abrir)
{
  if (abrir && !valvulaGasAberta)
  {
    digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH);
    valvulaGasAberta = true;
    Serial.println("Válvula de gás ABERTA.");
  }
  else if (!abrir && valvulaGasAberta)
  {
    digitalWrite(PINO_VALVULA_SOLENOIDE, LOW);
    valvulaGasAberta = false;
    Serial.println("Válvula de gás FECHADA.");
  }
}

void updateSystemState()
{
  // Se já está em ALARME_VAZAMENTO_GAS, só pode sair por comando do app
  if (currentState == ALARME_VAZAMENTO_GAS)
  {
    controlValvulaSolenoide(false); // Garante que a válvula esteja fechada
    return;                         // Não reavalia outras condições para evitar loops de entrada/saída
  }

  if (valorGasAtual > LIMIAR_GAS_ALERTA)
  {
    Serial.println("MUDANDO PARA: ALARME_VAZAMENTO_GAS (Gás alto)."); // DEBUG
    currentState = ALARME_VAZAMENTO_GAS;
    controlValvulaSolenoide(false);
    return;
  }

  if (chamaDetectada && !presencaDetectada && !fogoTimerAppAtivo)
  {
    if (!timerFogoSemPresencaAtivo)
    {
      timerFogoSemPresenca = millis();
      timerFogoSemPresencaAtivo = true;
      Serial.println("Timer de Fogo sem Presença INICIADO."); // DEBUG
    }
    else if (millis() - timerFogoSemPresenca >= TEMPO_MAX_FOGO_SEM_PRESENCA)
    {
      Serial.println("MUDANDO PARA: ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO."); // DEBUG
      currentState = ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO;
      controlValvulaSolenoide(false);
      return;
    }
  }
  else
  {
    if (timerFogoSemPresencaAtivo)
    {
      Serial.println("Timer de Fogo sem Presença CANCELADO (presença/sem chama)."); // DEBUG
      timerFogoSemPresencaAtivo = false;
    }
  }

  // Se já está em ALERTA_APLICATIVO, permanece lá até resetado explicitamente
  if (currentState == ALERTA_APLICATIVO)
  {
    controlValvulaSolenoide(false); // Garante que a válvula esteja fechada
    return;
  }

  // Se nenhuma condição de alarme foi atendida e não há alerta do app
  Serial.println("MUDANDO PARA: NORMAL."); // DEBUG
  currentState = NORMAL;
  controlValvulaSolenoide(true);
}

void updateVisualsAndAlarms()
{
  static unsigned long lastBlinkTime = 0;
  static bool ledState = false;

  switch (currentState)
  {
  case NORMAL:
    digitalWrite(PINO_FAROL_VERMELHO, LOW);
    digitalWrite(PINO_FAROL_AMARELO, fogoTimerAppAtivo ? HIGH : LOW); // Amarelo aceso se timer do app ativo
    digitalWrite(PINO_FAROL_VERDE, fogoTimerAppAtivo ? LOW : HIGH);   // Verde apagado se timer do app ativo, aceso caso contrário
    pararMelodiaAlerta();
    break;

  case ALARME_VAZAMENTO_GAS:
  case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
    digitalWrite(PINO_FAROL_VERDE, LOW);
    digitalWrite(PINO_FAROL_AMARELO, LOW);
    tocarMelodiaAlerta();
    if (millis() - lastBlinkTime >= BLINK_INTERVAL)
    {
      ledState = !ledState;
      digitalWrite(PINO_FAROL_VERMELHO, ledState); // Vermelho piscando
      lastBlinkTime = millis();
    }
    break;

  case ALERTA_APLICATIVO:
    digitalWrite(PINO_FAROL_VERMELHO, LOW);
    digitalWrite(PINO_FAROL_AMARELO, HIGH); // Amarelo aceso para indicar controle via app
    digitalWrite(PINO_FAROL_VERDE, LOW);
    pararMelodiaAlerta();
    break;
  }
}

void tocarMelodiaAlerta()
{
  static unsigned long lastNoteTime = 0;
  static int currentNoteIndex = 0;

  // Garante que o índice não exceda o tamanho da melodia
  if (currentNoteIndex >= NUM_MELODY)
  {
    currentNoteIndex = 0; // Reinicia a melodia
  }

  int note = pgm_read_word_near(melody + currentNoteIndex);
  int duration = pgm_read_word_near(melody + currentNoteIndex + 1);
  int noteDuration = tempoBase / abs(duration); // Usa abs() para evitar divisão por zero ou negativos

  if (millis() - lastNoteTime >= noteDuration)
  {
    if (note > 0)
    {
      ledcWriteTone(0, note); // Canal 0 para o buzzer
    }
    else
    {
      ledcWriteTone(0, 0); // Pausa (nota 0)
    }
    currentNoteIndex += 2; // Avança para a próxima nota (nota e duração)
    lastNoteTime = millis();
  }
}

void pararMelodiaAlerta()
{
  ledcWriteTone(0, 0); // Desliga o som do buzzer
}

void publishData_IO()
{
  Serial.println("Publicando dados no Adafruit IO...");
  char gasBuffer[16];
  snprintf(gasBuffer, sizeof(gasBuffer), "%d", valorGasAtual);
  gasConcentracaoFeed->save(gasBuffer);
  valvulaGasEstadoFeed->save(static_cast<const char *>(valvulaGasAberta ? "ABERTA" : "FECHADA"));
  fogoEstadoFeed->save(static_cast<const char *>(chamaDetectada ? "DETECTADO" : "NAO_DETECTADO"));
  presencaCozinhaFeed->save(static_cast<const char *>(presencaDetectada ? "PRESENCA" : "AUSENCIA"));

  switch (currentState)
  {
  case ALARME_VAZAMENTO_GAS:
  {
    static char alerta_gas[] = "ALARME_GAS";
    gasAlertaFeed->save(alerta_gas);
    break;
  }
  case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
  {
    static char fogo_sem_presenca[] = "FOGO_SEM_PRESENCA";
    gasAlertaFeed->save(fogo_sem_presenca);
    break;
  }
  case ALERTA_APLICATIVO:
  {
    static char alerta_app[] = "ALERTA_APP";
    gasAlertaFeed->save(alerta_app);
    break;
  }
  case NORMAL:
  default:
    if (fogoTimerAppAtivo)
    {
      static char fogo_timer_ativo[] = "FOGO_TIMER_ATIVO";
      gasAlertaFeed->save(fogo_timer_ativo);
    }
    else if (timerFogoSemPresencaAtivo)
    {
      char buffer[50];
      unsigned long tempoDecorrido = millis() - timerFogoSemPresenca;
      long tempoRestanteMs = TEMPO_MAX_FOGO_SEM_PRESENCA - tempoDecorrido;
      if (tempoRestanteMs < 0)
        tempoRestanteMs = 0;
      unsigned long tempoRestanteSeg = tempoRestanteMs / 1000;
      sprintf(buffer, "FOGO_CONTANDO (%lu s)", tempoRestanteSeg);
      gasAlertaFeed->save(buffer);
    }
    else
    {
      static char ok[] = "OK";
      gasAlertaFeed->save(ok);
    }
    break;
  }
}