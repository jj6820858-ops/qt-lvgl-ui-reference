/*
  3D Printer Filament Dryer Controller  
  ====================================

  Ivan Tarozzi (itarozzi@gmail.com) 2024



  UI built with EEZ-Studio and EEZ-Flow


  Lib dependencies
  -----------------

  - XPT2046_Touchscreen by Paul Stoffregen to use the Touchscreen - https://github.com/PaulStoffregen/XPT2046_Touchscreen 
  - TFT_eSPI by Bodmer to use the TFT display - https://github.com/Bodmer/TFT_eSPI
  - lvgl  by LVGL - https://github.com/lvgl/lvgl
  - BME280_Light by Tomasz 'Zen' Napierala
  - PicoMQTT - https://github.com/mlesniew/PicoMQTT
  - PID_V1 - https://github.com/br3ttb/Arduino-PID-Library/
  
*/

#include <Arduino.h>
#include <PID_v1.h>

#include "MqttController.h"

#if __has_include("credentials.h")
  #include "credentials.h"
#endif
// Create a file called credentials.h with the following content (don't push to github, see .gitignore):
// #define WIFI_SSID "MYSSID"
// #define WIFI_PASSWORD "MYPASSWORD"
// #define MQTT_BROKER "MQTTIPBROKER"
// #define MQTT_PORT 1883
// #define MQTT_USER "MQTTUSER"   no auth used if empty
// #define MQTT_PASSWORD "MQTTPASSWORD"
#ifndef WIFI_SSID
#define WIFI_SSID "WiFi SSID"0, 0
#endif

#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD "password"
#endif

#ifndef MQTT_BROKER
#define MQTT_BROKER "broker_ip"
#define MQTT_PORT "1883"
#endif

#ifndef MQTT_USER
#define MQTT_USER ""   
#define MQTT_PASSWORD ""
#endif

#define MQTT_BASE_TOPIC "itlab/dryer"

#define SW_NAME_REV "MyApp v1.0"

//************* software serial pins used for debug (if serial0 is used for communication) *************
#define RXPIN 27
#define TXPIN 22

// CYD RGB LED Pins
// #define CYD_LED_RED 4
// #define CYD_LED_GREEN 16
// #define CYD_LED_BLUE 17



//************* lvgl and UI includes  *************
#include <lvgl.h>
#include "ui/ui.h"
#include "ui/vars.h"
//#include "ui/actions.h"
//#include "ui/images.h"


#include <Wire.h>    
                                                   // required by BME280 library
#include <BME280_t.h>

//************* TFT display and includes  *************

#include "User_Setup.h"
#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>

// Touchscreen pins
#define XPT2046_IRQ 36   // T_IRQ
#define XPT2046_MISO 39  // T_OUT
#define XPT2046_MOSI 32  // T_DIN
#define XPT2046_CS 33    // T_CS
#define XPT2046_CLK 25   // T_CLK


// PID defines
#define PWM_FAN_CONSERVATIVE  150
#define PWM_FAN_AGGRESSIVE  255

SPIClass touchscreenSPI = SPIClass(VSPI);
XPT2046_Touchscreen touchscreen(XPT2046_CS, XPT2046_IRQ);

// PWM pins
#define HEATER_PIN 15
#define FAN_PIN 2
#define LED_PIN 4

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240

#define TFT_GREY 0x5AEB // New colour

// Touchscreen coordinates: (x, y) and pressure (z)
int x, y, z;

#define DRAW_BUF_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT / 10 * (LV_COLOR_DEPTH / 8))
uint32_t draw_buf[DRAW_BUF_SIZE / 4];

// ********  TFT display ********
TFT_eSPI tft = TFT_eSPI();

// ******** Temperature and humidity sensor ********
BME280<> BMESensor;    

MqttController mqttController(MQTT_BROKER, MQTT_PORT, MQTT_USER, MQTT_PASSWORD, MQTT_BASE_TOPIC);

// ************* EEZ-Studio Native global variables  *************
RegulationModes reg_mode;

int32_t pwm_heater;
int32_t pwm_fan;
int32_t pwm_led;

