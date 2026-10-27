// Copyright 2026 Viacheslav Korniienko
// Licensed under the Apache License, Version 2.0 — see LICENSE file

#pragma once
#include "esp_err.h"
#include <stdbool.h>

/* Call once from app_main after wifi_manager_init().
 * Reads broker URI, enabled flag, and device IDX values from NVS.
 * A no-op returning ESP_OK if disabled, URI empty, or no IDX configured.
 * Connection is deferred until the first IP_EVENT_STA_GOT_IP event. */
esp_err_t domoticz_mqtt_init(void);

/* Re-read NVS and (re)start the MQTT client immediately.
 * Call after the user saves Domoticz settings via the UI. */
esp_err_t domoticz_mqtt_start(void);

/* Disconnect and stop publishing. Safe to call when not running. */
void domoticz_mqtt_stop(void);

/* True while the MQTT session with the Domoticz broker is established. */
bool domoticz_mqtt_is_connected(void);


/* True if the last HTTP (JSON API) push to Domoticz succeeded. The HTTP push
 * task starts in domoticz_mqtt_init(), is gated by the dz_http_en setting and
 * uses its own dz_hp_* URL/credentials/IDX settings. */
bool domoticz_http_last_ok(void);
