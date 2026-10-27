import QtQuick
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StRoomPhotoView
    \inqmlmodule SmarTon.Ui.Components
    \brief The room as a photograph with its devices pinned onto it. Frame 20.

    Frames 19 and 20 are the same room shown two ways: 19 as cards on the page
    ground, 20 as a full-bleed photograph you point at. Both are real designs
    and neither replaces the other - a photo is faster to recognise and a list
    is faster to scan - so this is a view mode rather than a rewrite.

    THE PHOTOGRAPH IS FULL BLEED. Measured on the frame: it starts at the
    panel's left edge and the top of the window, square-cornered, and the
    header floats on top of it instead of sitting above it. The page margin
    every other screen carries would put a dark gutter around the room, which
    is the one thing this frame is designed not to have.

    PIN POSITIONS ARE GENERATED, and the honesty rule from the floor plan
    (ADR-0016) applies unchanged: the model holds no coordinates, so nothing
    here knows where a lamp actually is. What it CAN do is be consistent -
    positions are derived from the device id, so a given device lands in the
    same place every time the screen opens, on every run, on every machine.
    That is what separates a usable affordance from confetti: you learn where
    your lamp's dot is even though the app never knew where the lamp is.

    They are confined to the band BETWEEN the top bar and the card row,
    measured from those two things rather than from a guessed fraction of the
    height: a pin under the transparent header, or behind a card, is a pin
    nobody can tap. Within that band the pins sit on a grid, one device per
    cell, and the id only jitters a device inside its own cell. A pure hash
    puts two pins on top of each other often enough to matter with four
    devices in a room, and two overlapping pins are worse than a grid,
    because one of them cannot be reached at all.
