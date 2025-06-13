// --- Bibliotecas Necessárias ---
#include <WiFi.h>
#include <pgmspace.h>
#include <AdafruitIO_WiFi.h> // Adiciona a biblioteca do Adafruit IO

// --- Inclui o arquivo de segredos ---
// ATENÇÃO: A nova biblioteca espera a senha do Wi-Fi na variável WIFI_PASS
#include "secrets.h"

// --- Instância do Adafruit IO ---
AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);

// --- Pinos dos Sensores e Atuadores ---
const int PINO_SENSOR_GAS_AO = 32;
const int PINO_SENSOR_CHAMA_DO = 33;
const int PINO_SENSOR_PIR = 27;
const int PINO_VALVULA_SOLENOIDE = 26;
// Removido: PINO_BUZZER
const int PINO_FAROL_VERMELHO = 13;
const int PINO_FAROL_AMARELO = 12;
const int PINO_FAROL_VERDE = 14;

// Removido: Configuração do Buzzer (LEDC_RESOLUTION, NOTE_C4, etc., melody, NUM_MELODY, tempoBase)

// --- Feeds do Adafruit IO (usando Adafruit_IO_Arduino) ---
AdafruitIO_Feed *gasConcentracaoFeed = io.feed("gas-concentracao");
AdafruitIO_Feed *gasAlertaFeed = io.feed("gas-alerta");
AdafruitIO_Feed *valvulaGasEstadoFeed = io.feed("valvula-gas-estado");
AdafruitIO_Feed *fogoEstadoFeed = io.feed("fogo-estado");
AdafruitIO_Feed *presencaCozinhaFeed = io.feed("presenca-cozinha");

AdafruitIO_Feed *valvulaGasControleSub = io.feed("valvula-gas-controle");
AdafruitIO_Feed *fogoTimerResetSub = io.feed("fogo-timer-reset");
AdafruitIO_Feed *fogoTimerAppSub = io.feed("fogo-timer-app");

// --- Constantes de Controle e Timers ---
const int LIMIAR_GAS_ALERTA = 1500;
const long TEMPO_MAX_FOGO_SEM_PRESENCA = 5 * 60 * 1000;
const long SENSOR_READ_INTERVAL = 500;
const long PUBLISH_INTERVAL = 20000;
const long BLINK_INTERVAL_FAST = 250; // Piscar rápido para alarmes críticos
const long BLINK_INTERVAL_SLOW = 1000; // Piscar lento para alertas de contagem regressiva
const long CHAMA_PUBLISH_RATE_LIMIT = 1500;
const long VALVULA_PUBLISH_RATE_LIMIT = 1000;
const long GAS_ALERTA_PUBLISH_RATE_LIMIT = 1000;

// --- Variáveis de Estado do Sistema e Timers ---
int valorGasAtual = 0;
bool chamaDetectada = false;
bool presencaDetectada = false;
bool valvulaGasAberta = false;
unsigned long timerFogoSemPresenca = 0;
bool timerFogoSemPresencaAtivo = false;
bool fogoTimerAppAtivo = false;
unsigned long lastSensorReadTime = 0;
unsigned long lastPublishTime = 0;

bool lastChamaState = false;
unsigned long lastChamaPublishTime = 0;

bool lastValvulaGasState = false;
unsigned long lastValvulaPublishTime = 0;

char lastGasAlertaPublishedString[50];
unsigned long lastGasAlertaPublishTime = 0;

enum SystemState
{
    NORMAL,
    ALARME_VAZAMENTO_GAS,
    ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO,
    ALERTA_APLICATIVO
};
SystemState currentState = NORMAL;