bool running;
bool wifi_connected;
bool mqtt_connected;
float current_temp;
float current_humi;
double remaining_time_sec;

int32_t reg_target_temp=50, reg_target_humi=30;


// ********  PID parameters ********
double PIDSetpoint, PIDInput, PIDOutput;

// Define the aggressive and conservative Tuning Parameters
double aggKp=4, aggKi=0.2, aggKd=1;
double consKp=1, consKi=0.05, consKd=0.25;
//Specify the links and initial tuning parameters
PID myPID(&PIDInput, &PIDOutput, &PIDSetpoint, consKp, consKi, consKd, DIRECT);






// ************* EEZ-Studio actions  *************

// If you define custom action to change pages, then you can use these

// void action_goto_page2(lv_event_t * e){
//   loadScreen(SCREEN_ID_PAGE1);
// }
//
// void action_goto_homek(lv_event_t * e){
//   loadScreen(SCREEN_ID_MAIN);
// }


// ** Define your vars getter and setter here, if native variables are used in your project **

// bool is_led_active = false;
//
// bool get_var_led_active()
// {
//   return is_led_active;
// }
//
// void set_var_led_active(bool value) {
//   is_led_active = value;
//
//   // Cheap Yellow Display built-in RGB LED is controlled with inverted logic
//   digitalWrite(CYD_LED_BLUE, value ? LOW : HIGH);
// }

double get_var_remaining_time_sec() {
    return remaining_time_sec;
}

void set_var_remaining_time_sec(double value) {
    remaining_time_sec = value;
}

int32_t get_var_reg_target_temp() {
    return reg_target_temp;
}

void set_var_reg_target_temp(int32_t value) {
    reg_target_temp = value;
}

int32_t get_var_reg_target_humi() {
    return reg_target_humi;
}

void set_var_reg_target_humi(int32_t value) {
    reg_target_humi = value;
}

RegulationModes get_var_reg_mode() {
    return reg_mode;
}

void set_var_reg_mode(RegulationModes value) {
    reg_mode = value;
}

int32_t get_var_pwm_led() {
    return pwm_led;
}

void set_var_pwm_led(int32_t value) {
    pwm_led = value;
}


int32_t get_var_pwm_fan() {
    return pwm_fan;
}

void set_var_pwm_fan(int32_t value) {
    pwm_fan = value;
}


int32_t get_var_pwm_heater() {
    return pwm_heater;
}

void set_var_pwm_heater(int32_t value) {
    pwm_heater = value;
}


float get_var_current_humi() {
    return current_humi;
}

void set_var_current_humi(float value) {
    current_humi = value;
}

float get_var_current_temp() {
    return current_temp;
}

void set_var_current_temp(float value) {
    current_temp = value;
}


bool get_var_mqtt_connected() {
    return mqtt_connected;
}

void set_var_mqtt_connected(bool value) {
    mqtt_connected = value;
}


bool get_var_wifi_connected() {
    return wifi_connected;
}

void set_var_wifi_connected(bool value) {
    wifi_connected = value;
}


bool get_var_running() {
    return running;
}

void set_var_running(bool value) {
    running = value;
}




// If logging is enabled, it will inform the user about what is happening in the library
void log_print(lv_log_level_t level, const char * buf) {
  LV_UNUSED(level);
  Serial.println(buf);
  Serial.flush();
}

// Get the Touchscreen data
void touchscreen_read(lv_indev_t * indev, lv_indev_data_t * data) {
  // Checks if Touchscreen was touched, and prints X, Y and Pressure (Z)
  // if(touchscreen.tirqTouched() && touchscreen.touched()) {
    if (touchscreen.touched()) {
    // Get Touchscreen points
    TS_Point p = touchscreen.getPoint();
    // Calibrate Touchscreen points with map function to the correct width and height
    x = map(p.x, 200, 3700, 1, SCREEN_WIDTH);
    y = map(p.y, 240, 3800, 1, SCREEN_HEIGHT);
    z = p.z;

    data->state = LV_INDEV_STATE_PRESSED;

    // Set the coordinates
    data->point.x = x;
    data->point.y = y;
    String touch_data = "X = " + String(x) + "  Y = " + String(y) + "  Z = " + String(z);
    Serial.println(touch_data);
  
  }
  else {
    data->state = LV_INDEV_STATE_RELEASED;
  }
}


