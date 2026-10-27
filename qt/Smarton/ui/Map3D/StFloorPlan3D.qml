import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import SmarTon.Ui.Helpers
import SmarTon.Ui.Theme
import SmarTon.Ui.Controls

/*!
    \qmltype StFloorPlan3D
    \inqmlmodule SmarTon.Ui.Map3D
    \brief The home as a building you can look at from outside or stand inside.

    Same data and the same generated layout as the 2D plan - see
    \c FloorPlanHelper for why a plan derived from room AREA is the honest
    answer when the product holds no survey data. This builds it.

    TWO WAYS TO LOOK AT IT, and they want opposite things from the geometry.

    \list
    \li \b Orbit is the architectural model: you are outside it, and the
        question is "what is where". Waist-height sectioning walls answer that
        - the plan stays readable from above and every device is visible. This
        is the sectioning convention, and it is why the first version of this
        file used it everywhere.
    \li \b Walk puts you inside at eye height. Waist walls there read as an
        open-plan office, not as a home, so walk mode raises every wall to the
        ceiling, closes the roof, collapses the storey gap and cuts a doorway
        through each wall so you can get from room to room.
    \endlist

    So the wall height is a MODE, not a constant, and the two modes disagree
    on purpose. \l wallMode picks it in orbit; walk mode forces full height,
    because there is no reading of "inside the house" where a wall stops at
    your waist.

    ONE GEOMETRY PASS, in \l built. Wall segments, room rectangles and device
    positions are all computed once in JavaScript and handed to the delegates,
    rather than each delegate deriving its own. It is not only cheaper: the
    walk-mode collision test and the walls you can see have to be the same
    rectangles, and the surest way to make them the same is to compute them
    once. A player pushing through a wall that is drawn but not collided - or
    stopping in a doorway that is collided but not drawn - is exactly the bug
    that two copies of this arithmetic would produce.

    WALKING CANNOT DEAD-END. Doorways are cut in the middle of each room's own
    walls, and two rooms that share a boundary but not a full edge - which a
    squarified layout does produce - get two openings that do not line up.
    Rather than pretend otherwise, tapping a room's floor walks you to it. That
    also happens to be the fastest way to cross a house, which is why games
    that model doors properly still offer it.

    LABELS ARE 2D, ON PURPOSE. Text rendered INTO a 3D scene has to be a
    texture or extruded geometry; both look wrong at a glancing angle and
    neither stays readable at the far end of the plan. So the geometry is 3D
    and the labels are ordinary Qt Quick items positioned by projecting a
    point with \c View3D::mapFrom3DScene. Orbit labels name rooms; walk labels
    name the devices near you, because standing in a room you already know
    which room it is.

    PERFORMANCE. Materials are declared ONCE and shared. Lamps that are on
    emit real light, which is the single strongest cue that the model is your
    house rather than a diagram - and it is also the most expensive thing
    here, so it is capped (\l maxLampLights), limited to lamps, and off below
    render tier 1. Shadows follow \c Theme.shadowsEnabled.
*/
Item {
    id: root

    /*! From HomeViewModel::floorPlan(): includes a `floor` on every room. */
    property var rooms: []
    /*! Storeys present, ascending. From HomeViewModel::floors(). */
    property var floors: [0]
    /*! Which storey is highlighted; the others dim. -1 shows all equally. */
    property int activeFloor: -1
    /*! Gap between a storey's ceiling and the next storey's slab - the
        exploded view every architectural model has. Ignored while walking:
        a gap between the floors is a hole to fall through. */
    property real floorSeparation: 30
    /*! Selected room. The label overlay, the floor material and the room lift
        all read this, so they cannot disagree about what is selected. */
    property string selectedRoomId: ""

    /*! section | full. Waist-height sectioning walls, or walls to the ceiling.
        Forced to full while walking - see the class docs. */
    property string wallMode: "section"
    /*! orbit | walk. */
    property string cameraMode: "orbit"

    /*! How far a selected room lifts out of the stack. The drawer-pull that
        every physical architectural model has, and the only form of
        "exploded" that means anything in a bungalow, where separating the
        storeys separates nothing. */
    property real roomLift: 34

    /*! Lit lamps beyond this many are drawn but do not light the scene. Qt
        Quick 3D has a hard ceiling on lights per frame; going past it drops
        them silently, which is worse than choosing which ones to keep. */
    property int maxLampLights: 6

    signal roomActivated(string roomId)
    signal deviceActivated(string deviceId)
    /*! A device was held rather than tapped. Tap opens it, hold operates it:
        standing next to a lamp, the thing you want is the switch. */
    signal deviceToggleRequested(string deviceId)

    // ---- the building's dimensions -----------------------------------------
    // A fixed PLAN space rather than view pixels, so the model does not
    // re-solve on every frame of a window resize and the camera framing is a
    // constant rather than something chasing the viewport.
    readonly property real planWidth: 1000
    readonly property real planDepth: 700

    readonly property real slabThickness: 9
    /*! Slab overhang past the glazing. The cantilever IS the architecture. */
    readonly property real slabOverhang: 22
    /*!
        Storey height.

        Raised from 62 to 132 when walk mode arrived, because 62 was a
        proportion nobody lives in: the generated rooms are 300-400 units
        across, and a room four times wider than it is tall is a crawlspace.
        At 132 the ratio is roughly a real 2.6 m ceiling in a 7 m room, which
        is what makes the interior read as a home at eye height - and it costs
        the orbit view nothing, because the section is still cut at the waist.
    */
    readonly property real ceilingHeight: 132
    /*! Waist height, for the sectioned orbit view. */
    readonly property real partitionHeight: 46
    readonly property real wallThickness: 5
    readonly property real mullionSize: 4
    /*! The room's floor finish, laid on the structural slab. */
    readonly property real floorFinishThickness: 1.2

    /*! Doorway opening. 58 wide and 96 tall against a 132 ceiling is a real
        door's proportion, which is what stops the openings reading as damage. */
    readonly property real doorWidth: 58
    readonly property real doorHeight: 96
    /*! A wall shorter than this keeps its full length: an opening in a stub
        wall removes the wall. */
    readonly property real minWallForDoor: 132

    readonly property real eyeHeight: 62
    /*! Half the player's width, for the collision test. */
    readonly property real bodyRadius: 11

    // ---- derived ------------------------------------------------------------
    readonly property bool walking: root.cameraMode === "walk"
    /*! Full height while walking, whatever the mode property says. */
    readonly property bool fullHeightWalls: root.walking || root.wallMode === "full"
    readonly property real wallHeight: root.fullHeightWalls ? root.ceilingHeight - 2
                                                            : root.partitionHeight
    /*! Zero while walking: a gap between the storeys is a hole to fall down. */
    readonly property real separation: root.walking ? 0 : root.floorSeparation
    readonly property real storeyPitch: root.slabThickness + root.ceilingHeight
                                        + root.separation
    /*! The roof is what closes the stack - and what stops you seeing in. Off
        when the walls are already full height and you are outside, because
        that combination is a sealed box. */
    readonly property bool roofVisible: root.walking || !root.fullHeightWalls

    /*! Index into \l built of the storey being walked, or the active one. */
    readonly property int activeIndex: {
        for (let i = 0; i < root.built.length; ++i) {
            if (root.built[i].floor === root.activeFloor)
                return i;
        }
        return 0;
    }

    function isDimmed(floor: int): bool {
        return root.activeFloor !== -1 && floor !== root.activeFloor;
    }

    /*!
        One wall, split around a doorway.

        Appends to \a out either the whole wall or the two pieces either side
        of an opening. \a horizontal says which axis the wall spans, which the
        caller knows and the rectangle alone does not - a square stub is
        ambiguous, and guessing from w > d puts the door on the wrong axis.
    */
    function _pushWall(out: var, cx: real, cz: real, w: real, d: real,
                       horizontal: bool): void {
        const span = horizontal ? w : d;
        if (span < root.minWallForDoor) {
            out.push({ x: cx, z: cz, w: w, d: d, door: false });
            return;
        }

        const piece = (span - root.doorWidth) / 2;
        const offset = root.doorWidth / 2 + piece / 2;
        if (horizontal) {
            out.push({ x: cx - offset, z: cz, w: piece, d: d, door: true });
            out.push({ x: cx + offset, z: cz, w: piece, d: d, door: true });
        } else {
            out.push({ x: cx, z: cz - offset, w: w, d: piece, door: true });
            out.push({ x: cx, z: cz + offset, w: w, d: piece, door: true });
        }
    }

    /*!
        The whole model, solved once.

        Everything downstream - the delegates, the lamp lights, the collision
        test, the label projection - reads this rather than re-deriving it.
        See the class docs for why the collision rectangles and the visible
        ones must be literally the same objects.
    */
    readonly property var built: {
        const out = [];
        for (let i = 0; i < root.floors.length; ++i) {
            const floor = root.floors[i];
            const here = root.rooms.filter(
                r => (r.floor === undefined ? 0 : r.floor) === floor);
            if (here.length === 0)
                continue;

            const laid = FloorPlanHelper.layout(here, root.planWidth, root.planDepth);
            const cells = [];
            for (let c = 0; c < laid.length; ++c) {
                const cell = laid[c];
                // The layout has its origin at a corner; the scene wants it
                // centred, so everything shifts by half the footprint.
                const cx = cell.x + cell.w / 2 - root.planWidth / 2;
                const cz = cell.y + cell.h / 2 - root.planDepth / 2;
                const w = Math.max(1, cell.w - root.wallThickness);
                const d = Math.max(1, cell.h - root.wallThickness);

                const walls = [];
                root._pushWall(walls, 0, -d / 2, w, root.wallThickness, true);
                root._pushWall(walls, 0,  d / 2, w, root.wallThickness, true);
                root._pushWall(walls, -w / 2, 0, root.wallThickness, d, false);
                root._pushWall(walls,  w / 2, 0, root.wallThickness, d, false);

                // Devices on a grid inside the room. Not scattered: a device
                // has no real position either, and randomising one implies a
                // precision that does not exist.
                const devices = [];
                const source = cell.devices === undefined ? [] : cell.devices;
                const perRow = Math.max(1, Math.floor((w - 30) / 30));
                for (let k = 0; k < source.length; ++k) {
                    devices.push({
                        deviceId: source[k].deviceId,
                        name:     source[k].name,
                        kind:     source[k].kind,
                        on:       source[k].on,
                        pending:  source[k].pending,
                        offline:  source[k].offline,
                        x: -w / 2 + 22 + (k % perRow) * 30,
                        z: -d / 2 + 22 + Math.floor(k / perRow) * 30,
                    });
                }

                cells.push({
                    roomId: cell.roomId, name: cell.name,
                    areaSqm: cell.areaSqm, deviceCount: cell.deviceCount,
                    cx: cx, cz: cz, w: w, d: d,
                    walls: walls, devices: devices,
                });
            }

            out.push({ floor: floor, index: out.length, cells: cells });
        }
        return out;
    }

    /*! Lit lamps, capped. Positions are absolute in the scene, because a light
        is not parented to the room it is in. */
    readonly property var litLamps: {
        const out = [];
        if (Theme.renderTier < 1)
            return out;
        for (let s = 0; s < root.built.length; ++s) {
            const storey = root.built[s];
            if (root.isDimmed(storey.floor))
                continue;
            for (let c = 0; c < storey.cells.length; ++c) {
                const cell = storey.cells[c];
                for (let k = 0; k < cell.devices.length; ++k) {
                    const device = cell.devices[k];
                    if (device.kind !== "lamp" || !device.on || device.offline)
                        continue;
                    if (out.length >= root.maxLampLights)
                        return out;
                    out.push({
                        x: cell.cx + device.x,
                        y: storey.index * root.storeyPitch + root.ceilingHeight - 18,
                        z: cell.cz + device.z,
                    });
                }
            }
        }
        return out;
    }

    /*!
        What a device looks like, by kind.

        A cylinder for everything was the first version, and it is why the
        rooms read as a diagram with counters in them: five identical pegs
        tell you how MANY devices are in a room and nothing about which. These
        are still abstractions - nobody will mistake a cone on a stick for
        their actual lamp - but a floor lamp, a squat speaker, a wall unit up
        near the ceiling and a small box on the floor are distinguishable
        across a room at a glance, which is the whole job.

        Sizes are in plan units against a 132-unit ceiling, so the wall unit
        really is up near it and the floor lamp really is about waist high.
    */
    function _furniture(kind: string): var {
        switch (kind) {
        case "lamp":
            return [ { s: "#Cylinder", w: 3,  h: 46, d: 3,  y: 23 },
                     { s: "#Cone",     w: 26, h: 18, d: 26, y: 55 } ];
        case "speaker":
            return [ { s: "#Cylinder", w: 22, h: 28, d: 22, y: 14 } ];
        case "conditioner":
            // On the wall, not on the floor - which is where air conditioners
            // are, and which is why this one is worth telling apart.
            return [ { s: "#Cube",     w: 36, h: 16, d: 12, y: 100 } ];
        case "humidifier":
            return [ { s: "#Cylinder", w: 16, h: 36, d: 16, y: 18 } ];
        case "diffuser":
            return [ { s: "#Sphere",   w: 18, h: 18, d: 18, y: 10 } ];
        default:
            return [ { s: "#Cube",     w: 16, h: 14, d: 16, y: 7 } ];
        }
    }

    /*!
        Everything that moves a label on screen without changing its position
        in the scene.

        \c View3D::mapFrom3DScene is a FUNCTION, so a binding that calls it
        records no dependency on the camera - orbit the model and the labels
        would sit where they were. Reading the inputs into one property makes
        the dependency explicit, in one place rather than once per label.
    */
    readonly property real projectionEpoch:
        orbitCamera.position.x + orbitCamera.position.y + orbitCamera.position.z
        + orbitCamera.eulerRotation.x + orbitCamera.eulerRotation.y
        + walkCamera.position.x + walkCamera.position.y + walkCamera.position.z
        + walkCamera.eulerRotation.x + walkCamera.eulerRotation.y
        + view.width + view.height + root.separation + root.built.length
        + (root.walking ? 1 : 0) + root.roomLift * (root.selectedRoomId.length > 0 ? 1 : 0)

    // ---- walking ------------------------------------------------------------
    /*!
        Where the player is and which way they are facing.

        Kept in a plain object rather than on the camera node, because the
        camera's position is DERIVED - it is the storey height plus eye height
        plus wherever the feet are - and writing a derived value back into the
        thing that derives it is how a camera ends up drifting upwards one
        frame at a time.
    */
    QtObject {
        id: feet

        property real x: 0
        property real z: 240
        property real yaw: 180
        property real pitch: -6
        /*! -1..1 from the pad or the keyboard, applied every tick. */
        property real strafe: 0
        property real forward: 0
        /*! Set by a room tap: the player walks here rather than teleporting,
            because a cut to a new position in a first-person view is
            disorienting in a way that two seconds of travel is not. */
        property real targetX: 0
        property real targetZ: 0
        property bool travelling: false
    }

    /*! Put the player at a sensible spot on \a index's storey. */
    function _placeOnStorey(index: int): void {
        const storey = root.built[index];
        if (storey === undefined || storey.cells.length === 0)
            return;
        const cell = storey.cells[0];
        feet.x = cell.cx;
        feet.z = cell.cz;
        feet.travelling = false;
    }

    /*! Slide \a px, \a pz out of any wall it has ended up inside.

        Axis-separated: the shallower overlap is the one undone, which is what
        makes a player slide along a wall they walk into at an angle instead of
        stopping dead against it. */
    function _resolve(px: real, pz: real): point {
        const storey = root.built[root.activeIndex];
        if (storey === undefined)
            return Qt.point(px, pz);

        const r = root.bodyRadius;
        for (let c = 0; c < storey.cells.length; ++c) {
            const cell = storey.cells[c];
            for (let i = 0; i < cell.walls.length; ++i) {
                const wall = cell.walls[i];
                const wx = cell.cx + wall.x;
                const wz = cell.cz + wall.z;
                const hw = wall.w / 2 + r;
                const hd = wall.d / 2 + r;
                const dx = px - wx;
                const dz = pz - wz;
                if (Math.abs(dx) >= hw || Math.abs(dz) >= hd)
                    continue;

                if (hw - Math.abs(dx) < hd - Math.abs(dz))
                    px = wx + (dx < 0 ? -hw : hw);
                else
                    pz = wz + (dz < 0 ? -hd : hd);
            }
        }

        // And never outside the building.
        const limitX = root.planWidth / 2 - r;
        const limitZ = root.planDepth / 2 - r;
        return Qt.point(Math.max(-limitX, Math.min(limitX, px)),
                        Math.max(-limitZ, Math.min(limitZ, pz)));
    }

    function _step(): void {
        const speed = 3.4;

        let dx = 0;
        let dz = 0;

        if (feet.travelling) {
            // Walking to a tapped room. Arrival is generous - a wall between
            // here and there means the last few units may be unreachable, and
            // a player who never quite arrives keeps walking into it forever.
            const toX = feet.targetX - feet.x;
            const toZ = feet.targetZ - feet.z;
            const distance = Math.sqrt(toX * toX + toZ * toZ);
            if (distance < 18) {
                feet.travelling = false;
            } else {
                dx = toX / distance * speed * 1.6;
                dz = toZ / distance * speed * 1.6;
            }
        } else {
            const radians = feet.yaw * Math.PI / 180;
            // Forward is -Z rotated by the yaw, which is the convention every
            // Qt Quick 3D camera uses; right is that turned a quarter.
            const fx = -Math.sin(radians);
            const fz = -Math.cos(radians);
            dx = (fx * feet.forward + Math.cos(radians) * feet.strafe) * speed;
            dz = (fz * feet.forward - Math.sin(radians) * feet.strafe) * speed;
        }

        if (dx === 0 && dz === 0)
            return;

        // _resolve answers in a point, so its `y` is our z. A point rather
        // than two out-parameters because QML has no out-parameters, and a
        // two-element array is worse: nothing names which element is which.
        const settled = root._resolve(feet.x + dx, feet.z + dz);
        feet.x = settled.x;
        feet.z = settled.y;
    }

    Timer {
        interval: 16
        repeat: true
        running: root.walking
        onTriggered: root._step()
    }

    onCameraModeChanged: {
        if (root.walking) {
            if (root.activeFloor === -1 && root.built.length > 0)
                root.activeFloor = root.built[0].floor;
            root._placeOnStorey(root.activeIndex);
            walkFocus.forceActiveFocus();
        }
    }

    // Keyboard for a desk, the pad below for the panel. Both, because this is
    // developed on one and runs on the other.
    Item {
        id: walkFocus

        anchors.fill: parent
        focus: root.walking
        enabled: root.walking

        Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_W: case Qt.Key_Up:    feet.forward =  1; break;
            case Qt.Key_S: case Qt.Key_Down:  feet.forward = -1; break;
            case Qt.Key_A: case Qt.Key_Left:  feet.strafe  = -1; break;
            case Qt.Key_D: case Qt.Key_Right: feet.strafe  =  1; break;
            default: return;
            }
            feet.travelling = false;
            event.accepted = true;
        }

        Keys.onReleased: function (event) {
            switch (event.key) {
            case Qt.Key_W: case Qt.Key_Up: case Qt.Key_S: case Qt.Key_Down:
                feet.forward = 0; break;
            case Qt.Key_A: case Qt.Key_Left: case Qt.Key_D: case Qt.Key_Right:
                feet.strafe = 0; break;
            default: return;
            }
            event.accepted = true;
        }
    }

    View3D {
        id: view

        anchors.fill: parent
        camera: root.walking ? walkCamera : orbitCamera

        environment: SceneEnvironment {
            clearColor: "transparent"
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            // Filmic, not linear. Emissive device markers and a bright slab
            // under a key light blow out to flat white on a linear curve;
            // filmic rolls the highlights off and is why the concrete reads as
            // a surface rather than as a hole in the image.
            tonemapMode: SceneEnvironment.TonemapModeFilmic
            // Contact shading in the corners. The cheapest thing that makes
            // separate boxes look like one built object.
            aoStrength: 65
            aoDistance: 24
            aoSoftness: 28
        }

        Node {
            id: pivot
            // Orbit about the middle of the stack, so the model stays centred
            // as storeys are added rather than swinging around its ground floor.
            position: Qt.vector3d(0, Math.max(1, root.built.length)
                                     * root.storeyPitch / 2 - root.storeyPitch / 4, 0)

            PerspectiveCamera {
                id: orbitCamera

                // Three-quarter view: high enough to read the plan, low enough
                // that the glazing and the slab edges still have height.
                position: Qt.vector3d(0, 820, 1480)
                eulerRotation.x: -28
                clipNear: 10
                clipFar: 12000
                fieldOfView: 42
            }
        }

        OrbitCameraController {
            origin: pivot
            camera: orbitCamera
            enabled: !root.walking
            // Panning would let someone lose the model off-screen with no way
            // back. Orbit and zoom cannot.
            panEnabled: false
        }

        PerspectiveCamera {
            id: walkCamera

            position: Qt.vector3d(feet.x,
                                  root.activeIndex * root.storeyPitch + root.eyeHeight,
                                  feet.z)
            eulerRotation: Qt.vector3d(feet.pitch, feet.yaw, 0)
            // Near plane tight to the eye: at 10 a doorframe you are standing
            // in front of disappears. Far plane short, because indoors there
            // is nothing to see at 12,000 units and the depth buffer's
            // precision is better spent on the room you are in.
            clipNear: 2
            clipFar: 4000
            // Wider than the orbit camera. 42 degrees indoors feels like
            // looking down a tube; 68 is roughly what a first-person view
            // wants and what makes a room feel its size.
            fieldOfView: 68
        }

        // ---- lighting ------------------------------------------------------
        // Key, fill, rim. Three lights is the standard product-render set and
        // the reason is visible in the result: one light leaves the far walls
        // black, two leave the silhouette dead against the background.
        DirectionalLight {
            eulerRotation.x: -48
            eulerRotation.y: -38
            brightness: root.walking ? 0.55 : 1.15
            color: "#FFF4E8"           // slightly warm key
            castsShadow: Theme.shadowsEnabled && !root.walking
            shadowMapQuality: Light.ShadowMapQualityMedium
            shadowFactor: 62
            shadowBias: 12
        }

        DirectionalLight {
            eulerRotation.x: -16
            eulerRotation.y: 142
            brightness: root.walking ? 0.30 : 0.42
            color: "#DCE8FF"           // cool bounce, as if from the sky
            castsShadow: false
        }

        DirectionalLight {
            eulerRotation.x: 22
            eulerRotation.y: 62
            brightness: 0.22
            castsShadow: false
        }

        /*!
            Lamps that are on light the house.

            This is the one feature here that makes the model read as YOUR
            house rather than as a picture of a house: turn the living-room
            lamp off from the dashboard and the living room goes dark. It is
            also the most expensive thing in the scene, which is why the list
            behind it is capped and empty below render tier 1.
        */
        Repeater3D {
            model: root.litLamps

            delegate: PointLight {
                required property var modelData

                position: Qt.vector3d(modelData.x, modelData.y, modelData.z)
                color: "#FFD9A8"
                brightness: root.walking ? 34 : 22
                quadraticFade: 1.6
                linearFade: 0.4
                castsShadow: false
            }
        }

        // ---- materials, declared once --------------------------------------
        PrincipledMaterial {
            id: concreteMaterial
            baseColor: "#8E97A4"
            roughness: 0.92
            metalness: 0.0
        }

        PrincipledMaterial {
            id: concreteDimMaterial
            baseColor: "#49515C"
            roughness: 0.95
        }

        PrincipledMaterial {
            id: floorMaterial
            baseColor: Theme.surfaceAlt
            roughness: 0.8
        }

        PrincipledMaterial {
            id: floorDimMaterial
            baseColor: Qt.darker(Theme.surfaceAlt, 1.5)
            roughness: 0.9
        }

        PrincipledMaterial {
            id: floorSelectedMaterial
            baseColor: Theme.primary
            roughness: 0.55
            // A little emission so a selected room still reads as selected
            // when it faces away from every light.
            emissiveFactor: Qt.vector3d(0.30, 0.12, 0.04)
        }

        PrincipledMaterial {
            id: wallMaterial
            baseColor: "#C9D2DE"
            roughness: 0.78
        }

        PrincipledMaterial {
            id: wallDimMaterial
            baseColor: "#5A626D"
            roughness: 0.85
        }

        // Glazing. Blend mode with a low opacity, a near-mirror roughness and
        // no culling, so the far panes are visible through the near ones -
        // back-face culling on glass is what makes a glass box look like a
        // flat blue card.
        PrincipledMaterial {
            id: glassMaterial
            baseColor: "#A9C6DE"
            opacity: 0.17
            alphaMode: PrincipledMaterial.Blend
            roughness: 0.06
            metalness: 0.0
            specularAmount: 1.0
            cullMode: Material.NoCulling
        }

        PrincipledMaterial {
            id: mullionMaterial
            baseColor: "#20242A"
            metalness: 0.85
            roughness: 0.34
        }

        PrincipledMaterial {
            id: groundMaterial
            baseColor: "#15181C"
            roughness: 1.0
        }

        PrincipledMaterial {
            id: deviceOnMaterial
            baseColor: Theme.primary
            emissiveFactor: Qt.vector3d(0.85, 0.34, 0.10)
            roughness: 0.3
        }

        PrincipledMaterial {
            id: deviceOffMaterial
            baseColor: Theme.outlineStrong
            roughness: 0.65
        }

        PrincipledMaterial {
            id: deviceOfflineMaterial
            baseColor: Theme.warning
            emissiveFactor: Qt.vector3d(0.55, 0.40, 0.06)
            roughness: 0.5
        }

        // ---- site --------------------------------------------------------
        // The building stands on something. Without a ground plane the model
        // floats in the void, the key light's shadow lands on nothing, and the
        // whole thing reads as a diagram again.
        //
        // Dropped well BELOW the ground slab rather than flush with it. At the
        // same height the two surfaces are coplanar and the depth buffer
        // cannot separate them, which shows up as the shimmering patchwork
        // across the base that every z-fight looks like.
        readonly property real groundLevel: -root.slabThickness - 30

        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            y: view.groundLevel
            scale: Qt.vector3d(root.planWidth / 100 * 3.0,
                               root.planDepth / 100 * 3.0, 1)
            materials: [ groundMaterial ]
            receivesShadows: true
            castsShadows: false
            // Kept while walking. The perimeter is glass, and a window with
            // nothing behind it is a hole in the world.
        }

        // A plinth between the ground and the building, so the ground floor
        // sits ON the site rather than hovering above it.
        readonly property real plinthHeight: -root.slabThickness - view.groundLevel

        Model {
            source: "#Cube"
            y: view.groundLevel + view.plinthHeight / 2
            scale: Qt.vector3d((root.planWidth - 90) / 100,
                               view.plinthHeight / 100,
                               (root.planDepth - 90) / 100)
            materials: [ concreteDimMaterial ]
            castsShadows: true
            receivesShadows: true
        }

        // ---- the building ----------------------------------------------------
        Repeater3D {
            model: root.built

            delegate: Node {
                id: storey

                required property var modelData

                readonly property bool dimmed: root.isDimmed(storey.modelData.floor)
                readonly property bool topStorey:
                    storey.modelData.index === root.built.length - 1
                /*! Walking, the storeys above are a roof over your head and
                    the ones below are under the floor: neither is worth
                    drawing, and both cost a full storey of geometry. */
                readonly property bool shown:
                    !root.walking || storey.modelData.index === root.activeIndex

                y: storey.modelData.index * root.storeyPitch
                visible: storey.shown

                Behavior on y { NumberAnimation { duration: Theme.durationNormal
                                                  easing.type: Easing.OutCubic } }

                // ---- structural slab -------------------------------------
                Model {
                    source: "#Cube"
                    // #Cube is 100 units on a side, so scale is size/100 - the
                    // one piece of primitive arithmetic worth stating.
                    scale: Qt.vector3d((root.planWidth + root.slabOverhang * 2) / 100,
                                       root.slabThickness / 100,
                                       (root.planDepth + root.slabOverhang * 2) / 100)
                    y: -root.slabThickness / 2
                    materials: [ storey.dimmed ? concreteDimMaterial : concreteMaterial ]
                    castsShadows: true
                    receivesShadows: true
                }

                // ---- ceiling / roof ---------------------------------------
                Model {
                    source: "#Cube"
                    visible: root.roofVisible
                             && (storey.topStorey || root.walking)
                    scale: Qt.vector3d((root.planWidth + root.slabOverhang * 2) / 100,
                                       root.slabThickness / 100,
                                       (root.planDepth + root.slabOverhang * 2) / 100)
                    y: root.ceilingHeight + root.slabThickness / 2
                    materials: [ storey.dimmed ? concreteDimMaterial : concreteMaterial ]
                    castsShadows: true
                }

                // ---- perimeter glazing ------------------------------------
                Repeater3D {
                    model: [
                        { x: 0, z: -root.planDepth / 2, w: root.planWidth, d: 1 },
                        { x: 0, z:  root.planDepth / 2, w: root.planWidth, d: 1 },
                        { x: -root.planWidth / 2, z: 0, w: 1, d: root.planDepth },
                        { x:  root.planWidth / 2, z: 0, w: 1, d: root.planDepth }
                    ]

                    delegate: Model {
                        id: pane

                        required property var modelData

                        source: "#Cube"
                        visible: !storey.dimmed
                        position: Qt.vector3d(pane.modelData.x,
                                              root.ceilingHeight / 2,
                                              pane.modelData.z)
                        scale: Qt.vector3d(pane.modelData.w / 100,
                                           root.ceilingHeight / 100,
                                           pane.modelData.d / 100)
                        materials: [ glassMaterial ]
                        // Glass casts no shadow here. Physically it would cast
                        // a faint one; in a shadow map it lands as an opaque
                        // black slab across the floor, which is worse than
                        // none.
                        castsShadows: false
                    }
                }

                // ---- corner mullions --------------------------------------
                Repeater3D {
                    model: [
                        { x: -root.planWidth / 2, z: -root.planDepth / 2 },
                        { x:  root.planWidth / 2, z: -root.planDepth / 2 },
                        { x: -root.planWidth / 2, z:  root.planDepth / 2 },
                        { x:  root.planWidth / 2, z:  root.planDepth / 2 }
                    ]

                    delegate: Model {
                        id: post

                        required property var modelData

                        source: "#Cube"
                        visible: !storey.dimmed
                        position: Qt.vector3d(post.modelData.x,
                                              root.ceilingHeight / 2,
                                              post.modelData.z)
                        scale: Qt.vector3d(root.mullionSize / 100,
                                           root.ceilingHeight / 100,
                                           root.mullionSize / 100)
                        materials: [ mullionMaterial ]
                        castsShadows: true
                    }
                }

                // ---- head and cill rails ----------------------------------
                // The dark horizontal band top and bottom of the glazing. It
                // is what stops the glass reading as a gap between two slabs.
                Repeater3D {
                    model: [
                        { y: root.ceilingHeight - root.mullionSize / 2 },
                        { y: root.mullionSize / 2 }
                    ]

                    delegate: Node {
                        id: rail

                        required property var modelData

                        Repeater3D {
                            model: [
                                { x: 0, z: -root.planDepth / 2,
                                  w: root.planWidth, d: root.mullionSize },
                                { x: 0, z:  root.planDepth / 2,
                                  w: root.planWidth, d: root.mullionSize },
                                { x: -root.planWidth / 2, z: 0,
                                  w: root.mullionSize, d: root.planDepth },
                                { x:  root.planWidth / 2, z: 0,
                                  w: root.mullionSize, d: root.planDepth }
                            ]

                            delegate: Model {
                                id: railBeam

                                required property var modelData

                                source: "#Cube"
                                visible: !storey.dimmed
                                position: Qt.vector3d(railBeam.modelData.x,
                                                      rail.modelData.y,
                                                      railBeam.modelData.z)
                                scale: Qt.vector3d(railBeam.modelData.w / 100,
                                                   root.mullionSize / 100,
                                                   railBeam.modelData.d / 100)
                                materials: [ mullionMaterial ]
                                castsShadows: true
                            }
                        }
                    }
                }

                // ---- rooms --------------------------------------------------
                Repeater3D {
                    model: storey.modelData.cells

                    delegate: Node {
                        id: cell

                        required property var modelData

                        readonly property bool selected:
                            root.selectedRoomId === cell.modelData.roomId

                        // THE DRAWER PULL. A selected room rises out of the
                        // slab, which is the only kind of exploded view that
                        // means anything in a single-storey house - separating
                        // the storeys of a bungalow separates nothing. Off
                        // while walking, where the floor lifting under your
                        // feet is not an explanatory device.
                        position: Qt.vector3d(cell.modelData.cx,
                                              cell.selected && !root.walking
                                                  ? root.roomLift : 0,
                                              cell.modelData.cz)

                        Behavior on position {
                            Vector3dAnimation { duration: Theme.durationNormal
                                                easing.type: Easing.OutCubic }
                        }

                        // Floor finish: a thin inset plate ON the structural
                        // slab, not a slab of its own. This is what gives each
                        // room a readable footprint without a wall around it.
                        Model {
                            source: "#Cube"
                            scale: Qt.vector3d(cell.modelData.w / 100,
                                               root.floorFinishThickness / 100,
                                               cell.modelData.d / 100)
                            y: root.floorFinishThickness / 2
                            materials: [ cell.selected  ? floorSelectedMaterial
                                       : storey.dimmed  ? floorDimMaterial
                                                        : floorMaterial ]
                            receivesShadows: true
                            castsShadows: false

                            // Picking on the FLOOR only. On the walls too and
                            // a click near a boundary hits whichever wall
                            // happens to be nearer the camera.
                            pickable: true
                            // The KIND is encoded, not inferred from the id's
                            // shape: seed data and generated ids use different
                            // prefixes, so anything sniffing an id works for
                            // one and silently not the other.
                            objectName: "room:" + cell.modelData.roomId
                        }

                        // ---- walls, with their doorways ------------------
                        Repeater3D {
                            model: cell.modelData.walls

                            delegate: Model {
                                id: wall

                                required property var modelData

                                source: "#Cube"
                                position: Qt.vector3d(wall.modelData.x,
                                                      root.wallHeight / 2,
                                                      wall.modelData.z)
                                scale: Qt.vector3d(wall.modelData.w / 100,
                                                   root.wallHeight / 100,
                                                   wall.modelData.d / 100)
                                materials: [ storey.dimmed ? wallDimMaterial
                                                           : wallMaterial ]
                                castsShadows: true
                                receivesShadows: true

                                Behavior on scale {
                                    Vector3dAnimation { duration: Theme.durationNormal
                                                        easing.type: Easing.OutCubic }
                                }
                                Behavior on position {
                                    Vector3dAnimation { duration: Theme.durationNormal
                                                        easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // The lintel over each doorway. Only at full height:
                        // a waist-high wall with a header floating above it is
                        // a doorframe with no door in it.
                        Repeater3D {
                            model: cell.modelData.walls

                            delegate: Model {
                                id: lintel

                                required property var modelData

                                readonly property bool horizontal:
                                    lintel.modelData.w > lintel.modelData.d

                                source: "#Cube"
                                // ONE lintel per doorway, not one per piece.
                                // Both pieces of a split wall would place it
                                // at the same point, and two identical cubes
                                // in the same place is a z-fight, not a
                                // thicker header.
                                visible: root.fullHeightWalls && lintel.modelData.door
                                         && (lintel.horizontal
                                             ? lintel.modelData.x > 0
                                             : lintel.modelData.z > 0)
                                // Spans the opening: the piece is offset from
                                // the wall centre by half its own length plus
                                // half the door, so the lintel sits between
                                // the two pieces by construction.
                                position: Qt.vector3d(
                                    lintel.horizontal
                                        ? lintel.modelData.x
                                          - Math.sign(lintel.modelData.x)
                                            * (lintel.modelData.w + root.doorWidth) / 2
                                        : lintel.modelData.x,
                                    root.doorHeight
                                        + (root.wallHeight - root.doorHeight) / 2,
                                    lintel.horizontal
                                        ? lintel.modelData.z
                                        : lintel.modelData.z
                                          - Math.sign(lintel.modelData.z)
                                            * (lintel.modelData.d + root.doorWidth) / 2)
                                scale: Qt.vector3d(
                                    (lintel.horizontal ? root.doorWidth
                                                       : lintel.modelData.w) / 100,
                                    Math.max(1, root.wallHeight - root.doorHeight) / 100,
                                    (lintel.horizontal ? lintel.modelData.d
                                                       : root.doorWidth) / 100)
                                materials: [ storey.dimmed ? wallDimMaterial
                                                           : wallMaterial ]
                                castsShadows: true
                            }
                        }

                        // ---- devices --------------------------------------
                        Repeater3D {
                            model: cell.modelData.devices

                            delegate: Node {
                                id: marker

                                required property var modelData

                                // Standing on the floor, not floating over it:
                                // it sits IN the room like a piece of furniture
                                // instead of hovering above it like a map pin.
                                position: Qt.vector3d(marker.modelData.x, 0,
                                                      marker.modelData.z)
                                visible: !storey.dimmed

                                Repeater3D {
                                    model: root._furniture(marker.modelData.kind)

                                    delegate: Model {
                                        id: part

                                        required property var modelData

                                        source: part.modelData.s
                                        y: part.modelData.y
                                        scale: Qt.vector3d(part.modelData.w / 100,
                                                           part.modelData.h / 100,
                                                           part.modelData.d / 100)
                                        materials: [
                                            marker.modelData.offline ? deviceOfflineMaterial
                                          : marker.modelData.on      ? deviceOnMaterial
                                                                     : deviceOffMaterial ]
                                        castsShadows: true
                                        // Every part is pickable, so a tap on
                                        // the lamp's shade means the lamp
                                        // rather than the room behind it.
                                        pickable: true
                                        objectName: "device:" + marker.modelData.deviceId
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 2D label overlay ---------------------------------------------------
    // Room names when you are outside looking in; device names when you are
    // inside, because standing in a room you already know which room it is.
    Repeater {
        model: root.walking ? [] : root.built

        delegate: Repeater {
            id: labelLayer

            required property var modelData

            model: labelLayer.modelData.cells

            delegate: Item {
                id: label

                required property var modelData

                readonly property bool lifted:
                    root.selectedRoomId === label.modelData.roomId

                // Recomputed whenever the camera moves - see projectionEpoch.
                readonly property vector3d projected: {
                    const epoch = root.projectionEpoch;
                    return view.mapFrom3DScene(Qt.vector3d(
                        label.modelData.cx,
                        labelLayer.modelData.index * root.storeyPitch
                            + (label.lifted ? root.roomLift : 0)
                            + root.wallHeight + 8,
                        label.modelData.cz));
                }

                // z below zero is behind the camera, where x and y are
                // meaningless - drawing them puts labels in mirror positions
                // on the far side of the screen.
                visible: label.projected.z > 0
                         && !root.isDimmed(labelLayer.modelData.floor)
                x: label.projected.x - width / 2
                y: label.projected.y - height
                width: plate.width
                height: plate.height

                Rectangle {
                    id: plate

                    width: caption.implicitWidth + Theme.spacing3 * 2
                    height: caption.implicitHeight + Theme.spacing2 * 2
                    radius: Theme.radiusXs
                    color: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                                   Theme.surfaceDeep.b, 0.84)
                    border.width: Theme.borderWidth
                    border.color: label.lifted ? Theme.primary : Theme.outlineSubtle

                    Column {
                        id: caption
                        anchors.centerIn: parent
                        spacing: 0

                        StLabel {
                            text: label.modelData.name
                            level: 1
                            font.weight: Theme.fontWeightMedium
                        }

                        StLabel {
                            text: qsTr("%1 m²  ·  %2")
                                    .arg(Math.round(label.modelData.areaSqm))
                                    .arg(label.modelData.deviceCount === 1
                                         ? qsTr("1 device")
                                         : qsTr("%1 devices")
                                             .arg(label.modelData.deviceCount))
                            level: 0
                            tone: "muted"
                        }
                    }
                }
            }
        }
    }

    /*! Device names, while walking, for the storey you are on and only within
        arm's reach of the eye - a label on every device in the house at once
        is a wall of text with a room behind it. */
    Repeater {
        model: root.walking && root.built[root.activeIndex] !== undefined
               ? root.built[root.activeIndex].cells : []

        delegate: Repeater {
            id: deviceLayer

            required property var modelData

            model: deviceLayer.modelData.devices

            delegate: Item {
                id: tag

                required property var modelData

                readonly property real sceneX: deviceLayer.modelData.cx + tag.modelData.x
                readonly property real sceneZ: deviceLayer.modelData.cz + tag.modelData.z
                readonly property real distance: {
                    const dx = tag.sceneX - feet.x;
                    const dz = tag.sceneZ - feet.z;
                    return Math.sqrt(dx * dx + dz * dz);
                }

                readonly property vector3d projected: {
                    const epoch = root.projectionEpoch;
                    return view.mapFrom3DScene(Qt.vector3d(
                        tag.sceneX,
                        root.activeIndex * root.storeyPitch + 34,
                        tag.sceneZ));
                }

                visible: tag.projected.z > 0 && tag.distance < 300
                opacity: tag.distance < 220 ? 1 : (300 - tag.distance) / 80
                x: tag.projected.x - width / 2
                y: tag.projected.y - height
                width: tagPlate.width
                height: tagPlate.height

                Rectangle {
                    id: tagPlate

                    width: tagRow.implicitWidth + Theme.spacing3 * 2
                    height: tagRow.implicitHeight + Theme.spacing2 * 2
                    radius: Theme.radiusXs
                    color: Qt.rgba(Theme.surfaceDeep.r, Theme.surfaceDeep.g,
                                   Theme.surfaceDeep.b, 0.88)
                    border.width: Theme.borderWidth
                    border.color: tag.modelData.on ? Theme.primary : Theme.outlineSubtle

                    Row {
                        id: tagRow
                        anchors.centerIn: parent
                        spacing: Theme.spacing2

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: tag.modelData.offline ? Theme.warning
                                 : tag.modelData.on      ? Theme.primary
                                                         : Theme.outlineStrong
                        }

                        StLabel {
                            text: tag.modelData.name
                            level: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    // ---- picking ------------------------------------------------------------
    // One ray cast per tap rather than an input handler per model: Quick3D
    // picking IS a ray cast, and doing it once is cheaper and far more
    // predictable than forty overlapping hit areas.
    //
    // Tap opens, hold operates. Standing next to a lamp the thing you want is
    // the switch, and a first-person view has nowhere to put one.
    TapHandler {
        id: picker

        // Below the walk pad, which declares itself after this and so takes
        // the press first - the pad must never also cast a ray into the room
        // behind it.
        onSingleTapped: tap => root._pickAt(tap.position, false)
        onLongPressed: root._pickAt(picker.point.position, true)
    }

    function _pickAt(position: point, hold: bool): void {
        const hit = view.pick(position.x, position.y);
        if (hit.objectHit === null)
            return;

        const tag = hit.objectHit.objectName;
        const separator = tag.indexOf(":");
        if (separator <= 0)
            return;

        const kind = tag.substring(0, separator);
        const id = tag.substring(separator + 1);

        if (kind === "device") {
            if (hold)
                root.deviceToggleRequested(id);
            else
                root.deviceActivated(id);
            return;
        }

        root.selectedRoomId = id;
        if (root.walking) {
            // Walk there rather than opening it. Inside the house, a tap on
            // the far side of a room means "go and look", and the room's page
            // is a tap on its label away in the list view.
            const storey = root.built[root.activeIndex];
            for (let c = 0; storey !== undefined && c < storey.cells.length; ++c) {
                if (storey.cells[c].roomId !== id)
                    continue;
                feet.targetX = storey.cells[c].cx;
                feet.targetZ = storey.cells[c].cz;
                feet.travelling = true;
                return;
            }
            return;
        }
        root.roomActivated(id);
    }

    // ---- walk controls --------------------------------------------------------
    StWalkPad {
        anchors.fill: parent
        visible: root.walking
        storeyLabel: root.built[root.activeIndex] === undefined
                     ? "" : root.floorName(root.built[root.activeIndex].floor)
        canGoUp: root.activeIndex < root.built.length - 1
        canGoDown: root.activeIndex > 0

        onMoveRequested: (strafe, forward) => {
            feet.strafe = strafe;
            feet.forward = forward;
            if (strafe !== 0 || forward !== 0)
                feet.travelling = false;
        }
        onLookRequested: (dx, dy) => {
            feet.yaw -= dx * 0.28;
            // Clamped, because a first-person camera that can roll past
            // vertical inverts every control the player has just learned.
            feet.pitch = Math.max(-72, Math.min(62, feet.pitch - dy * 0.24));
        }
        onFloorUpRequested: {
            if (root.activeIndex < root.built.length - 1) {
                root.activeFloor = root.built[root.activeIndex + 1].floor;
                root._placeOnStorey(root.activeIndex);
            }
        }
        onFloorDownRequested: {
            if (root.activeIndex > 0) {
                root.activeFloor = root.built[root.activeIndex - 1].floor;
                root._placeOnStorey(root.activeIndex);
            }
        }
    }

    /*!
        A storey's name.

        Duplicated from StRoomMap rather than passed in: this component is
        loaded by URL and cannot import the one that loads it, and one line of
        wording is a smaller price than an interface for it.
    */
    function floorName(floor: int): string {
        if (floor === 0)
            return qsTr("Ground");
        if (floor < 0)
            return floor === -1 ? qsTr("Basement") : qsTr("Basement %1").arg(-floor);
        return qsTr("Floor %1").arg(floor);
    }
}
