# ESP32 LVGL Thermostat Panel

A simple interactive Thermostat interface built with **ESP32**, **LVGL (v8.3)**, and **TFT_eSPI**. This project features a bidirectional integration with **Home Assistant** via MQTT Discovery, allowing real-time synchronization between the physical touch panel and your smart home dashboard.

---

## 🚀 Features

* **Interactive UI**: Modern Gauge (Meter) and slim Slider for intuitive temperature control.
* **Bi-directional Sync**: 
    * Change temperature on the ESP32 → Updates Home Assistant.
    * Change value in Home Assistant → Needle and Slider on ESP32 move automatically.
* **MQTT Discovery**: Automatically recognized by Home Assistant as a `number` entity (no YAML configuration required).
* **Smooth Graphics**: Optimized LVGL implementation with custom styling and Montserrat fonts.
* **Hardware Optimized**: Calibrated touch response for resistive screens with an extended touch area for the slider.

---

## 🛠 Hardware Required

* **ESP32** DevKit (WROOM-32).
* **320x240 TFT Display** (ILI9341 or similar) with Touch Controller (XPT2046).
* **MQTT Broker** (Mosquitto via Home Assistant Add-on or standalone).

## 🛠 Hardware Note

* VCC  --> 3.3V --> Power
* GND  --> GND  --> 0 V
* CS (Display) --> GPIO 15  --> Chip Select Display
* RESET --> GPIO 4 (o EN) -->   Reset Hardware
* DC/RS --> GPIO 2 -->  Data/Command
* MOSI -->  GPIO 23 --> Master Out Slave In
* SCK  -->  GPIO 18 --> Serial Clock
* LED  -->  3.3V o GPIO 21 --> Retroilluminazione
* MISO -->  GPIO 19 --> Master In Slave Out
* T_CS (Touch) --> GPIO 5 --> Chip Select Touch
* T_IRQ --> N.C --> (Opzion) Interrupt touch
* T_CLK --> SCK (GPIO 18)
* T_DIN --> MOSI (GPIO 23)
* T_DO  --> MISO (GPIO 19)
  
---

## 📋 Software Dependencies

The project is developed using **PlatformIO**. Ensure you have the following libraries installed in your `platformio.ini`:

* `lvgl/lvgl@^8.3.x`
* `bodmer/TFT_eSPI@^2.5.0`
* `knolleary/PubSubClient@^2.8`


---

## ⚙️ Configuration

### 1. PlatformIO Build Flags (`platformio.ini`)
Add these flags to enable the fonts and increase the MQTT buffer size to handle long JSON discovery payloads:

```ini
build_flags =
    ; Parametri per TFT_eSPI
    -D LV_FONT_MONTSERRAT_20=1
    -D USER_SETUP_LOADED=1
    -D ILI9341_DRIVER=1
    -D TFT_MISO=19
    -D TFT_MOSI=23
    -D TFT_SCLK=18
    -D TFT_CS=15
    -D TFT_DC=2
    -D TFT_RST=4
    -D TOUCH_CS=5
    -D SPI_FREQUENCY=40000000
    -D SPI_TOUCH_FREQUENCY=2500000
    ; Parametri per PubSubClient
    -D MQTT_MAX_PACKET_SIZE=1024
    ; Parametri per LVGL
    -D LV_CONF_SKIP
    -D LV_CONF_INCLUDE_SIMPLE
    -D LV_LVGL_H_INCLUDE_SIMPLE



