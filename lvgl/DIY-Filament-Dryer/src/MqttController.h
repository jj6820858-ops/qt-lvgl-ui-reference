#ifndef MQTT_CONTROLLER_H
#define MQTT_CONTROLLER_H   

#include <PicoMQTT.h>

#define MQTT_MAX_ERRORS 10
class MqttController
{
private:
    bool connection = false;

    String client_id ;
    String broker_address = "";
    String  wifi_ssid, wifi_password;
    String wifi_ip;
    bool wifi_connecting = false;
    bool wifi_connected = false;

    PicoMQTT::Client mqtt;
    String mqtt_broker;
    int  mqtt_port;
    String mqtt_user;
    String mqtt_password;
    bool mqtt_connecting = false;
    bool mqtt_connected = false;
    String mqtt_base_topic = "";

    int mqtt_errors = 0;
    unsigned long last_publish_time = 0;
    int greeting_number = 1;

    void mqtt_subscribe();
    void increment_mqtt_errors();

    void onConnectCallback(bool reconnect, const char *topic, uint8_t *payload, unsigned int length) {       }
    std::function<void()> mqtt_on_disconnect_callback_ ;
    std::function<void(int,int,int,int)> remote_cmd_callback_;




public:
    MqttController(String broker_address, int broker_port, String username, String password, String base_topic);
    ~MqttController();

    void setRemoteCommandsCallback(std::function<void(int,int,int,int)> callback) { remote_cmd_callback_ = callback; }
   
    void tick();

    void connectWifi(String ssid, String password);
    void getConnectionStatus(bool *wifi_connected,  bool *mqtt_connected);
    String getWifiIP();
    
    void pushSensors(float temp, float humi);
    void pushData(int mode, float target, int heater_pwm, int fan_pwm, int led_pwm, long remaining_time);
        
};



#endif