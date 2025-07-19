// --- O Aleh tem que colocar as coisas aqui ---
 // --- Bibliotecas Necessárias ---
 #include <WiFi.h>
 #include <AdafruitIO_WiFi.h>
 
 // --- Configurações do Wi-Fi ---
    #include "secrets.h" // Inclui o arquivo de segredos com SSID e Senha do Wi-Fi
    // --- Instância do Adafruit IO ---
    AdafruitIO_WiFi io(IO_USERNAME, IO_KEY, WIFI_SSID, WIFI_PASS);