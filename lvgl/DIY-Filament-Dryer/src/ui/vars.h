#ifndef EEZ_LVGL_UI_VARS_H
#define EEZ_LVGL_UI_VARS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// enum declarations

typedef enum {
    RegulationModes_REG_OFF = 0,
    RegulationModes_REG_TEMP = 1,
    RegulationModes_REG_HUMI = 2,
    RegulationModes_REG_REMOTE = 3,
    RegulationModes_REG_MANUAL = 4
} RegulationModes;

// Flow global variables

enum FlowGlobalVariables {
    FLOW_GLOBAL_VARIABLE_COUNTER = 0,
    FLOW_GLOBAL_VARIABLE_TIMER = 1
};

// Native global variables

extern bool get_var_running();
extern void set_var_running(bool value);
extern bool get_var_wifi_connected();
extern void set_var_wifi_connected(bool value);
extern bool get_var_mqtt_connected();
extern void set_var_mqtt_connected(bool value);
extern float get_var_current_temp();
extern void set_var_current_temp(float value);
extern float get_var_current_humi();
extern void set_var_current_humi(float value);
extern int32_t get_var_pwm_heater();
extern void set_var_pwm_heater(int32_t value);
extern int32_t get_var_pwm_fan();
extern void set_var_pwm_fan(int32_t value);
extern int32_t get_var_pwm_led();
extern void set_var_pwm_led(int32_t value);
extern RegulationModes get_var_reg_mode();
extern void set_var_reg_mode(RegulationModes value);
extern int32_t get_var_reg_target_temp();
extern void set_var_reg_target_temp(int32_t value);
extern int32_t get_var_reg_target_humi();
extern void set_var_reg_target_humi(int32_t value);
extern double get_var_remaining_time_sec();
extern void set_var_remaining_time_sec(double value);



#ifdef __cplusplus
}
#endif

#endif /*EEZ_LVGL_UI_VARS_H*/