// lvgl initialization for esp32 board
void lv_init_esp32(void) {

  // // Register print function for debugging
  lv_log_register_print_cb(log_print);

  // Start the SPI for the touchscreen and init the touchscreen
  touchscreenSPI.begin(XPT2046_CLK, XPT2046_MISO, XPT2046_MOSI, XPT2046_CS);
  
  touchscreen.begin(touchscreenSPI);
  
  // Set the Touchscreen rotation
  #ifdef TOUCH_INVERTED 
    touchscreen.setRotation(3);  // 2:vertical / 1|3:horizontal
  #else
    touchscreen.setRotation(1);  // 2:vertical / 1|3:horizontal
  #endif

  // Create a display object
  lv_display_t * disp;
  // Initialize the TFT display using the TFT_eSPI library
  disp = lv_tft_espi_create(SCREEN_WIDTH, SCREEN_HEIGHT, draw_buf, sizeof(draw_buf));

//   tft.init();  
  
  // set rotation mode
  //lv_display_set_rotation(NULL, LV_DISPLAY_ROTATION_90);
  #ifdef TFT_INVERTED
    tft.setRotation(1);  // 0 or 2 for  portrait / 1 or 3 for landscape
  #else
    tft.setRotation(3);  // 0 or 2 for  portrait / 1 or 3 for landscape
  #endif


  // Initialize an LVGL input device object (Touchscreen)
  lv_indev_t * indev = lv_indev_create();
  lv_indev_set_type(indev, LV_INDEV_TYPE_POINTER);
  // Set the callback function to read Touchscreen input
  lv_indev_set_read_cb(indev, touchscreen_read);


  // you can define TFT_COLOR_INVERTED as compiler param in platformio.ini
  #ifdef TFT_COLOR_INVERTED
    tft.invertDisplay(true);
  #else
    tft.invertDisplay(false);
  #endif

}

