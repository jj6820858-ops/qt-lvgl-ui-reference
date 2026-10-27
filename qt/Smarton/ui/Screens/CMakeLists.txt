# QML module: SmarTon.Ui.Screens — full pages and the application shell.
#
# Screens compose everything below them and are the only UI module that knows
# what a "route" means. They receive view models as properties rather than
# importing SmarTon.Models, so every screen can be instantiated in a QML test
# against a plain QtObject stub.
qt_add_library(smarton_ui_screens STATIC)
add_library(SmarTonUi::screens ALIAS smarton_ui_screens)

st_add_qml_module(smarton_ui_screens
    URI     SmarTon.Ui.Screens
    VERSION 1.0
    NO_PLUGIN
    QML_FILES
        SplashScreen.qml
        WelcomeScreen.qml
        LoginScreen.qml
        VerifyCodeScreen.qml
        ResetPasswordScreen.qml
        SpacesScreen.qml
        RoomsScreen.qml
        MapViewScreen.qml
        LinkDeviceScreen.qml
        RoomOverviewScreen.qml
        DeviceDetailScreen.qml
        ScenariosScreen.qml
        StatisticsScreen.qml
        OperationsScreen.qml
        ProfileScreen.qml
        MembersScreen.qml
        SpaceWizardScreen.qml
        SceneWizardScreen.qml
        PlaceholderScreen.qml
        ShellScreen.qml
    IMPORTS
        QtQuick.Controls.Basic
        QtQuick.Dialogs
        SmarTon.Backend
        SmarTon.Ui.Helpers
        SmarTon.Ui.Theme
        SmarTon.Ui.Controls
        SmarTon.Ui.Layouts
        SmarTon.Ui.Components
        SmarTon.Ui.Navigation
        SmarTon.Ui.Dialogs
)

# Linked, not imported. The Rooms screen loads the 3D view by URL (see the
# Loader there for why), but the module still has to be in the binary for that
# URL to resolve - a resource nothing links against is not compiled in.
if(TARGET SmarTonUi::map3d)
    target_link_libraries(smarton_ui_screens PUBLIC SmarTonUi::map3d)
endif()

target_link_libraries(smarton_ui_screens
    PUBLIC
        SmarTonUi::helpers
        SmarTonUi::components
        SmarTonUi::navigation
        SmarTonUi::dialogs
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::QuickDialogs2
    PRIVATE
        SmarTon::compile_settings
)
