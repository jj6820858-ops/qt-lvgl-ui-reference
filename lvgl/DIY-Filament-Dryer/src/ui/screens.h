#ifndef EEZ_LVGL_UI_SCREENS_H
#define EEZ_LVGL_UI_SCREENS_H

#include <lvgl.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _objects_t {
    lv_obj_t *main;
    lv_obj_t *set_target;
    lv_obj_t *set_timer;
    lv_obj_t *button_mode;
    lv_obj_t *label_wifi;
    lv_obj_t *label_mqtt;
    lv_obj_t *label_time;
    lv_obj_t *panel_target;
    lv_obj_t *button_start;
    lv_obj_t *button_stop;
    lv_obj_t *msgbox_long_press;
    lv_obj_t *obj0;
    lv_obj_t *obj1;
    lv_obj_t *obj2;
    lv_obj_t *obj3;
    lv_obj_t *obj4;
    lv_obj_t *obj5;
    lv_obj_t *label_mode;
    lv_obj_t *button_settings;
    lv_obj_t *label_humi;
    lv_obj_t *label_temp;
    lv_obj_t *label_target;
    lv_obj_t *cont_heater_fan;
    lv_obj_t *label_pwm_heater;
    lv_obj_t *label_pwm_fan;
    lv_obj_t *cont_start;
    lv_obj_t *obj6;
    lv_obj_t *obj7;
    lv_obj_t *obj8;
    lv_obj_t *obj9;
    lv_obj_t *obj10;
    lv_obj_t *obj11;
    lv_obj_t *obj12;
    lv_obj_t *obj13;
    lv_obj_t *obj14;
    lv_obj_t *obj15;
    lv_obj_t *obj16;
    lv_obj_t *obj17;
    lv_obj_t *obj18;
    lv_obj_t *obj19;
} objects_t;

extern objects_t objects;

enum ScreensEnum {
    SCREEN_ID_MAIN = 1,
    SCREEN_ID_SET_TARGET = 2,
    SCREEN_ID_SET_TIMER = 3,
};

void create_screen_main();
void tick_screen_main();

void create_screen_set_target();
void tick_screen_set_target();

void create_screen_set_timer();
void tick_screen_set_timer();

void tick_screen_by_id(enum ScreensEnum screenId);
void tick_screen(int screen_index);

void create_screens();


#ifdef __cplusplus
}
#endif

#endif /*EEZ_LVGL_UI_SCREENS_H*/