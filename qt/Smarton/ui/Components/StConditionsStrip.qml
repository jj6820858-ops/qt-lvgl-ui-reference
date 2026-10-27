import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StConditionsStrip
    \inqmlmodule SmarTon.Ui.Components
    \brief Weather, humidity and two quick actions. Figma frame 07.

    Sits inside the header band, below the title row.

    FOUR TILES, NOT THREE. The frame draws weather and humidity inside one
    card, and that grouping was reproduced literally. It does not survive
    contact with the panel: at 1024 px the shared card has to hold two icons,
    two captions and two values, so its contents were centred as a clump and
    the two readings ran together with no boundary between them. One tile per
    fact reads at a glance and gives every tile the same anatomy, which is what
    lets them share a delegate and a scroll.

    SCROLLS HORIZONTALLY. Four tiles at a legible size do not fit 1024 px, and
    the alternative to scrolling is shrinking them until the captions elide.
    A flick is the right answer on a touch panel; the design was drawn at 1440
    where the question does not arise.

    ALIGNMENT. Content is left-aligned against a fixed inset and vertically
    centred. Centring the content horizontally - which is what it did before -
    makes every tile's text start at a different x, so the four captions do not
    line up with each other and the strip reads as scattered.
*/
Item {
    id: root

    property string weatherDescription: ""
    property int    temperature: 0
    property int    humidity: 0
    property bool   allLightsOn: false
    property string musicRoom: ""

    signal lightsToggled()
    signal musicRequested()

    /*! Measured 100 on the 1440 frame. Reduced to 76: the frame's height came
        from a 48 px icon stacked against two lines of text with generous
        padding, and on a 600 px panel that band was eating an eighth of the
        screen to show four short facts. 76 keeps the two lines and the touch
        target and drops only the air. */
    readonly property int tileHeight: 76
    readonly property int tileWidth: 268
    /*! Left inset for tile content. One value, so all four line up. */
    readonly property int tileInset: Theme.spacing4

    implicitHeight: root.tileHeight

    ListView {
        id: strip

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Theme.spacing3
        // The tiles ARE the content; a bar under them would sit on the header
        // artwork. StopAtBounds keeps the flick from bouncing, which on an
        // appliance panel reads as a glitch rather than as a phone idiom.
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500
        pixelAligned: true
        clip: true

        model: [
            {
                kind: "reading", action: "", glyph: "weatherPartlyCloudy",
                caption: root.weatherDescription,
                value: qsTr("%1°").arg(root.temperature)
            },
            {
                kind: "reading", action: "", glyph: "humidity",
                caption: qsTr("Humidity"),
                value: qsTr("%1%").arg(root.humidity)
            },
            {
                kind: "action", action: "lights", glyph: "bulb",
                caption: root.allLightsOn ? qsTr("All lights on")
                                          : qsTr("All lights off"),
                value: qsTr("Home")
            },
            {
                kind: "action", action: "music", glyph: "music",
                caption: qsTr("Play music"),
                value: root.musicRoom
            }
        ]

        delegate: StConditionTile {
            id: tileDelegate

            required property var modelData

            width: root.tileWidth
            height: root.tileHeight
            inset: root.tileInset
            glyph: tileDelegate.modelData.glyph
            caption: tileDelegate.modelData.caption
            value: tileDelegate.modelData.value
            pressable: tileDelegate.modelData.kind === "action"
            // A reading's value is the brand colour, an action's is plain
            // white and bold. That is the frame's own distinction between
            // "this is a measurement" and "this is a thing you can press",
            // and it survives the regrouping.
            emphasised: tileDelegate.modelData.kind === "reading"
            // On the model, not on the row number: switching on index ties
            // the delegate to the list's ORDER, so inserting a tile silently
            // rewires the two that follow it.
            onActivated: {
                if (tileDelegate.modelData.action === "lights")
                    root.lightsToggled();
                else if (tileDelegate.modelData.action === "music")
                    root.musicRequested();
            }
        }
    }

    /*!
        One tile. Readings and actions differ in two properties, not in
        structure - which is the point of merging them: the icon, caption and
        value sit on the same grid whichever kind it is.
    */
    component StConditionTile: Rectangle {
        id: tile

        property string glyph: ""
        property string caption: ""
        property string value: ""
        property bool   pressable: false
        property bool   emphasised: false
        /*! Left inset for the content. Passed in rather than read from the
            enclosing component: an inline component is its own scope and
            cannot reach the ids of the file that declares it. */
        property int    inset: Theme.spacing4

        signal activated()

        readonly property bool hovered: tileHover.hovered && tile.pressable

        radius: Theme.radiusXs
        // Measured white @15% over the band - LIGHTER than it. These were
        // drawn as surfaceDeep at 85% ON a surfaceDeep band, which made them
        // invisible: the strip looked like bare artwork.
        color: tile.hovered ? Qt.rgba(1, 1, 1, Theme.hoverOverlay * 2)
                            : Theme.overlaySubtle

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        StIcon {
            id: glyphIcon

            anchors.left: parent.left
            anchors.leftMargin: tile.inset
            anchors.verticalCenter: parent.verticalCenter
            name: tile.glyph
            // 32, the empty-state size from the icon scale. The PNGs this
            // replaced were 48 px raster stand-ins that read as emoji next to
            // a 14 px caption; 32 is the largest step that still belongs to
            // the text it labels.
            size: 32
            color: tile.emphasised ? Theme.primary : Theme.textPrimary
        }

        Column {
            anchors.left: glyphIcon.right
            anchors.leftMargin: Theme.spacing3
            anchors.right: parent.right
            anchors.rightMargin: tile.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StLabel {
                width: parent.width
                text: tile.caption
                level: 1
                tone: "secondary"
                elide: Text.ElideRight
            }

            StLabel {
                width: parent.width
                text: tile.value
                level: 2
                tone: tile.emphasised ? "brand" : "primary"
                font.weight: Theme.fontWeightBold
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            id: tileHover
            enabled: tile.pressable
        }

        TapHandler {
            enabled: tile.pressable
            onTapped: tile.activated()
        }

        // One announcement per tile. Without this the icon, caption and value
        // are three stops that read as "Humidity" "67" with no relationship.
        Accessible.role: tile.pressable ? Accessible.Button : Accessible.StaticText
        Accessible.name: qsTr("%1, %2").arg(tile.caption).arg(tile.value)
        Accessible.onPressAction: tile.activated()
    }
}
