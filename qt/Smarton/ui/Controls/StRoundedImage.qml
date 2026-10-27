import QtQuick
import QtQuick.Effects
import SmarTon.Ui.Theme

/*!
    \qmltype StRoundedImage
    \inqmlmodule SmarTon.Ui.Controls
    \brief An image genuinely cropped to a rounded rectangle or a circle.

    THE BUG THIS EXISTS TO FIX. Every avatar and thumbnail in SmarTon was an
    Image inside a `Rectangle { radius: width / 2; clip: true }`. That does not
    do what it reads as: \c clip in Qt Quick clips to the item's BOUNDING BOX,
    never to its corner radius. The rounded rectangle was drawn underneath and
    then completely covered by a square image, so every "circular" avatar in
    the app was a square one with a ring of colour that happened to be hidden.
    It looks almost right at 36 px against a dark background, which is why it
    survived.

    The fix is a real mask. \c MultiEffect takes the alpha of \l maskSource and
    applies it to \l source, so the corners are actually cut. The mask is a
    layered rounded Rectangle - the shape we wanted all along, now used as
    geometry rather than as decoration behind an image.

    \c maskSpreadAtMin keeps one pixel of softness at the edge. At zero the cut
    is aliased and a circle at 36 px visibly steps.

    Lives in Controls, not Components: it composes nothing and depends on
    nothing above Theme, and Controls is where the combobox that needs it
    lives. StAvatar - which does compose - is the Components-level type.
*/
Item {
    id: root

    property url source: ""
    /*! Corner radius. Half the width gives a circle. */
    property real radius: Theme.radius
    property int fillMode: Image.PreserveAspectCrop
    /*! Which part of an over-wide crop survives. Matters for artwork that is
        anchored to one edge - the header's line pattern is drawn to sit on the
        right, and a centre crop cuts its most legible part off. */
    property int horizontalAlignment: Image.AlignHCenter
    property int verticalAlignment: Image.AlignVCenter
    /*! Decode size. Defaults to 2x the item, for a crisp result on the panel. */
    property int decodeWidth: Math.max(2, Math.round(root.width * 2))
    property bool asynchronous: true
    // MultiEffect masking is unavailable with Qt Quick's software backend.
    // Canvas is deliberately the fallback there: unlike Item::clip it clips
    // to a real rounded path, so profiles stay circular on the RK3328 rather
    // than becoming square merely because the GPU effect is unavailable.
    readonly property bool softwareRenderer: GraphicsInfo.api === GraphicsInfo.Software

    readonly property bool ready: picture.status === Image.Ready

    Image {
        id: picture

        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        sourceSize.width: root.decodeWidth
        smooth: true
        mipmap: true
        asynchronous: root.asynchronous
        visible: !root.softwareRenderer
        layer.enabled: true
    }

    // Canvas renders through the software scene graph and supports path
    // clipping. It is the small, reliable fallback for arbitrary user photos
    // and device images when a GPU alpha mask cannot be used.
    Canvas {
        id: softwareCrop

        anchors.fill: parent
        visible: root.softwareRenderer && root.source !== ""
        renderStrategy: Canvas.Immediate
        antialiasing: true

        function repaint() {
            if (root.source !== "")
                loadImage(root.source)
            requestPaint()
        }

        onImageLoaded: requestPaint()
        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0 || root.source === "" || !root.ready
                    || !isImageLoaded(root.source))
                return

            // Qt 6.2 Canvas has no imageSize() API. `picture` already owns
            // the decoded source, so its intrinsic dimensions are both the
            // compatible and the more efficient source of crop geometry.
            const imageWidth = picture.implicitWidth
            const imageHeight = picture.implicitHeight
            if (imageWidth <= 0 || imageHeight <= 0)
                return

            // PreserveAspectCrop, expressed in Canvas coordinates. This is
            // the same crop policy as the GPU Image above, not a stretched
            // fallback that happens to have rounded corners.
            const scale = Math.max(width / imageWidth, height / imageHeight)
            const drawWidth = imageWidth * scale
            const drawHeight = imageHeight * scale
            const drawX = (width - drawWidth) / 2
            const drawY = (height - drawHeight) / 2
            const corner = Math.min(root.radius, width / 2, height / 2)

            context.beginPath()
            context.moveTo(corner, 0)
            context.lineTo(width - corner, 0)
            context.quadraticCurveTo(width, 0, width, corner)
            context.lineTo(width, height - corner)
            context.quadraticCurveTo(width, height, width - corner, height)
            context.lineTo(corner, height)
            context.quadraticCurveTo(0, height, 0, height - corner)
            context.lineTo(0, corner)
            context.quadraticCurveTo(0, 0, corner, 0)
            context.closePath()
            context.clip()
            // Qt 6.2 supports the five-argument drawImage overload but not
            // the browser-style nine-argument source rectangle overload.
            // Drawing a cover-sized image under this clip is equivalent.
            context.drawImage(root.source, drawX, drawY, drawWidth, drawHeight)
        }
    }

    Item {
        id: mask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: picture
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        // A pixel of softness at the cut. At 0 a 36 px circle visibly steps.
        maskSpreadAtMin: 0.35
        visible: root.ready && !root.softwareRenderer
    }

    onSourceChanged: softwareCrop.repaint()
    onWidthChanged: softwareCrop.requestPaint()
    onHeightChanged: softwareCrop.requestPaint()
    onRadiusChanged: softwareCrop.requestPaint()
}
