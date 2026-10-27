# A second executable that renders every control in isolation.
#
# The gallery is the cheapest quality tool in a component library: it proves
# each control works without the application around it, gives designers
# something to review, and makes an unusable component obvious immediately.
qt_add_executable(smarton_gallery main.cpp)

st_add_qml_module(smarton_gallery
    URI     SmarTon.Gallery
    VERSION 1.0
    QML_FILES
        qml/GalleryMain.qml
    IMPORTS
        QtQuick.Effects
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
        SmarTon.Ui.Layouts
        SmarTon.Ui.Components
)

target_link_libraries(smarton_gallery PRIVATE
    SmarTon::resources
    SmarTonUi::components
    SmarTonUi::layouts
    SmarTonUi::controls
    SmarTonUi::theme
    Qt6::Quick
    Qt6::QuickControls2
)
