#include <Arduino.h>
#include <lvgl.h>
#include <TFT_eSPI.h>
#include <WiFi.h>
#include <PubSubClient.h>

// ---  WIFI and MQTT configuration ---
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";
const char* mqtt_server = "BROKER_IP_ADDRESS";
const char* mqtt_user = "BROKER_USERNAME";
const char* mqtt_pass = "BROKER_PASSWORD";

WiFiClient espClient;
PubSubClient client(espClient);

// Topic for Home Assistant Discovery ( "number" for bidirectional control )
const char* disc_topic = "homeassistant/number/termostato_lvgl/config";
const char* state_topic = "homeassistant/number/termostato_lvgl/state";
const char* cmd_topic   = "homeassistant/number/termostato_lvgl/set";

// --- DISPLAY configuration ---
static const uint16_t screenWidth  = 320;
static const uint16_t screenHeight = 240;
TFT_eSPI tft = TFT_eSPI(screenWidth, screenHeight); 
static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[screenWidth * 10];

lv_obj_t * screen_home, * meter, * temp_label, * slider_obj;
lv_meter_indicator_t * needle;

// --- MQTT functions ---

// Callback that triggers when you receive a message from Home Assistant
void mqtt_callback(char* topic, byte* payload, unsigned int length) {
    String msg;
    for (int i = 0; i < length; i++) msg += (char)payload[i];
    
    float val = msg.toFloat();
    int int_val = (int)val;

    // Aggiorna l'interfaccia LVGL (Lancetta, Testo, Slider)
    if (meter) lv_meter_set_indicator_value(meter, needle, int_val);
    if (temp_label) lv_label_set_text_fmt(temp_label, "%d°C", int_val);
    if (slider_obj) lv_slider_set_value(slider_obj, int_val, LV_ANIM_ON);
    
    
    client.publish(state_topic, msg.c_str(), true);
}

void send_mqtt_discovery() {
    client.setBufferSize(1024);
    
    
    String payload = "{";
    payload += "\"name\": \"Impostazione Termostato\",";
    payload += "\"stat_t\": \"" + String(state_topic) + "\",";
    payload += "\"cmd_t\": \"" + String(cmd_topic) + "\","; // Topic per ricevere comandi
    payload += "\"min\": -10,";
    payload += "\"max\": 50,";
    payload += "\"unit_of_meas\": \"°C\",";
    payload += "\"uniq_id\": \"esp32_termostato_01\",";
    payload += "\"dev\": {\"ids\": [\"esp32_lvgl_01\"], \"name\": \"ESP32 LVGL Panel\"}";
    payload += "}";

    client.publish(disc_topic, payload.c_str(), true);
    Serial.println("Discovery MQTT inviato!");
}

void reconnect() {
    while (!client.connected()) {
        Serial.print("Connessione MQTT...");
        if (client.connect("ESP32_LVGL_Client", mqtt_user, mqtt_pass)) {
            Serial.println("Connesso!");
            send_mqtt_discovery();
            client.subscribe(cmd_topic); // Sottoscrive il topic dei comandi
        } else {
            delay(5000);
        }
    }
}

// --- CALLBACK LVGL ---

void temp_slider_event_cb(lv_event_t * e) {
    lv_obj_t * slider = lv_event_get_target(e);
    int val = lv_slider_get_value(slider);

    lv_meter_set_indicator_value(meter, needle, val);
    lv_label_set_text_fmt(temp_label, "%d°C", val);

    // Invia il valore a Home Assistant
    if (client.connected()) {
        client.publish(state_topic, String(val).c_str(), true);
    }
}

// --- BUILD UI ---