// --- DEFINIÇÃO EXPLÍCITA DE STRINGS PARA PUBLICAÇÃO ---
static char FOGO_DETECTADO[] = "DETECTADO";
static char FOGO_NAO_DETECTADO[] = "NAO_DETECTADO";
static char VALVULA_ABERTA[] = "ABERTA";
static char VALVULA_FECHADA[] = "FECHADA";
static char PRESENCA[] = "PRESENCA";
static char AUSENCIA[] = "AUSENCIA";
static char ALARME_GAS_STR[] = "ALARME_GAS";
static char FOGO_SEM_PRESENCA_STR[] = "FOGO_SEM_PRESENCA";
static char ALERTA_APP_STR[] = "ALERTA_APP";
static char FOGO_TIMER_ATIVO_STR[] = "FOGO_TIMER_ATIVO";
static char OK_STR[] = "OK";
// ----------------------------------------------------------------------------------

// --- Protótipos das Funções de Callback ---
void handleValvulaControlMessage(AdafruitIO_Data *data);
void handleFogoTimerResetMessage(AdafruitIO_Data *data);
void handleFogoTimerAppMessage(AdafruitIO_Data *data);

// --- Protótipos de Funções Auxiliares ---
void readSensors();
void controlValvulaSolenoide(bool abrir);
void updateSystemState();
// Removido: tocarMelodiaAlerta();
// Removido: pararMelodiaAlerta();
void publishData_IO_Periodic();
void publishChamaStatusChange();
void publishValvulaStatusChange();
void publishGasAlertaStatusChange();
void updateVisualsAndAlarms();
String getStateString(SystemState state);
char* getGasAlertaString();

// --- Função setup() ---
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
    // Removido: pinMode(PINO_BUZZER, OUTPUT);
    pinMode(PINO_FAROL_VERMELHO, OUTPUT);
    pinMode(PINO_FAROL_AMARELO, OUTPUT); // Definido como OUTPUT
    pinMode(PINO_FAROL_VERDE, OUTPUT);

    // Estado inicial dos LEDs e Válvula
    digitalWrite(PINO_VALVULA_SOLENOIDE, LOW); // Assumindo relé ativo em LOW para válvula NF (para começar aberta/válvula com fluxo)
    valvulaGasAberta = true; // Define o estado inicial da válvula como ABERTA
    digitalWrite(PINO_FAROL_VERMELHO, LOW);
    digitalWrite(PINO_FAROL_AMARELO, LOW);
    digitalWrite(PINO_FAROL_VERDE, HIGH); // Inicia com o LED Verde aceso (Normal)

    // Removido: ledcAttachPin, ledcSetup, pararMelodiaAlerta();

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

    // Inicializa os 'lastState' com a leitura inicial e publica IMEDIATAMENTE
    lastChamaState = (digitalRead(PINO_SENSOR_CHAMA_DO) == LOW);
    fogoEstadoFeed->save(lastChamaState ? FOGO_DETECTADO : FOGO_NAO_DETECTADO);
    lastChamaPublishTime = millis();

    // NOTA: Ajuste o estado inicial da válvula aqui se for diferente
    // Se a válvula começa FECHADA fisicamente e o relé é ativo LOW, então:
    // digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH);
    // valvulaGasAberta = false;
    // (O código atual no setup faz ela iniciar ABERTA se for NF e relé ativo LOW)
    lastValvulaGasState = valvulaGasAberta;
    valvulaGasEstadoFeed->save(lastValvulaGasState ? VALVULA_ABERTA : VALVULA_FECHADA);
    lastValvulaPublishTime = millis();

    // --- INICIALIZAÇÃO E PRIMEIRA PUBLICAÇÃO DO STATUS GERAL ---
    strcpy(lastGasAlertaPublishedString, getGasAlertaString());
    gasAlertaFeed->save(lastGasAlertaPublishedString);
    lastGasAlertaPublishTime = millis();
    // ------------------------------------------------------------

    Serial.println("Sistema inicializado. Monitorando...");
}