void setup() {
  String LVGL_Arduino = String("LVGL Library Version: ") + lv_version_major() + "." + lv_version_minor() + "." + lv_version_patch();

  //Serial.begin(115200, SERIAL_8N1, RXPIN, TXPIN);
  Serial.begin(115200);
  

  Serial.println(SW_NAME_REV);
  Serial.println(LVGL_Arduino);

  pinMode(HEATER_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  
  
  // Initialize BME280 sensor
  Wire.begin(21,22);                                                      // initialize I2C that connects to sensor
  BMESensor.begin();   


  // Start LVGL
  lv_init();

  // Init TFT and Touch for esp32
  lv_init_esp32();


  // Integrate EEZ Studio GUI
  ui_init();

  // Connect to WiFi and Broker
  mqttController.setRemoteCommandsCallback([](int cmd_mode, int cmd_heater_pwm, int cmd_fan_pwm, int cmd_led_pwm) { 
    if (cmd_mode >=0) reg_mode = RegulationModes(cmd_mode);
    if (reg_mode == RegulationModes::RegulationModes_REG_REMOTE) {
      if (cmd_heater_pwm >=0) pwm_heater = cmd_heater_pwm;
      if (cmd_fan_pwm >=0) pwm_fan = cmd_fan_pwm;
      if (cmd_led_pwm >=0) pwm_led = cmd_led_pwm;
    }

    Serial.println("cmd_mode: " + String(cmd_mode) + "  cmd_heater_pwm: " + String(pwm_heater) + "  cmd_fan_pwm: " + String(pwm_fan) + "  cmd_led_pwm: " + String(pwm_led));
  });
  
  mqttController.connectWifi(WIFI_SSID, WIFI_PASSWORD);

}

#define ASCII_ESC 27

#define MYALTITUDE  150.50

char bufout[10];

void read_sensor() {
  BMESensor.refresh();    
  
  current_temp = BMESensor.temperature;
  current_humi = BMESensor.humidity;
  
  /*                                              // read current sensor data
  sprintf(bufout,"%c[1;0H",ASCII_ESC);
  Serial.print(bufout);

  Serial.print("Temperature: ");
  Serial.print(BMESensor.temperature);                                  // display temperature in Celsius
  Serial.println("C");

  Serial.print("Humidity:    ");
  Serial.print(BMESensor.humidity);                                     // display humidity in %   
  Serial.println("%");
  */
  
}

void regulation_loop() {
  static auto reg_mode_prev = reg_mode;

  if (reg_mode == RegulationModes::RegulationModes_REG_OFF) {
    // all pwm values to 0 (except led)
    pwm_heater = 0;
    pwm_fan = 0;
  }
  else if (reg_mode == RegulationModes::RegulationModes_REG_TEMP) {
    // mantain target temperature

    if (!running) {
      pwm_fan = 0;
      pwm_heater = 0;
    }
    else {
      if (reg_mode != reg_mode_prev) {
        myPID.SetMode(AUTOMATIC);
        reg_mode_prev = reg_mode;
      }

      PIDSetpoint = reg_target_temp;
      PIDInput = current_temp;

      double gap = abs(PIDSetpoint-PIDInput);
      if (gap < 10) {
        //we're close to setpoint, use conservative tuning parameters
        myPID.SetTunings(consKp, consKi, consKd);
        pwm_fan = PWM_FAN_CONSERVATIVE;
      }
      else {
        //we're far from setpoint, use aggressive tuning parameters
        myPID.SetTunings(aggKp, aggKi, aggKd);
        pwm_fan = PWM_FAN_AGGRESSIVE;
      }
      myPID.Compute();

      pwm_heater = PIDOutput;
    }

  }
  else if (reg_mode == RegulationModes::RegulationModes_REG_HUMI) {
    // mantain target humidity  

    // TODO: complete this
  }
  else if (reg_mode == RegulationModes::RegulationModes_REG_REMOTE) {
    // apply pwm values already received from mqtt

  }
  else if (reg_mode == RegulationModes::RegulationModes_REG_MANUAL) {
    // not yet implementd
  }

  // apply PWM to pins
  analogWrite(HEATER_PIN, pwm_heater);
  analogWrite(FAN_PIN, pwm_fan);
  analogWrite(LED_PIN, pwm_led);
}

void loop() {
  const int SENSORS_POLLING_INTERVAL = 2000; // ms
  static long last_sensor_polling = 0;

  const int PUSH_DATA_INTERVAL = 2000; // ms
  static long last_push_data = 0;

  static long last_ms = 0;
  static float c_temp = 0.0;

  long now_ms = millis();

  if (now_ms - last_sensor_polling > SENSORS_POLLING_INTERVAL) {
    #ifndef IGNORE_SENSORS
    read_sensor();
    #else
    static float simulated_temp = 20;

    simulated_temp += random(-1, 3);


    current_temp = simulated_temp;
    current_humi = random(30, 40);
    #endif

    mqttController.pushSensors(current_temp, current_humi);

    last_sensor_polling = now_ms;
  }



  // Tick the mqtt controller to process connections and pub/subs
  mqttController.tick();

  mqttController.getConnectionStatus(&wifi_connected, &mqtt_connected);


  if (now_ms - last_push_data > PUSH_DATA_INTERVAL) {
    mqttController.pushData(reg_mode, 
    reg_mode == RegulationModes::RegulationModes_REG_TEMP ? reg_target_temp : reg_mode == RegulationModes::RegulationModes_REG_HUMI ? reg_target_humi : 0,
    pwm_heater, pwm_fan, pwm_led, 0);
    last_push_data = now_ms;
  }

  lv_task_handler();  // let the GUI do its work
  lv_tick_inc(now_ms - last_ms);     // tell LVGL how much time has passed
  ui_tick(); // uncomment if using eez-flow

  // Regulate heater, fan and led on the current selected mode
  regulation_loop();

  last_ms = now_ms;
  delay(5);           // let this time pass

}