*/
Item {
    id: root

    /*! From HomeViewModel::room(): name, image, temperature, humidity. */
    property var room: ({})
    /*! QAbstractListModel of this room's devices. */
    property var devices: null
    property string selectedDeviceId: ""
    /*! Whether the signed-in role may operate these devices. Disables the
        switches, not the cards - see StDeviceCard for why. */
    property bool operable: true

    /*!
        Resolves a device row's relative image path to a loadable URL.

        The device list model returns \c imageSource as it is stored - a path
        relative to the image root - while HomeViewModel::room() resolves it
        before handing the map over. A component given the MODEL rather than
        resolved rows therefore has to be given the resolver too; screens pass
        \c viewModel.imageUrl. Left unset the raw value is used, which is the
        right fallback for the gallery, where paths are already absolute.
    */
    property var imageUrlFor: null

    /*! Height of whatever the screen draws over the top of this view - the
        transparent top bar. Pins stay below it. */
    property real topInset: 0

    signal deviceActivated(string deviceId)
    signal devicePowerToggled(string deviceId, bool on)

    // ---- frame measurements -----------------------------------------------
    // Read off 20-room-overview-new.png, panel-relative. They are fixed pixel
    // sizes rather than fractions because that is what the frame specifies:
    // the card is 320 wide on a 1160-wide panel and on a narrower one too.
    QtObject {
        id: metrics

        /*!
            The frame is 1024 tall and the panel is 600.

            Everything below is measured off the frame and then scaled by how
            much height there actually is. Unscaled, the card row and the
            footer take 411 px of a 600 px panel and the band left for the
            device pins is two pixels tall - so every pin lands in the same
            place and the affordance the view exists for stops working. The
            floor is 0.72 rather than the raw ratio because below that the
            cards stop being able to hold their own text.

            Widths are NOT scaled. A card is 320 across because that is what
            fits its content, and a narrower panel gets fewer cards rather
            than smaller ones - which is the reflow rule from ADR-0008.
        */
        readonly property real scale:
            Math.min(1, Math.max(0.72, root.height / 1024))

        readonly property int cardWidth:    320  // 320..639 on the frame
        readonly property int cardHeight:   Math.round(240 * metrics.scale)
        readonly property int cardGap:       24  // 640..663
        readonly property int cardInset:     40  // panel edge to first card
        readonly property int cardOverhang: Math.round(39 * metrics.scale)
        readonly property int footerHeight: Math.round(110 * metrics.scale)
        readonly property int photoGap:     Math.round(61 * metrics.scale)
        readonly property int readingGap:   120  // between the two readings
    }

    /*!
        A stable jitter in [0,1]x[0,1] for \a id.

        FNV-1a, because it needs to be deterministic across runs and platforms
        and JavaScript's own string hashing is neither specified nor stable.
        Two different slices of the hash for x and y so a device does not land
        on the diagonal, which is what using one hash for both axes looks like.

        This is the offset INSIDE a device's grid cell, not a position on the
        photo: the cell is chosen by index, so two pins cannot coincide.
    */
    function _jitter(id: string): point {
        let h = 2166136261;
        for (let i = 0; i < id.length; ++i) {
            h ^= id.charCodeAt(i);
            h = Math.imul(h, 16777619) >>> 0;
        }
        return Qt.point((h % 997) / 997, ((h >>> 10) % 991) / 991);
    }

    /*! Cells across the pin band. Four keeps a cell wider than a pin at the
        panel's narrowest sane width, and two rows of four covers every room
        in the model with slots to spare. */
    readonly property int _pinColumns: 4

    // ---- the photograph ---------------------------------------------------
    Image {
        id: photo

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: metrics.photoGap
        // Square corners and no inset: see the note on full bleed above. Plain
        // Image rather than StRoundedImage for the same reason - there is no
        // radius to mask, and masking costs a texture and a pass.
        source: root.room.image === undefined ? "" : root.room.image
        fillMode: Image.PreserveAspectCrop
        clip: true
        asynchronous: true
        // The room photographs are far larger than the panel, so this is a
        // minification - the case where a GPU without mipmaps shimmers along
        // every edge as the window resizes. StRoundedImage has had these for
        // the same reason.
        smooth: true
        mipmap: true
    }

    // Scrim under the card row. Without it a pale room makes white card text
    // unreadable, and the design's photographs are pale.
    Rectangle {
        anchors.left: photo.left
        anchors.right: photo.right
        anchors.bottom: photo.bottom
        height: photo.height * 0.55
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.62) }
        }
    }

    // ---- device pins -------------------------------------------------------
    Repeater {
        model: root.devices

        delegate: Item {
            id: pin

            required property var model
            required property int index

            readonly property point at: root._jitter(pin.model.deviceId)
            readonly property bool selected: root.selectedDeviceId === pin.model.deviceId

            // The band: below the header the screen draws over us, above the
            // card row, inset from the sides by the card inset.
            readonly property real bandLeft: metrics.cardInset
            readonly property real bandRight:
                Math.max(pin.bandLeft + pin.width, root.width - metrics.cardInset)
            readonly property real bandTop: root.topInset + Theme.spacing4
            readonly property real bandBottom:
                Math.max(pin.bandTop + pin.height, cardRow.y - Theme.spacing4)

            readonly property int column: pin.index % root._pinColumns
            readonly property int row: Math.floor(pin.index / root._pinColumns)
            readonly property real cellWidth:
                (pin.bandRight - pin.bandLeft) / root._pinColumns
            readonly property real cellHeight: (pin.bandBottom - pin.bandTop) / 2

            // The jitter runs over what the cell has LEFT after the pin, not
            // over the whole cell: jittered by a full cell width, the last pin
            // in a cell starts exactly where the next cell begins and the grid
            // stops preventing the overlap it exists to prevent.
            x: pin.bandLeft + pin.column * pin.cellWidth
               + pin.at.x * Math.max(0, pin.cellWidth - pin.width)
            y: pin.bandTop + (pin.row % 2) * pin.cellHeight
               + pin.at.y * Math.max(0, pin.cellHeight - pin.height)
            width: 44
            height: 44

            // The halo: only on the selected pin, and drawn as a ring around
            // the dot rather than as a bigger dot, so selection reads as
            // emphasis instead of as a different kind of device.
            Rectangle {
                anchors.centerIn: parent
                width: pin.selected ? 34 : 26
                height: width
                radius: width / 2
                color: pin.selected ? Theme.info : Qt.rgba(1, 1, 1, 0.92)
                border.width: pin.selected ? 3 : 0
                border.color: Theme.info
                antialiasing: true

                Behavior on width { NumberAnimation { duration: Theme.durationFast } }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: width
                    radius: width / 2
                    antialiasing: true
                    // Orange centre when selected, matching the frame; when
                    // not, the dot IS the white disc and this is invisible.
                    color: pin.selected ? Theme.primary : "transparent"
                }
            }

            Accessible.role: Accessible.Button
            Accessible.name: pin.model.name
            Accessible.onPressAction: root.deviceActivated(pin.model.deviceId)

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.deviceActivated(pin.model.deviceId) }
        }
    }

    // ---- device card row ----------------------------------------------------
    ListView {
        id: cardRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: metrics.cardOverhang
        height: metrics.cardHeight
        orientation: ListView.Horizontal
        spacing: metrics.cardGap
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500
        pixelAligned: true
        // Clipped. The half-visible last card that tells a person the row
        // scrolls is what the CLIP produces - a card cut off at the panel's
        // own right edge, which is where the frame cuts it. Unclipped, the row
        // drew its cards over the sidebar and off the right of the window
        // instead; that is not an affordance, it is a leak.
        clip: true
        // The left inset is the VIEW's content margin, not an anchor margin,
        // so the clip boundary stays at the panel edge: the frame runs the row
        // right off that edge and starts it 40 px inside. Anchored in, the
        // clip would also cut every drop shadow off flat against its card.
        leftMargin: metrics.cardInset
        model: root.devices

        delegate: Item {
            id: card

            required property var model

            readonly property bool active: card.model.isOn

            width: metrics.cardWidth
            height: cardRow.height

            StShadow { anchors.fill: parent; radius: Theme.radiusLg }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg
                // Frame 20: the ON device's card is filled with the accent and
                // the rest are a translucent slate over the photograph. That
                // is the whole point of the view - which device is on is
                // readable without reading a single word.
                color: card.active ? Theme.primary
                                   : Qt.rgba(0.30, 0.33, 0.37, 0.82)
                antialiasing: true
                // The disc and the product both run past the top edge on the
                // frame - the lamp's flex reaches the card's top - so the card
                // is the clip, not the artwork.
                clip: true

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                // The soft disc behind the product. Measured: ~194 across on a
                // 320 card, flush with the left edge, its top cut off by the
                // card's - so it reads as a glow the product stands in rather
                // than as a circle someone drew.
                Rectangle {
                    id: disc

                    width: parent.width * 0.606
                    height: width
                    radius: width / 2
                    x: 0
                    y: -height * 0.20
                    color: Theme.textPrimary
                    opacity: 0.06
                }

                Image {
                    anchors.top: parent.top
                    // On the disc, not on the card: the product sits at the
                    // quarter mark of the frame's cards, with the whole right
                    // half of the card left for the name and the switch.
                    anchors.horizontalCenter: disc.horizontalCenter
                    height: parent.height * 0.44
                    source: root.imageUrlFor === null
                            ? card.model.image
                            : root.imageUrlFor(card.model.image)
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 240
                    smooth: true
                    asynchronous: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing5
                    anchors.right: cardSwitch.left
                    anchors.rightMargin: Theme.spacing4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacing5
                    spacing: 1

                    StLabel {
                        width: parent.width
                        text: card.model.name
                        level: 2
                        font.weight: Theme.fontWeightMedium
                        color: card.active ? Theme.textOnPrimary : Theme.textPrimary
                    }

                    StLabel {
                        width: parent.width
                        text: card.model.roomName
                        level: 1
                        color: card.active ? Theme.textOnPrimary : Theme.textSecondary
                        opacity: card.active ? 0.85 : 1.0
                    }
                }

                StSwitch {
                    id: cardSwitch

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing5
                    anchors.bottom: parent.bottom
                    // Spacing3, not spacing5: StSwitch's item is 44 tall for
                    // the touch target while its track is 28, so the track
                    // sits 8 px inside the item's bottom edge. Measured to the
                    // TRACK, this is where the frame puts it.
                    anchors.bottomMargin: Theme.spacing3
                    // No size override: the frame's switch here is within a
                    // few pixels of StSwitch's own 52x28, and one switch size
                    // across the app beats a bespoke one per card.
                    enabled: root.operable
                    value: card.model.isOn
                    pending: card.model.isPending
                    unreachable: !card.model.isReachable
                    onToggleRequested: next =>
                        root.devicePowerToggled(card.model.deviceId, next)
                }
            }

            TapHandler {
                // The card body opens the device; the switch has its own
                // handler and takes the tap before this one sees it.
                onTapped: root.deviceActivated(card.model.deviceId)
            }
        }
    }

    // ---- ambient footer ------------------------------------------------------
    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: metrics.cardInset
        anchors.rightMargin: metrics.cardInset
        height: metrics.footerHeight

        Rectangle {
            id: rule

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            color: Theme.overlaySubtle
        }

        // Two equal blocks with a fixed gap, NOT a centred row: the frame
        // right-aligns each reading's value, and it can only do that if the
        // block has an edge to align to. Centred, the two values drift with
        // the caption lengths and stop lining up with each other - which is
        // exactly what they did in every language but English.
        Row {
            id: readings

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            spacing: metrics.readingGap

            StAmbientReading {
                width: (readings.width - readings.spacing) / 2
                height: readings.height
                glyph: "temperature"
                tone: Theme.warning
                caption: qsTr("Current temperature in the %1")
                            .arg(root.room.name === undefined ? "" : root.room.name)
                value: qsTr("%1°").arg(root.room.temperature === undefined
                                       ? 0 : root.room.temperature)
            }

            StAmbientReading {
                width: (readings.width - readings.spacing) / 2
                height: readings.height
                glyph: "humidity"
                tone: Theme.info
                caption: qsTr("Current humidity in the %1")
                            .arg(root.room.name === undefined ? "" : root.room.name)
                value: qsTr("%1%").arg(root.room.humidity === undefined
                                       ? 0 : root.room.humidity)
            }
        }

        Rectangle {
            anchors.horizontalCenter: readings.horizontalCenter
            anchors.verticalCenter: readings.verticalCenter
            width: 1
            height: 34
            color: Theme.overlaySubtle
        }
    }

    /*! One footer reading: icon, caption, and the value on the right edge. */
    component StAmbientReading: Item {
        id: reading

        property string glyph: ""
        property color tone: Theme.primary
        property string caption: ""
        property string value: ""

        StIcon {
            id: readingIcon

            name: reading.glyph
            size: 24
            color: reading.tone
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        StLabel {
            text: reading.caption
            level: 1
            anchors.left: readingIcon.right
            anchors.leftMargin: Theme.spacing3
            anchors.right: readingValue.left
            anchors.rightMargin: Theme.spacing4
            anchors.verticalCenter: parent.verticalCenter
        }

        StLabel {
            id: readingValue

            text: reading.value
            level: 2
            tone: "brand"
            font.weight: Theme.fontWeightBold
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