// --- Função loop() ---
void loop()
{
    io.run(); // Gerencia a conexão e dispara os callbacks. ESSENCIAL!
    unsigned long currentTime = millis();

    // Leitura dos sensores e atualização do estado do sistema a cada SENSOR_READ_INTERVAL
    if (currentTime - lastSensorReadTime >= SENSOR_READ_INTERVAL)
    {
        readSensors();
        updateSystemState(); // Esta função pode alterar 'valvulaGasAberta' e 'currentState'
        lastSensorReadTime = currentTime;

        // --- MENSAGEM DE STATUS DO SISTEMA NO TERMINAL ---
        Serial.print("[");
        Serial.print(millis());
        Serial.print("ms] Gás: ");
        Serial.print(valorGasAtual);
        Serial.print(" | Chama: ");
        Serial.print(chamaDetectada ? "SIM" : "NAO");
        Serial.print(" | Presença: ");
        Serial.print(presencaDetectada ? "SIM" : "NAO");
        Serial.print(" | Válvula: ");
        Serial.print(valvulaGasAberta ? "ABERTA" : "FECHADA");
        Serial.print(" | Estado: ");
        Serial.println(getStateString(currentState));
        // --------------------------------------------------
    }

    // Publicações por mudança de estado, com rate limit
    publishChamaStatusChange();
    publishValvulaStatusChange();
    publishGasAlertaStatusChange();

    updateVisualsAndAlarms();

    // Publica outros dados periodicamente
    if (currentTime - lastPublishTime >= PUBLISH_INTERVAL)
    {
        publishData_IO_Periodic();
        lastPublishTime = currentTime;
    }
}

// --- Implementação das Funções de Callback (sem alterações funcionais significativas) ---
void handleValvulaControlMessage(AdafruitIO_Data *data)
{
    Serial.print("Comando da Válvula Recebido: '");
    Serial.print(data->toString());
    Serial.println("'");

    const char *comando = data->toChar();
    if (strcmp(comando, "FECHAR_AGORA") == 0)
    {
        controlValvulaSolenoide(false);
        currentState = ALERTA_APLICATIVO;
        Serial.println("Válvula de gás fechada via app.");
    }
    else if (strcmp(comando, "ABRIR_AGORA") == 0)
    {
        if (currentState == ALARME_VAZAMENTO_GAS)
        {
            Serial.print("Tentando sair do alarme de gás. Gás atual: ");
            Serial.print(valorGasAtual);
            Serial.print(" | Limiar: ");
            Serial.println(LIMIAR_GAS_ALERTA);
            if (valorGasAtual < LIMIAR_GAS_ALERTA)
            {
                Serial.println("Alarme de gás resetado. Nível de gás seguro. Abrindo válvula.");
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
            controlValvulaSolenoide(true);
            currentState = NORMAL;
            Serial.println("Válvula de gás aberta via app.");
        }
        else
        {
            Serial.println("AVISO: Abertura negada devido a alarme de fogo ativo.");
        }
    }
}

void handleFogoTimerResetMessage(AdafruitIO_Data *data)
{
    Serial.print("Comando de Reset de Timer de Fogo Recebido: '");
    Serial.print(data->toString());
    Serial.println("'");
    const char *msg = data->toChar();
    if (strcmp(msg, "RESET_TIMER") == 0)
    {
        timerFogoSemPresenca = millis();
        Serial.println("Timer de Fogo sem Presença RESETADO pelo app.");
    }
}

void handleFogoTimerAppMessage(AdafruitIO_Data *data)
{
    Serial.print("Comando de Timer de Fogo do App Recebido: '");
    Serial.print(data->toString());
    Serial.println("'");
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

// --- Implementação das Funções Auxiliares ---
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
        // Assumindo relé ativo em LOW para válvula NF (Normalmente Fechada)
        digitalWrite(PINO_VALVULA_SOLENOIDE, LOW); // Manda LOW para ligar o relé (luz acende)
        valvulaGasAberta = true;
        Serial.println("AÇÃO: Válvula de gás ABERTA.");
    }
    else if (!abrir && valvulaGasAberta)
    {
        // Assumindo relé ativo em LOW para válvula NF (Normalmente Fechada)
        digitalWrite(PINO_VALVULA_SOLENOIDE, HIGH); // Manda HIGH para desligar o relé (luz apaga)
        valvulaGasAberta = false;
        Serial.println("AÇÃO: Válvula de gás FECHADA.");
    }
}

