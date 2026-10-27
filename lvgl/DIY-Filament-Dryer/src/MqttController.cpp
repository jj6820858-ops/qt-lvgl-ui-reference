#include "MqttController.h"

MqttController::MqttController(String broker_address, int broker_port, String username, String password, String base_topic)
{
    mqtt_broker = broker_address;
    mqtt_port = broker_port;
    mqtt_user = username;    
    mqtt_password = password;    
    mqtt_base_topic = base_topic;
        
    //assign mqtt callbacks and subscribe once
    mqtt.connected_callback = [this] {
                this->mqtt_connecting = false;
                this->mqtt_connected = true;
                Serial.println("MQTT connected");
            };

    mqtt.disconnected_callback = [this] {
            this->mqtt_connecting = false;
            this->mqtt_connected = false;
            Serial.println("MQTT disconnected");
            if (mqtt_on_disconnect_callback_)
                mqtt_on_disconnect_callback_();
        };
    mqtt_subscribe();

    connection = false;
}

MqttController::~MqttController()
{
    
}



void MqttController::connectWifi(String ssid, String password) {

    wifi_ssid = ssid;
    wifi_password = password;
    wifi_connecting = false;
    wifi_connected = false;
    connection = true;
}

void MqttController::tick() {

    if (connection) {

        // connection_required, test wifi
        if (!wifi_connecting) {
            wifi_connected = (WiFi.status() == WL_CONNECTED); 
        }

        if (!wifi_connected) {
            if (!wifi_connecting) {
                Serial.print("Connecting to WiFi SSID: ");
                Serial.println(wifi_ssid);
                wifi_connecting = true;
                WiFi.begin(wifi_ssid.c_str(), wifi_password.c_str());
            }
            else {
                //TODO: manage timeout
                if (WiFi.status() == WL_CONNECTED) {
                    Serial.println("WiFi connected");
                    Serial.println("IP address: ");
                    wifi_ip = WiFi.localIP().toString();
                    Serial.println(wifi_ip);
                    wifi_connecting = false;
                    wifi_connected = true;

                    // When connected to wifi, subscribe to topic and connect to MQTT Broker
                    mqtt_connecting = false;
                    mqtt_connected = false;
                }
                else {
                    Serial.print(".");    
                }
            }
        }
        else if (!mqtt_connecting) {
            //TODO: manage timeout
           

            mqtt.host = mqtt_broker;
            mqtt.port = mqtt_port;

            // TODO: auth management
            mqtt.username = mqtt_user;
            mqtt.password = mqtt_password;
            
            Serial.println("Connect to MQTT Broker ");
            mqtt.begin();
            mqtt_connecting = true;                    

        }
        else {
            mqtt.loop();
        }

    }
}

void MqttController::mqtt_subscribe() {

    mqtt.subscribe(mqtt_base_topic + "/commands/#", [this](const char * topic, const char * payload) {
        bool done = false;
        int cmd_mode = -1;
        int cmd_heater_pwm = -1;
        int cmd_fan_pwm = -1;
        int cmd_led_pwm = -1;

        // payload might be binary, but PicoMQTT guarantees that it's zero-terminated
        // Serial.printf("Received message in topic '%s': %s    - pwm %d  -   %d\n", topic, payload, cmd_heater_pwm, cmd_fan_pwm);

        // test if override mode command received
        String cmd_topic = this->mqtt_base_topic + "/commands/remote_mode_override";
        if (strncmp(topic, cmd_topic.c_str(), strlen(cmd_topic.c_str())) == 0) {
            int value = atoi(payload);
            Serial.print("Override mode: ");
            Serial.println(value);
            cmd_mode = value = (value > 3) ? 3 : ((value < 0) ? 0 : value);;
            done = true;
        }

        // test if heater_pwm mode command received
        cmd_topic = this->mqtt_base_topic + "/commands/heater_pwm";
        if ((!done) && (strncmp(topic, cmd_topic.c_str(), strlen(cmd_topic.c_str())) == 0)) {
            int value = atoi(payload);
            Serial.print("PWM heater: ");
            Serial.println(value);
            cmd_heater_pwm = value = (value > 255) ? 255 : ((value < 0) ? 0 : value);
            done = true;
        }

        // test if fan_pwm mode command received
        cmd_topic = this->mqtt_base_topic + "/commands/fan_pwm";
        if ((!done) && (strncmp(topic, cmd_topic.c_str(), strlen(cmd_topic.c_str())) == 0)) {
            int value = atoi(payload);
            Serial.print("PWM fan: ");
            Serial.println(value);
            cmd_fan_pwm = value = (value > 255) ? 255 : ((value < 0) ? 0 : value);
            done = true;
        }

        // test if led_pwm mode command received
        cmd_topic = this->mqtt_base_topic + "/commands/led_pwm";
        if ((!done) && (strncmp(topic, cmd_topic.c_str(), strlen(cmd_topic.c_str())) == 0)) {
            int value = atoi(payload);
            Serial.print("PWM led: ");
            Serial.println(value);
            cmd_led_pwm = value = (value > 255) ? 255 : ((value < 0) ? 0 : value);
            done = true;
        }


        if (done && remote_cmd_callback_) {
            remote_cmd_callback_(cmd_mode, cmd_heater_pwm, cmd_fan_pwm, cmd_led_pwm);
        }

    });
    
}


void MqttController::getConnectionStatus(bool *wifi_connected_,  bool *mqtt_connected_) {
    *wifi_connected_ = this->wifi_connected;
    *mqtt_connected_ = this->mqtt_connected;
}

void MqttController::pushSensors(float temp, float humi){
    if (mqtt_connected) {
    if (!mqtt.publish(mqtt_base_topic + "/sensors", "{\"temp\": " + String(temp) + ", \"humi\": " + String(humi) + "}", 1U)) {
        increment_mqtt_errors();
    }
    }
}

void MqttController::pushData(int mode, float target, int heater_pwm, int fan_pwm, int led_pwm, long remaining_time) {
    static auto mode_prev = -1;
    if (mqtt_connected) {
        if (!mqtt.publish(mqtt_base_topic + "/rtdata", 
            "{\"mode\": " + String(mode) + 
            ", \"target\": " + String(target) + 
            ", \"heater_pwm\": " + String(heater_pwm) + 
            ", \"fan_pwm\": " + String(fan_pwm) + 
            ", \"led_pwm\": " + String(led_pwm) + 
            ", \"remaining_time\": " + String(remaining_time) + 
            "}", 1U)) {
                increment_mqtt_errors();
            }
        

        if (mode != mode_prev) {
            mqtt.publish(mqtt_base_topic + "/reg_mode", String(mode), 1U);
            mode_prev = mode;
        }
    }
}

void MqttController::increment_mqtt_errors() {
    mqtt_errors++;
    Serial.println("mqtt errors: " + String(mqtt_errors));
    if (mqtt_errors > MQTT_MAX_ERRORS) {
        mqtt.disconnect();
        mqtt_errors = 0;
        
        //TODO: may be the wifi reset is required only if the mqtt errors persist

        // reset all connections and retry to reconnect
        wifi_connected = false;
        wifi_connecting = false;
        mqtt_connected = false;
        mqtt_connecting = false;
    }
}