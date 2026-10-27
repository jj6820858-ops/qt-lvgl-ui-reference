import QtQuick
import QtQuick.Templates as T
import SmarTon.Ui.Theme

/*!
    \qmltype StComboBox
    \inqmlmodule SmarTon.Ui.Controls
    \brief Dropdown selector. Figma: the "My Home" pill on frames 07, 18, 21.

    Derives from T.ComboBox, which is doing real work here: popup placement
    and closing, Up/Down/Home/End/Escape/Enter key handling, type-ahead, and
    the highlighted-versus-current distinction all come from Qt. A Rectangle
    with a TapHandler and a ListView looks the same and gets every one of
    those wrong in a way that only shows up on a keyboard.

    The design draws a chevron and no other affordance, so the WHOLE pill is
    the target rather than just the arrow - a 36 px arrow is not a touch
    target, and people tap the label anyway.

    Delegates take an optional \c leadingImage role, which is what lets the
    space picker show a thumbnail without a second component.
*/
T.ComboBox {
    id: root

    /*! Extra row pinned under the list, e.g. "Create a new space". Empty hides it. */
    property string actionText: ""
    /*! Role holding an image URL, or empty for a text-only list. */
    property string imageRole: ""
    /*! Thumbnail for the CLOSED state. The delegates carry their own; this is
        the one T.ComboBox renders from contentItem, which has no delegate.
        Built in here rather than overlaid by the caller - an overlay has to
        guess the control's padding, and got it wrong. */
    property url leadingImage: ""

    signal actionTriggered()

    // Measured 320 x 55 on the 1440 frame; height preserved, width reflowed.
    implicitWidth: 300
    implicitHeight: 55
    // Measured: the thumbnail sits 15 px in, and is 34 across.
    leftPadding: root.leadingImage.toString().length > 0
                 ? 15 + 34 + Theme.spacing3 : Theme.spacing5
    rightPadding: Theme.spacing2
    hoverEnabled: true
    activeFocusOnTab: true

    property string accessibleName: qsTr("Selection")

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName
    Accessible.description: root.displayText
    focusPolicy: Qt.StrongFocus

    delegate: T.ItemDelegate {
        id: option

        required property int index
        required property var model

        width: ListView.view.width
        // Matches the closed control's height, so opening the list does not
        // change the rhythm of what you are looking at.
        height: 55
        highlighted: root.highlightedIndex === option.index
        hoverEnabled: true

        contentItem: Item {
            StRoundedImage {
                id: optionImage
                visible: root.imageRole.length > 0
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: width / 2
                source: root.imageRole.length > 0
                        ? (option.model[root.imageRole] === undefined
                           ? "" : option.model[root.imageRole])
                        : ""
            }

            StLabel {
                anchors.left: optionImage.visible ? optionImage.right : parent.left
                anchors.leftMargin: Theme.spacing3
                anchors.right: tick.left
                anchors.rightMargin: Theme.spacing2
                anchors.verticalCenter: parent.verticalCenter
                text: option.model[root.textRole] === undefined
                      ? String(option.model) : option.model[root.textRole]
                level: 1
                color: option.highlighted ? Theme.textPrimary : Theme.textSecondary
            }

            // The current entry is ticked, not just highlighted: highlight
            // follows the keyboard cursor, which is a different thing from
            // "this is the one you are on".
            StIcon {
                id: tick
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing3
                anchors.verticalCenter: parent.verticalCenter
                // Was the literal character "✓", which is whatever the system
                // font decides - a thin hairline on one platform, a coloured
                // emoji on another, and never the weight of the icon set.
                name: "check"
                size: 20
                color: Theme.primary
                visible: root.currentIndex === option.index
            }
        }

        background: Rectangle {
            radius: Theme.radiusXs
            color: option.highlighted ? Theme.surfaceAlt
                 : option.hovered     ? Qt.rgba(1, 1, 1, Theme.hoverOverlay)
                                      : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    indicator: StIcon {
        x: root.width - width - Theme.spacing4
        y: (root.height - height) / 2
        name: "chevronDown"
        size: 20
        color: root.enabled ? Theme.textSecondary : Theme.textDisabled

        // Rotates to point up while the list is open, which is the standard
        // behaviour people already expect from a dropdown.
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation {
            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
        }
    }

    // The thumbnail is part of the control, positioned against the BACKGROUND
    // rather than inside contentItem: contentItem is laid out inside the
    // control's padding, and the padding is what makes room for this.
    // A circle, cut with a mask rather than clipped: `clip` follows the
    // bounding box, not the radius, so this was a square thumbnail sitting on
    // a round one nobody could see.
    Item {
        id: leadingThumb

        visible: root.leadingImage.toString().length > 0
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surfaceRaised
            antialiasing: true
        }

        StRoundedImage {
            anchors.fill: parent
            radius: width / 2
            source: root.leadingImage
        }
    }

    contentItem: StLabel {
        // No leftPadding here: T.ComboBox lays the content item out inside the
        // control's padding, and adding more would double it - which is
        // exactly what hid the label behind the thumbnail before.
        rightPadding: root.indicator.width + Theme.spacing3
        text: root.displayText
        level: 1
        color: root.enabled ? Theme.textPrimary : Theme.textDisabled
        font.weight: Theme.fontWeightMedium
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        // Measured: fill #2A3240 (surfaceAlt, NOT surface), 1 px #808B9A
        // border, radius 10. It sits on the dark header band, which is why it
        // needs a stronger edge than a control on the page ground.
        radius: Theme.radiusSm
        color: !root.enabled ? Theme.surfaceAlt
             : root.down     ? Theme.pressedFill(Theme.surfaceAlt)
             : root.hovered  ? Qt.lighter(Theme.surfaceAlt, 1 + Theme.hoverOverlay)
                             : Theme.surfaceAlt
        border.width: root.visualFocus || root.popup.visible
                      ? Theme.borderWidthFocus : Theme.borderWidth
        border.color: root.visualFocus || root.popup.visible
                      ? Theme.focus
                      : root.hovered ? Theme.textMuted : Theme.outlineStrong
        opacity: root.enabled ? 1 : Theme.disabledOpacity

        Behavior on color        { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    popup: T.Popup {
        id: listPopup

        // Sits directly under the control with the same 1 px gap the design
        // uses between stacked controls, and exactly the same width - a popup
        // narrower or wider than its anchor reads as a different control.
        y: root.height + Theme.spacing2
        width: root.width
        // Capped, then scrolls. An unbounded popup on a 600 px panel runs off
        // the bottom of the screen with no way back to what it hid.
        // Four rows before it scrolls. On a 600 px panel a taller popup runs
        // off the bottom edge with no way back to what it hid.
        implicitHeight: Math.min(list.contentHeight + footer.height
                                 + listPopup.padding * 2, 55 * 4 + 52)
        padding: Theme.spacing1

        enter: Transition {
            NumberAnimation {
                property: "opacity"; from: 0; to: 1; duration: Theme.durationFast
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"; from: 1; to: 0; duration: Theme.durationFast
            }
        }

        background: Rectangle {
            // Same radius and edge as the closed control, one step darker so
            // the open list reads as being in front of it rather than as part
            // of the band behind.
            radius: Theme.radiusSm
            color: Theme.surfaceDeep
            border.width: Theme.borderWidth
            border.color: Theme.outlineStrong
        }

        // An explicit contentItem holding BOTH parts. Declaring the footer as
        // a plain child would put it inside T.Popup's contentData - which is
        // the ListView - and it would scroll away with the entries.
        contentItem: Item {
            ListView {
                id: list

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                clip: true
                model: listPopup.visible ? root.delegateModel : null
                currentIndex: root.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                // A hairline that only appears while scrolling, so a list that
                // fits shows nothing at all.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: Theme.scrollBarWidth / 2
                    radius: width / 2
                    color: Theme.outlineSubtle
                    visible: list.contentHeight > list.height
                    opacity: list.moving ? 0.9 : 0.35
                    y: list.contentHeight > 0
                       ? (list.contentY / list.contentHeight) * list.height : 0
                    height: list.contentHeight > 0
                            ? Math.max(24, (list.height / list.contentHeight) * list.height)
                            : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }
            }

            Item {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.actionText.length > 0 ? 52 : 0
                visible: height > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.outline
                    opacity: 0.5
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    color: footerHover.hovered
                           ? Qt.lighter(Theme.surfaceDeep, 1 + Theme.hoverOverlay * 3)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                StLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing4
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.actionText
                    level: 1
                    tone: "brand"
                    font.weight: Theme.fontWeightMedium
                }

                HoverHandler { id: footerHover }

                TapHandler {
                    onTapped: {
                        listPopup.close();
                        root.actionTriggered();
                    }
                }
            }
        }
    }
}