void updateSystemState()
{
    SystemState previousState = currentState;

    // Lógica para ALARME_VAZAMENTO_GAS (prioridade alta)
    if (currentState == ALARME_VAZAMENTO_GAS)
    {
        controlValvulaSolenoide(false); // Garante que a válvula esteja fechada
        return; // Permanece neste estado até ser resetado pelo app ou gás baixar
    }

    if (valorGasAtual > LIMIAR_GAS_ALERTA)
    {
        currentState = ALARME_VAZAMENTO_GAS;
        controlValvulaSolenoide(false);
        Serial.println("ALERTA: Gás acima do limite! Válvula FECHADA.");
        return;
    }

    // Lógica para ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO
    if (chamaDetectada && !presencaDetectada && !fogoTimerAppAtivo)
    {
        if (!timerFogoSemPresencaAtivo)
        {
            timerFogoSemPresenca = millis();
            timerFogoSemPresencaAtivo = true;
            Serial.println("ALERTA: Chama detectada SEM presença! Timer de fogo iniciado.");
        }
        else if (millis() - timerFogoSemPresenca >= TEMPO_MAX_FOGO_SEM_PRESENCA)
        {
            currentState = ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO;
            controlValvulaSolenoide(false);
            Serial.println("ALERTA: Fogo sem presença por tempo excessivo! Válvula FECHADA.");
            return;
        }
    }
    else
    {
        if (timerFogoSemPresencaAtivo)
        {
            timerFogoSemPresencaAtivo = false;
            Serial.println("INFO: Timer de Fogo sem Presença CANCELADO (presença ou chama ausente).");
        }
    }

    // Lógica para ALERTA_APLICATIVO (prioridade média)
    if (currentState == ALERTA_APLICATIVO)
    {
        controlValvulaSolenoide(false); // Garante que a válvula esteja fechada
        return; // Permanece neste estado até ser resetado pelo app (ABRIR_AGORA)
    }

    // Se nenhuma condição de alarme ou alerta ativo, volta para NORMAL
    currentState = NORMAL;
    controlValvulaSolenoide(true);
    if (previousState != NORMAL) {
        Serial.println("INFO: Sistema NORMAL. Válvula ABERTA.");
    }
}

void updateVisualsAndAlarms()
{
    static unsigned long lastFastBlinkTime = 0;
    static unsigned long lastSlowBlinkTime = 0;
    static bool ledStateFast = false;
    static bool ledStateSlow = false;

    // Apaga todos os LEDs por padrão e acende conforme o estado
    digitalWrite(PINO_FAROL_VERMELHO, LOW);
    digitalWrite(PINO_FAROL_AMARELO, LOW);
    digitalWrite(PINO_FAROL_VERDE, LOW);

    switch (currentState)
    {
    case NORMAL:
        if (fogoTimerAppAtivo) {
            digitalWrite(PINO_FAROL_AMARELO, HIGH); // Amarelo sólido: Timer App Ativo
        } else if (timerFogoSemPresencaAtivo) {
            // Amarelo piscando lento: Contagem regressiva
            if (millis() - lastSlowBlinkTime >= BLINK_INTERVAL_SLOW) {
                ledStateSlow = !ledStateSlow;
                digitalWrite(PINO_FAROL_AMARELO, ledStateSlow);
                lastSlowBlinkTime = millis();
            }
        } else {
            digitalWrite(PINO_FAROL_VERDE, HIGH); // Verde sólido: Normal
        }
        break;

    case ALARME_VAZAMENTO_GAS:
    case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
        // Vermelho piscando rápido: Alarme crítico
        if (millis() - lastFastBlinkTime >= BLINK_INTERVAL_FAST) {
            ledStateFast = !ledStateFast;
            digitalWrite(PINO_FAROL_VERMELHO, ledStateFast);
            lastFastBlinkTime = millis();
        }
        break;

    case ALERTA_APLICATIVO:
        digitalWrite(PINO_FAROL_AMARELO, HIGH); // Amarelo sólido: Alerta App (válvula fechada via app)
        break;
    }
}

