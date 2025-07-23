# Volt Age - Sistema de Automação Residencial (Biochallenge 2025)

## Sobre o Projeto

Este repositório contém o código-fonte do aplicativo mobile do projeto **Volt Age**, desenvolvido para a competição **Biochallenge Brasil 2025**. A solução consiste em um sistema de automação residencial focado em promover mais segurança, qualidade de vida e, principalmente, autonomia para pessoas idosas, como a Sra. Dolores e o Sr. Antônio.

O aplicativo, desenvolvido em **Flutter**, atua como a interface de controle e monitoramento para um sistema de IoT distribuído, que utiliza microcontroladores ESP32 e a plataforma de nuvem **Adafruit IO** para interagir com o ambiente doméstico.

## 🚀 Funcionalidades Principais

O aplicativo se conecta aos módulos de hardware para oferecer as seguintes funcionalidades:

### Módulo Cozinha
- **Monitoramento de Alertas:** Exibe o status geral do sistema de segurança da cozinha (`OK`, `ALARME DE GÁS`, `FOGO SEM PRESENÇA`, etc.).
- **Feedback de Estado:** Mostra o estado real da válvula de gás (`ABERTA` ou `FECHADA`).
- **Controle Manual:** Permite ao usuário abrir ou fechar a válvula de gás remotamente.
- **Anulação de Segurança:** Um botão de "Lógica de Esquecimento" que permite desativar temporariamente o alarme de "fogo sem presença" para cozimentos longos.
- **Reset de Alarmes:** Permite ao usuário rearmar o sistema após um alarme, garantindo uma intervenção consciente.

### Módulo Jardinagem
- **Monitoramento de Umidade:** Exibe a umidade do solo em uma escala percentual (0-100%).
- **Lembrete de Rega:** Apresenta um status visual claro (`UMIDADE OK` ou `REGAR AGORA`).
- **Controle de Sensibilidade:** Um slider permite que o usuário ajuste o limiar de umidade que dispara o lembrete de rega.

### Módulo Iluminação
- **Feedback de Status:** Mostra se as luzes de segurança estão `ACESAS` ou `APAGADAS`.
- **Controle de Modo:** Permite ao usuário alternar entre os modos `AUTOMÁTICO`, `LIGAR MANUAL` e `DESLIGAR MANUAL`.
- **Personalização de Cor:** Um seletor de cores (`Color Picker`) permite ao usuário escolher a cor da iluminação.

## 🛠️ Tecnologias Utilizadas

- **Frontend (Aplicativo):** Flutter e Dart
- **Comunicação com a Nuvem:** MQTT
- **Plataforma de Nuvem (Broker):** Adafruit IO
- **Hardware Embarcado:** ESP32 (com firmware desenvolvido em C++ no PlatformIO)

## 🏁 Começando

Para rodar este projeto localmente, siga os passos abaixo.

### Pré-requisitos
- Ter o [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado.
- Um editor de código como o [VS Code](https://code.visualstudio.com/) com a extensão do Flutter.

### Instalação

1.  **Clone o repositório:**
    ```sh
    git clone [https://github.com/nygold/volt-age-app.git](https://github.com/nygold/volt-age-app.git)
    ```
2.  **Navegue até a pasta do projeto:**
    ```sh
    cd volt-age-app
    ```
3.  **Instale as dependências:**
    ```sh
    flutter pub get
    ```
4.  **Configure as Credenciais:**
    - Na pasta `lib/`, crie um arquivo chamado `env.dart`.
    - Adicione suas credenciais do Wi-Fi e da Adafruit IO neste arquivo, seguindo o modelo abaixo:
      ```dart
      // lib/env.dart
      const String IO_USERNAME = "seu_usuario_adafruit";
      const String IO_KEY = "sua_chave_aio";
      ```
    - *Observação: O arquivo `env.dart` já está listado no `.gitignore` para proteger suas credenciais.*

5.  **Execute o aplicativo:**
    ```sh
    flutter run
    ```

## ⚙️ Componente de Hardware

Este aplicativo é a interface de um sistema de IoT maior. O firmware para os microcontroladores ESP32, que se conectam aos sensores e atuadores, está localizado na pasta `ESP32/` deste repositório.

- **`ESP32/ESP1.cpp`:** Firmware para o Módulo Cozinha e Módulo Jardinagem.
- **`ESP32/ESP2.cpp`:** Firmware para o Módulo Iluminação.

## 👥 Equipe Volt Age

- **Gabriell de Luccas Rêgo Lourenço** - Gerente de Projeto & Desenvolvedor de Firmware
- **Alexandre Martins Soares** - Desenvolvedor de Firmware & Hardware
- **Nycollas Silva Teixeira** - Desenvolvedor do Aplicativo Flutter

---