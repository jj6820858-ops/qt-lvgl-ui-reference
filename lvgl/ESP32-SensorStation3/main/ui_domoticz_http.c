// Copyright 2026 Viacheslav Korniienko
// Licensed under the Apache License, Version 2.0 — see LICENSE file

#include "ui.h"
#include "nvs_settings.h"
#include "lvgl.h"
#include "esp_log.h"
#include <stdio.h>
#include <stdlib.h>

static const char *TAG = "ui_dz_http";

/* Same geometry/keyboard-scroll scheme as ui_domoticz.c's overlays. */
#define HDR_H            38
#define CONTENT_FULL_H   (320 - HDR_H)
#define CONTENT_VISIBLE_H (320 - HDR_H - 140)

static lv_obj_t *s_overlay, *s_content, *s_kbd;
static lv_obj_t *s_ta_url, *s_ta_user, *s_ta_pass, *s_ta_thp, *s_ta_co2;

static void ta_focused_cb(lv_event_t *e)
{
    lv_obj_t *ta = lv_event_get_target(e);
    lv_keyboard_set_mode(s_kbd, (ta == s_ta_thp || ta == s_ta_co2)
                         ? LV_KEYBOARD_MODE_NUMBER : LV_KEYBOARD_MODE_TEXT_LOWER);
    lv_keyboard_set_textarea(s_kbd, ta);
    lv_obj_set_hidden(s_kbd, false);
    lv_obj_set_height(s_content, CONTENT_VISIBLE_H);
    lv_obj_scroll_to_view_recursive(ta, LV_ANIM_ON);
}

static void kbd_done_cb(lv_event_t *e)
{
    (void)e;
    lv_obj_set_hidden(s_kbd, true);
    lv_keyboard_set_textarea(s_kbd, NULL);
    lv_obj_set_height(s_content, CONTENT_FULL_H);
    lv_obj_scroll_to_y(s_content, 0, LV_ANIM_ON);
}

static void save_cb(lv_event_t *e)
{
    (void)e;
    nvs_dz_push_t c = {0};
    snprintf(c.url,  sizeof(c.url),  "%s", lv_textarea_get_text(s_ta_url));
    snprintf(c.user, sizeof(c.user), "%s", lv_textarea_get_text(s_ta_user));
    snprintf(c.pass, sizeof(c.pass), "%s", lv_textarea_get_text(s_ta_pass));
    c.thp_idx = (uint16_t)atoi(lv_textarea_get_text(s_ta_thp));
    c.co2_idx = (uint16_t)atoi(lv_textarea_get_text(s_ta_co2));
    nvs_settings_set_dz_push(&c);
    ESP_LOGI(TAG, "saved url=%s user=%s thp=%u co2=%u", c.url, c.user,
             (unsigned)c.thp_idx, (unsigned)c.co2_idx);
}

static void back_cb(lv_event_t *e)
{
    (void)e;
    if (!s_overlay) return;
    lv_obj_delete(s_overlay);
    s_overlay = NULL;
}

static void hist_cb(lv_event_t *e)
{
    (void)e;
    back_cb(NULL);   /* siblings under lv_layer_top() — only one at a time */
    ui_domoticz_history_show_from_http();
}

static lv_obj_t *add_ta(const char *placeholder, const char *text, int y, uint32_t maxlen, bool pwd)
{
    lv_obj_t *ta = lv_textarea_create(s_content);
    lv_obj_set_size(ta, 224, 30);
    lv_obj_align(ta, LV_ALIGN_TOP_MID, 0, y);
    lv_textarea_set_one_line(ta, true);
    lv_textarea_set_max_length(ta, maxlen);
    lv_textarea_set_placeholder_text(ta, placeholder);
    lv_textarea_set_password_mode(ta, pwd);
    lv_textarea_set_text(ta, text);
    lv_obj_add_event_cb(ta, ta_focused_cb, LV_EVENT_FOCUSED, NULL);
    return ta;
}