// Removido: tocarMelodiaAlerta(), pararMelodiaAlerta()

// --- FUNÇÃO: Publica o status da chama apenas quando há alteração e respeita o rate limit ---
void publishChamaStatusChange() {
    unsigned long currentTime = millis();

    if (chamaDetectada != lastChamaState) {
        if (currentTime - lastChamaPublishTime >= CHAMA_PUBLISH_RATE_LIMIT) {
            Serial.print("PUBLICANDO: Chama -> ");
            Serial.println(chamaDetectada ? FOGO_DETECTADO : FOGO_NAO_DETECTADO);

            fogoEstadoFeed->save(chamaDetectada ? FOGO_DETECTADO : FOGO_NAO_DETECTADO);
            lastChamaState = chamaDetectada;
            lastChamaPublishTime = currentTime;
        }
    }
}

// --- FUNÇÃO: Publica o status da válvula apenas quando há alteração e respeita o rate limit ---
void publishValvulaStatusChange() {
    unsigned long currentTime = millis();

    if (valvulaGasAberta != lastValvulaGasState) {
        if (currentTime - lastValvulaPublishTime >= VALVULA_PUBLISH_RATE_LIMIT) {
            Serial.print("PUBLICANDO: Válvula Gás -> ");
            Serial.println(valvulaGasAberta ? VALVULA_ABERTA : VALVULA_FECHADA);

            valvulaGasEstadoFeed->save(valvulaGasAberta ? VALVULA_ABERTA : VALVULA_FECHADA);
            lastValvulaGasState = valvulaGasAberta;
            lastValvulaPublishTime = currentTime;
        }
    }
}

// --- FUNÇÃO: Gera a string atual para o gasAlertaFeed ---
char* getGasAlertaString() {
    static char currentGasAlertaString[50]; // Buffer para a string

    switch (currentState) {
        case ALARME_VAZAMENTO_GAS:
            strcpy(currentGasAlertaString, ALARME_GAS_STR);
            break;
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO:
            strcpy(currentGasAlertaString, FOGO_SEM_PRESENCA_STR);
            break;
        case ALERTA_APLICATIVO:
            strcpy(currentGasAlertaString, ALERTA_APP_STR);
            break;
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

// --- FUNÇÃO: Publica o status geral apenas quando há alteração e respeita o rate limit ---
void publishGasAlertaStatusChange() {
    unsigned long currentTime = millis();
    char* currentString = getGasAlertaString();

    if (strcmp(currentString, lastGasAlertaPublishedString) != 0) { // Se as strings são diferentes
        if (currentTime - lastGasAlertaPublishTime >= GAS_ALERTA_PUBLISH_RATE_LIMIT) {
            Serial.print("PUBLICANDO: Alerta Geral -> ");
            Serial.println(currentString);

            gasAlertaFeed->save(currentString);
            strcpy(lastGasAlertaPublishedString, currentString);
            lastGasAlertaPublishTime = currentTime;
        }
    }
}

// --- FUNÇÃO: Publica outros dados periodicamente ---
void publishData_IO_Periodic()
{
    Serial.println("PUBLICANDO: Dados periódicos...");
    char gasBuffer[16];
    snprintf(gasBuffer, sizeof(gasBuffer), "%d", valorGasAtual);
    gasConcentracaoFeed->save(gasBuffer);
    
    // Presença ainda é periódica por simplicidade
    presencaCozinhaFeed->save(presencaDetectada ? PRESENCA : AUSENCIA);
}

// --- Função para converter SystemState para String para o Serial Monitor ---
String getStateString(SystemState state) {
    switch (state) {
        case NORMAL: return "NORMAL";
        case ALARME_VAZAMENTO_GAS: return "ALARME_VAZAMENTO_GAS";
        case ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO: return "ALARME_FOGO_SEM_PRESENCA_OU_ESQUECIMENTO";
        case ALERTA_APLICATIVO: return "ALERTA_APLICATIVO";
        default: return "DESCONHECIDO";
    }
}