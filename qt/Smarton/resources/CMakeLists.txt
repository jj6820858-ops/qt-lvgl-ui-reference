# Non-code assets bundled into the binary. Kept in one target so the asset list
# is reviewable in a diff and the same assets serve the app and the gallery.
#
# Paths below resolve at runtime as
#     qrc:/qt/qml/SmarTon/Resources/<path as listed>
# because st_add_qml_module() sets RESOURCE_PREFIX /qt/qml and the URI is
# SmarTon.Resources. Screens use that full URL rather than a relative path, so
# an asset moving between folders is a one-line change here plus a grep.
qt_add_library(smarton_resources STATIC)
add_library(SmarTon::resources ALIAS smarton_resources)

st_add_qml_module(smarton_resources
    URI     SmarTon.Resources
    VERSION 1.0
    NO_PLUGIN
    RESOURCES
        config/defaults.json
        config/home-seed.json
        icons/ui/back.svg
        icons/ui/battery.svg
        icons/ui/bulb.svg
        icons/ui/bell.svg
        icons/ui/check.svg
        icons/ui/chevronDown.svg
        icons/ui/chevronUp.svg
        icons/ui/close.svg
        icons/ui/devices.svg
        icons/ui/edit.svg
        icons/ui/eye.svg
        icons/ui/eyeOff.svg
        icons/ui/forward.svg
        icons/ui/home.svg
        icons/ui/humidity.svg
        icons/ui/image.svg
        icons/ui/link.svg
        icons/ui/logout.svg
        icons/ui/members.svg
        icons/ui/modeCold.svg
        icons/ui/modeSleep.svg
        icons/ui/modeSwing.svg
        icons/ui/modeWind.svg
        icons/ui/music.svg
        icons/ui/more.svg
        icons/ui/pause.svg
        icons/ui/play.svg
        icons/ui/plus.svg
        icons/ui/rooms.svg
        icons/ui/search.svg
        icons/ui/settings.svg
        icons/ui/skipBack.svg
        icons/ui/skipForward.svg
        icons/ui/statistics.svg
        icons/ui/temperature.svg
        icons/ui/trash.svg
        icons/ui/volume.svg
        icons/ui/weatherPartlyCloudy.svg
        icons/humidity.png
        icons/temperature.svg
        icons/tile-lighting.png
        icons/tile-music.png
        icons/weather-partly-cloudy.png
        images/avatars/default-profile.jpeg
        images/brand/deco-lines.png
        images/brand/radial-falloff.png
        images/brand/logo-splash.png
        images/brand/logo-wordmark.png
        images/devices/air-purifier.png
        images/devices/badge-air-purifier.png
        images/devices/badge-pendant-lamp.png
        images/devices/badge-placeholder.png
        images/devices/badge-sensor-hub.png
        images/devices/ceiling-lamp.png
        images/devices/pendant-lamp-teal.png
        images/devices/pendant-lamp.png
        images/devices/sensor-hub.png
        images/devices/smart-speaker.png
        images/devices/speaker.png
        images/illustrations/empty-spaces.png
        images/illustrations/smart-home.png
        images/illustrations/smart-house-devices.png
        images/rooms/bathroom-tub-sm.png
        images/rooms/bathroom-tub.png
        images/rooms/bedroom-bed-sm.png
        images/rooms/bedroom-bed.png
        images/rooms/house-exterior.png
        images/rooms/kitchen-hob-sm.png
        images/rooms/kitchen-hob.png
        images/rooms/living-bordered.png
        images/rooms/living-interior.png
        images/rooms/living-sofa-sm.png
        images/rooms/living-sofa.png
        images/rooms/lounge-framed.png
)

target_link_libraries(smarton_resources
    PUBLIC  Qt6::Qml
    PRIVATE SmarTon::compile_settings
)