void ui_domoticz_http_show(void)
{
    if (s_overlay) return;

    nvs_dz_push_t c;
    nvs_settings_get_dz_push(&c);
    char thp[8], co2[8];
    snprintf(thp, sizeof(thp), "%u", (unsigned)c.thp_idx);
    snprintf(co2, sizeof(co2), "%u", (unsigned)c.co2_idx);

    s_overlay = lv_obj_create(lv_layer_top());
    lv_obj_set_scrollable(s_overlay, false);
    lv_obj_set_size(s_overlay, 240, 320);
    lv_obj_set_pos(s_overlay, 0, 0);
    lv_obj_set_style_bg_color(s_overlay, lv_color_black(), 0);
    lv_obj_set_style_bg_opa(s_overlay, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(s_overlay, 0, 0);
    lv_obj_set_style_pad_all(s_overlay, 0, 0);

    lv_obj_t *hdr = lv_obj_create(s_overlay);
    lv_obj_set_scrollable(hdr, false);
    lv_obj_set_size(hdr, 240, HDR_H);
    lv_obj_set_pos(hdr, 0, 0);
    lv_obj_set_style_bg_color(hdr, lv_color_make(0, 40, 50), 0);
    lv_obj_set_style_bg_opa(hdr, LV_OPA_COVER, 0);
    lv_obj_set_style_border_width(hdr, 0, 0);
    lv_obj_set_style_pad_all(hdr, 0, 0);

    lv_obj_t *title = lv_label_create(hdr);
    lv_label_set_text(title, LV_SYMBOL_SETTINGS " Domoticz HTTP");
    lv_obj_set_style_text_color(title, lv_color_white(), 0);
    lv_obj_align(title, LV_ALIGN_LEFT_MID, 8, 0);

    lv_obj_t *back_btn = lv_button_create(hdr);
    lv_obj_set_size(back_btn, 60, 28);
    lv_obj_align(back_btn, LV_ALIGN_RIGHT_MID, -4, 0);
    lv_obj_set_style_bg_color(back_btn, lv_color_make(60, 30, 30), 0);
    lv_obj_add_event_cb(back_btn, back_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t *back_lbl = lv_label_create(back_btn);
    lv_label_set_text(back_lbl, LV_SYMBOL_LEFT " Back");
    lv_obj_center(back_lbl);

    s_content = lv_obj_create(s_overlay);
    lv_obj_set_size(s_content, 240, CONTENT_FULL_H);
    lv_obj_set_pos(s_content, 0, HDR_H);
    lv_obj_set_scroll_dir(s_content, LV_DIR_VER);
    lv_obj_set_style_bg_opa(s_content, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(s_content, 0, 0);
    lv_obj_set_style_pad_all(s_content, 0, 0);

    lv_obj_t *hint = lv_label_create(s_content);
    lv_label_set_text(hint, "Domoticz web API (not MQTT).\nIDX 0 = skip that device.");
    lv_obj_set_style_text_color(hint, lv_palette_main(LV_PALETTE_GREY), 0);
    lv_obj_set_width(hint, 224);
    lv_obj_align(hint, LV_ALIGN_TOP_LEFT, 8, 4);

    s_ta_url  = add_ta("Base URL: http://host:port", c.url, 40, sizeof(c.url) - 1, false);
    s_ta_user = add_ta("Username (optional)", c.user, 74, sizeof(c.user) - 1, false);
    s_ta_pass = add_ta("Password (optional)", c.pass, 108, sizeof(c.pass) - 1, true);
    s_ta_thp  = add_ta("Temp/Hum/Baro device IDX", thp, 142, 5, false);
    s_ta_co2  = add_ta("Air Quality/CO2 device IDX", co2, 176, 5, false);

    lv_obj_t *save_btn = lv_button_create(s_content);
    lv_obj_set_size(save_btn, 224, 36);
    lv_obj_align(save_btn, LV_ALIGN_TOP_MID, 0, 214);
    lv_obj_set_style_bg_color(save_btn, lv_palette_main(LV_PALETTE_GREEN), 0);
    lv_obj_add_event_cb(save_btn, save_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t *save_lbl = lv_label_create(save_btn);
    lv_label_set_text(save_lbl, LV_SYMBOL_OK " Save");
    lv_obj_center(save_lbl);

    lv_obj_t *hist_btn = lv_button_create(s_content);
    lv_obj_set_size(hist_btn, 224, 36);
    lv_obj_align(hist_btn, LV_ALIGN_TOP_MID, 0, 258);
    lv_obj_add_event_cb(hist_btn, hist_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t *hist_lbl = lv_label_create(hist_btn);
    lv_label_set_text(hist_lbl, LV_SYMBOL_SETTINGS " History Chart Source");
    lv_obj_center(hist_lbl);

    s_kbd = lv_keyboard_create(s_overlay);
    lv_obj_set_size(s_kbd, 240, 140);
    lv_obj_align(s_kbd, LV_ALIGN_BOTTOM_MID, 0, 0);
    lv_obj_set_hidden(s_kbd, true);
    lv_obj_add_event_cb(s_kbd, kbd_done_cb, LV_EVENT_READY,  NULL);
    lv_obj_add_event_cb(s_kbd, kbd_done_cb, LV_EVENT_CANCEL, NULL);
}