void build_home_ui() {
    lv_obj_set_style_bg_color(screen_home, lv_color_hex(0x000000), 0);

    meter = lv_meter_create(screen_home);
    lv_obj_set_size(meter, 180, 180);
    lv_obj_align(meter, LV_ALIGN_CENTER, 0, -35);
    lv_obj_set_style_bg_opa(meter, 0, 0);
    lv_obj_set_style_border_width(meter, 0, 0);

    lv_meter_scale_t * scale = lv_meter_add_scale(meter);
    lv_meter_set_scale_ticks(meter, scale, 61, 1, 8, lv_palette_main(LV_PALETTE_GREY));
    lv_meter_set_scale_range(meter, scale, -10, 50, 240, 150);
    needle = lv_meter_add_needle_line(meter, scale, 4, lv_palette_main(LV_PALETTE_YELLOW), -10);

    temp_label = lv_label_create(screen_home);
    lv_label_set_text(temp_label, "20°C");
    lv_obj_set_style_text_color(temp_label, lv_color_white(), 0);
    lv_obj_set_style_text_font(temp_label, &lv_font_montserrat_20, 0);
    lv_obj_align(temp_label, LV_ALIGN_CENTER, 0, 0);

    slider_obj = lv_slider_create(screen_home); // Salvato in variabile globale
    lv_obj_set_size(slider_obj, 200, 6);
    lv_obj_align(slider_obj, LV_ALIGN_BOTTOM_MID, 0, -45);
    lv_slider_set_range(slider_obj, -10, 50);
    lv_slider_set_value(slider_obj, 20, LV_ANIM_OFF);
    lv_obj_set_style_pad_all(slider_obj, 8, LV_PART_KNOB);
    lv_obj_set_ext_click_area(slider_obj, 20);
    lv_obj_add_event_cb(slider_obj, temp_slider_event_cb, LV_EVENT_VALUE_CHANGED, NULL);
}

// --- SETUP and LOOP ---

void setup() {
    Serial.begin(115200);

    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    Serial.println("WiFi Connesso");

    client.setServer(mqtt_server, 1883);
    client.setCallback(mqtt_callback); // Imposta la funzione che riceve i dati

    tft.begin();
    tft.setRotation(1);
    uint16_t calData[5] = { 262, 3256, 455, 3332, 1 }; 
    tft.setTouch(calData);

    lv_init();
    lv_disp_draw_buf_init(&draw_buf, buf, NULL, screenWidth * 10);
    static lv_disp_drv_t disp_drv;
    lv_disp_drv_init(&disp_drv);
    disp_drv.hor_res = screenWidth; disp_drv.ver_res = screenHeight;
    disp_drv.flush_cb = [](lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p) {
        uint32_t w = (area->x2 - area->x1 + 1);
        uint32_t h = (area->y2 - area->y1 + 1);
        tft.startWrite();
        tft.setAddrWindow(area->x1, area->y1, w, h);
        tft.pushColors((uint16_t *)&color_p->full, w * h, true);
        tft.endWrite();
        lv_disp_flush_ready(disp);
    };
    disp_drv.draw_buf = &draw_buf;
    lv_disp_drv_register(&disp_drv);

    static lv_indev_drv_t indev_drv;
    lv_indev_drv_init(&indev_drv);
    indev_drv.type = LV_INDEV_TYPE_POINTER;
    indev_drv.read_cb = [](lv_indev_drv_t *drv, lv_indev_data_t *data) {
        uint16_t touchX, touchY;
        if (!tft.getTouch(&touchX, &touchY, 600)) data->state = LV_INDEV_STATE_REL;
        else {
            data->state = LV_INDEV_STATE_PR;
            data->point.x = map(touchX, 0, 250, 0, 320); 
            data->point.y = map(touchY, 0, 316, 0, 240);
        }
    };
    lv_indev_drv_register(&indev_drv);

    screen_home = lv_obj_create(NULL);
    build_home_ui();
    lv_scr_load(screen_home);
}

void loop() {
    if (!client.connected()) reconnect();
    client.loop(); // Gestisce i messaggi in arrivo

    static uint32_t last_tick = millis();
    if (millis() - last_tick > 5) {
        lv_tick_inc(millis() - last_tick);
        last_tick = millis();
    }
    lv_timer_handler(); 
    delay(5);
}