#include "styles.h"
#include "images.h"
#include "fonts.h"

#include "ui.h"
#include "screens.h"

//
// Style: sensorMain
//

void init_style_sensor_main_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_text_font(style, &ui_font_digital7_44);
    lv_style_set_text_align(style, LV_TEXT_ALIGN_RIGHT);
};

lv_style_t *get_style_sensor_main_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_sensor_main_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_sensor_main(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_sensor_main_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_sensor_main(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_sensor_main_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: sensorUm
//

void init_style_sensor_um_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_text_font(style, &lv_font_montserrat_28);
};

lv_style_t *get_style_sensor_um_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_sensor_um_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_sensor_um(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_sensor_um_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_sensor_um(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_sensor_um_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: pwm
//

void init_style_pwm_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_text_font(style, &lv_font_montserrat_14);
    lv_style_set_text_letter_space(style, 0);
    lv_style_set_text_align(style, LV_TEXT_ALIGN_CENTER);
};

lv_style_t *get_style_pwm_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_pwm_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_pwm(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_pwm_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_pwm(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_pwm_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: buttonMode
//

void init_style_button_mode_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_radius(style, 4);
    lv_style_set_bg_color(style, lv_color_hex(0xff858382));
};

lv_style_t *get_style_button_mode_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_button_mode_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_button_mode(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_button_mode_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_button_mode(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_button_mode_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: buttonMode1
//

void init_style_button_mode1_MAIN_DEFAULT(lv_style_t *style) {
    init_style_button_mode_MAIN_DEFAULT(style);
    
    lv_style_set_bg_color(style, lv_color_hex(0xff024d20));
};

lv_style_t *get_style_button_mode1_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_button_mode1_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_button_mode1(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_button_mode1_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_button_mode1(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_button_mode1_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: buttonMode2
//

void init_style_button_mode2_MAIN_DEFAULT(lv_style_t *style) {
    init_style_button_mode_MAIN_DEFAULT(style);
    
    lv_style_set_bg_color(style, lv_color_hex(0xff3636da));
};

lv_style_t *get_style_button_mode2_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_button_mode2_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_button_mode2(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_button_mode2_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_button_mode2(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_button_mode2_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: buttonMode3
//

void init_style_button_mode3_MAIN_DEFAULT(lv_style_t *style) {
    init_style_button_mode_MAIN_DEFAULT(style);
    
    lv_style_set_bg_color(style, lv_color_hex(0xffdc642a));
};

lv_style_t *get_style_button_mode3_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_button_mode3_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_button_mode3(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_button_mode3_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_button_mode3(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_button_mode3_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: target
//

void init_style_target_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_text_font(style, &lv_font_montserrat_16);
    lv_style_set_text_align(style, LV_TEXT_ALIGN_CENTER);
};

lv_style_t *get_style_target_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_target_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_target(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_target_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_target(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_target_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
// Style: ButtonOkCancel
//

void init_style_button_ok_cancel_MAIN_DEFAULT(lv_style_t *style) {
    lv_style_set_bg_color(style, lv_color_hex(0xff00400a));
    lv_style_set_text_font(style, &lv_font_montserrat_28);
};

lv_style_t *get_style_button_ok_cancel_MAIN_DEFAULT() {
    static lv_style_t *style;
    if (!style) {
        style = lv_malloc(sizeof(lv_style_t));
        lv_style_init(style);
        init_style_button_ok_cancel_MAIN_DEFAULT(style);
    }
    return style;
};

void add_style_button_ok_cancel(lv_obj_t *obj) {
    (void)obj;
    lv_obj_add_style(obj, get_style_button_ok_cancel_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

void remove_style_button_ok_cancel(lv_obj_t *obj) {
    (void)obj;
    lv_obj_remove_style(obj, get_style_button_ok_cancel_MAIN_DEFAULT(), LV_PART_MAIN | LV_STATE_DEFAULT);
};

//
//
//

void add_style(lv_obj_t *obj, int32_t styleIndex) {
    typedef void (*AddStyleFunc)(lv_obj_t *obj);
    static const AddStyleFunc add_style_funcs[] = {
        add_style_sensor_main,
        add_style_sensor_um,
        add_style_pwm,
        add_style_button_mode,
        add_style_button_mode1,
        add_style_button_mode2,
        add_style_button_mode3,
        add_style_target,
        add_style_button_ok_cancel,
    };
    add_style_funcs[styleIndex](obj);
}

void remove_style(lv_obj_t *obj, int32_t styleIndex) {
    typedef void (*RemoveStyleFunc)(lv_obj_t *obj);
    static const RemoveStyleFunc remove_style_funcs[] = {
        remove_style_sensor_main,
        remove_style_sensor_um,
        remove_style_pwm,
        remove_style_button_mode,
        remove_style_button_mode1,
        remove_style_button_mode2,
        remove_style_button_mode3,
        remove_style_target,
        remove_style_button_ok_cancel,
    };
    remove_style_funcs[styleIndex](obj);
}

