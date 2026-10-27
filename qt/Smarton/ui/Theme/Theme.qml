pragma Singleton

import QtQuick
import SmarTon.Backend

/*!
    \qmltype Theme
    \inqmlmodule SmarTon.Ui.Theme
    \brief Single source of truth for colour, metric, type and motion tokens.

    SmarTon ships ONE dark theme. There is no light variant and no runtime
    switch - the product runs on a single fixed panel.

    Colours come from \c DesignTokens (C++), taken verbatim from Figma. The
    one exception is \l primary, which reads from \c Appearance so the user's
    accent choice reaches every control through the token they already bind to.
    Metrics below are measured from the 1440x1024 Figma exports and reflowed
    for the 1024x600 Waveshare panel: control heights, radii and type sizes are
    preserved so touch targets and weight match the design; only the LAYOUT is
    re-composed for the wider, shorter aspect.

    NAMING TRAP: never start a property with "on" + a capital letter. QML reads
    onBackground: as a handler for a signal named "background".
*/
QtObject {
    id: root

    // ---- target panel -----------------------------------------------------
    readonly property int  screenWidth:  1024
    readonly property int  screenHeight: 600
    /*! Figma frames are 1440x1024. Kept for reference when comparing. */
    readonly property real designWidth:  1440
    readonly property real designHeight: 1024

    // ---- colour (all from DesignTokens, all exact Figma hex) --------------
    readonly property color background:    DesignTokens.background      // #202326
    readonly property color surfaceDeep:   DesignTokens.surfaceDeep     // #101113
    readonly property color surface:       DesignTokens.surface         // #2D3542
    readonly property color surfaceAlt:    DesignTokens.surfaceAlt      // #2A3240
    readonly property color surfaceRaised: DesignTokens.surfaceRaised   // #40464D
    readonly property color outline:       DesignTokens.outline         // #555C67
    readonly property color outlineSubtle: DesignTokens.outlineSubtle   // #606873
    /*! Measured on the space picker's border. A control sitting ON the dark
        header band needs a stronger edge than one on the page ground. */
    readonly property color outlineStrong: DesignTokens.outlineStrong   // #808B9A
    readonly property color overlay:       DesignTokens.overlay         // #FFFFFF 20%
    /*! Measured on the conditions-strip cards: they are LIGHTER than the band
        they sit on. Drawn darker, they vanished into it. */
    readonly property color overlaySubtle: DesignTokens.overlaySubtle   // #FFFFFF 15%

    readonly property color textPrimary:   DesignTokens.textPrimary     // #FFFFFF
    readonly property color textSecondary: DesignTokens.textSecondary   // #D9DFE6
    readonly property color textMuted:     DesignTokens.textMuted       // #B3BECD
    readonly property color textDisabled:  DesignTokens.textDisabled    // #606873
    readonly property color textOnActive:  DesignTokens.textOnActive    // #D1E6FF

    /*!
        The one colour a user can change (Profile > Preferences). Reads from
        \c Appearance, not \c DesignTokens, so every control that already
        binds to Theme.primary follows the choice with no further work -
        which is the whole reason the token existed in the first place.

        \c DesignTokens.primary stays the Figma #E25319 and is what Appearance
        hands back when nothing has been chosen.
    */
    readonly property color primary:       Appearance.accentColor       // #E25319 default
    /*! Text and icons drawn ON \l primary. Measured contrast, so a pale accent
        gets dark text instead of a white-on-yellow label - with one exception:
        at the DEFAULT accent the design's own white wins over the measured
        answer, so adding a picker does not restyle the brand (ADR-0014).
        Use this for anything sitting on a primary fill - never textPrimary,
        which is white and only correct while the accent stays dark. */
    readonly property color textOnPrimary: Appearance.accentForeground
    readonly property color focus:         DesignTokens.focus           // #1268CC
    readonly property color info:          DesignTokens.info            // #1874FF
    readonly property color infoDeep:      DesignTokens.infoDeep        // #0C4180
    readonly property color infoSoft:      DesignTokens.infoSoft        // #74B4FF
    readonly property color success:       DesignTokens.success         // #31AA7A
    readonly property color successSoft:   DesignTokens.successSoft     // #9EEACC
    readonly property color warning:       DesignTokens.warning         // #F5BA41
    readonly property color warningSoft:   DesignTokens.warningSoft     // #FFD67B
    readonly property color danger:        DesignTokens.danger          // #E31D1C
    readonly property color accentViolet:     DesignTokens.accentViolet
    readonly property color accentVioletSoft: DesignTokens.accentVioletSoft

    /*! The thermostat dial's ring, measured #606974 on frame 22. Its own
        token because it sits between outline and outlineStrong and is not the
        midpoint of either - approximating it with a neighbour was tried and
        the ring read a step too dark against the card. */
    readonly property color dialRing:  DesignTokens.dialRing
    /*! The progress arc over that ring. */
    readonly property color dialTrack: DesignTokens.textSecondary

    // ---- theme ---------------------------------------------------------------
    /*!
        Which skin is active. Read it to CHOOSE a treatment, never to guess a
        colour - every colour still comes from a token, and a component that
        branches on this to hard-code a hex has defeated the point of both
        themes existing.
    */
    readonly property bool glass: Appearance.glassTheme
    /*! Per-frame GPU budget: 0 plain, 1 gradients and glow, 2 full glass. */
    readonly property int  renderTier: Appearance.renderTier
    readonly property bool blurEnabled: Appearance.blurEnabled
    readonly property bool particlesEnabled: Appearance.particlesEnabled

    /*!
        Backdrop blur radius for glass surfaces, already zeroed on machines
        that cannot afford it - so callers bind to it rather than each
        re-deciding whether blur is allowed.
    */
    readonly property real glassBlur: root.glass && root.blurEnabled ? 0.62 : 0.0
    /*! Fill behind a glass surface. Translucent enough to show the backdrop,
        opaque enough that text on it stays readable when the backdrop is
        busy - which is the failure mode of every glass UI. */
    readonly property color glassFill:      Qt.rgba(1, 1, 1, 0.07)
    readonly property color glassFillRaised: Qt.rgba(1, 1, 1, 0.11)
    /*! The bright hairline along a glass edge. What actually sells the
        material - a translucent panel without one reads as a smudge. */
    readonly property color glassRim:       Qt.rgba(1, 1, 1, 0.22)
    readonly property color glassRimStrong: Qt.rgba(1, 1, 1, 0.34)

    /*! Page-level wash behind everything, in the accent's hue. The vibrance
        comes from HERE rather than from the surfaces, so the surfaces can stay
        neutral and text on them stays legible. */
    readonly property color auroraOne:   Qt.rgba(root.primary.r, root.primary.g,
                                                 root.primary.b, 0.30)
    readonly property color auroraTwo:   Qt.rgba(root.info.r, root.info.g,
                                                 root.info.b, 0.24)
    readonly property color auroraThree: Qt.rgba(root.accentViolet.r, root.accentViolet.g,
                                                 root.accentViolet.b, 0.22)

    // ---- interaction states -----------------------------------------------
    /*!
        Every interactive component reacts in the same four ways, so the
        amounts live here rather than being re-invented per control:

        \list
        \li hover  - a light film, pointer only; touch has no hover
        \li press  - a darker film, plus the control's own colour shift
        \li focus  - the 2 px #1268CC ring from the design
        \li disabled - reduced opacity AND a muted colour, never opacity alone
        \endlist

        Opacity alone is not enough for disabled: at 0.5 an orange button is
        still the most saturated thing on screen and still reads as the primary
        action. The colour has to move too, which is what disabledFill() does.
    */
    readonly property real hoverOverlay:    0.07
    readonly property real pressOverlay:    0.12
    readonly property real disabledOpacity: 0.45

    /*! Default border for inputs when they are idle. Without one an input is
        just a filled rectangle, and people do not know they can type in it.
        Measured #606873 on frame 27's account fields - outlineSubtle, not
        outline, which is a shade darker and read as almost no border at all. */
    readonly property color fieldBorder:      DesignTokens.outlineSubtle
    readonly property color fieldBorderHover: DesignTokens.outlineStrong

    // ---- window -----------------------------------------------------------
    /*! Never smaller than the design: below this, layouts are being judged at
        a size nothing was drawn for. Never wider than the max either - a
        1024-wide three-column grid stretched to 3840 is not a design. */
    readonly property int windowMinWidth:  1024
    readonly property int windowMinHeight:  600
    readonly property int windowMaxWidth:  1600
    readonly property int windowMaxHeight:  980
    /*! Content stops growing here and centres instead. */
    readonly property int contentMaxWidth: 1440
    readonly property int scrollBarWidth:     6

    // ---- spacing (4 px base) ---------------------------------------------
    readonly property int spacing1:  4
    readonly property int spacing2:  8
    readonly property int spacing3: 12
    readonly property int spacing4: 16
    readonly property int spacing5: 20
    readonly property int spacing6: 24
    readonly property int spacing8: 32
    readonly property int spacing10: 40

    // ---- radii ------------------------------------------------------------
    /*!
        Measured off the exports by scanning the top row of each rounded rect
        for where the fill starts - see design/measurements.md.

        radiusLg was 16, which was invented. Nothing in the design is 16: the
        largest measured corner is the 12-13 px on a device card. A card drawn
        at 16 reads noticeably softer than the frame beside it, which is most
        of why the built screens looked "close but not right".
    */
    readonly property int radiusXs:   8    // conditions-strip cards
    readonly property int radiusSm:   10   // space picker, sidebar pill
    readonly property int radius:     12   // fields, buttons, cards
    readonly property int radiusLg:   13   // device and room cards
    /*! Measured 18 on the pale summary card (frames 13-17, 24-25). It is the
        only element in the design with a corner this large, which is part of
        how it reads as a fixed reference above changing content. */
    readonly property int radiusXl:   18
    readonly property int radiusPill: 999

    // ---- control metrics (Figma heights preserved) -----------------------
    /*! Figma input 478x52; button 480x54. 52 px on a 169 ppi panel is 7.8 mm,
        comfortably above the 7 mm touch minimum. */
    readonly property int controlHeight:      52
    readonly property int controlHeightSm:    44
    /*! Figma auth column is 480 of 1440. Kept at 480 on the 1024 panel:
        shrinking it would change control proportions, and 480 of 1024 still
        leaves a comfortable 272 px gutter either side. */
    readonly property int fieldWidth:        480
    readonly property int borderWidth:         1
    readonly property int borderWidthFocus:    2   // measured on the Login email field

    /*! Sidebar: measured 279 of 1440 = 19.4%; 198 px of 1024 keeps the ratio. */
    readonly property int sidebarWidth:      198
    /*! Where "Profile & Settings" starts to elide. */
    readonly property int sidebarMinWidth:   168
    /*! Beyond this the rail stops being a rail: on a 1024 panel a 320 px
        sidebar leaves 698 for a three-column grid, which is already tight. */
    readonly property int sidebarMaxWidth:   320
    readonly property int navItemHeight:      46   // measured 220x46
    /*! Measured 30 of 279 = 10.8%, so 21 on the 198 px rail. Was 16, which
        pulled every nav row too close to the edge. */
    readonly property int navItemInset:       21

    // ---- page rhythm ------------------------------------------------------
    /*!
        The header band is WIDER than the content beneath it. Measured: the
        band spans 320..1400 while the content column is 350..1370 - 30 px of
        bleed on each side. Everything shared one margin, which is why the
        built dashboard read as a stack of same-width slabs rather than a band
        with content sitting inside it.
    */
    readonly property int pageMargin:         28
    readonly property int bandBleed:          12
    readonly property int cardGap:            18   // measured 25 of 1440
    readonly property int cardGapV:           20   // measured 28 of 1440
    readonly property int touchTarget:        44

    // ---- type -------------------------------------------------------------
    /*! Resolved at startup by backend::Typography - never a hard-coded family.
        A hard-coded "Segoe UI" existed here and silently substituted on every
        platform that is not Windows, including the target panel. */
    readonly property string fontFamily: Typography.family
    readonly property int fontSizeDisplay: 30      // Figma 34, tightened for 600 px height
    readonly property int fontSizeTitle:   22
    readonly property int fontSizeSubtitle:16
    readonly property int fontSizeBody:    14
    readonly property int fontSizeLabel:   14
    readonly property int fontSizeCaption: 12
    readonly property int fontWeightRegular: Font.Normal
    readonly property int fontWeightMedium:  Font.Medium
    readonly property int fontWeightBold:    Font.DemiBold

    // ---- elevation --------------------------------------------------------
    /*!
        Tiles in the Figma sit on a soft drop shadow. It is drawn with
        MultiEffect, which is a GPU blur pass per elevated item - cheap on a
        desktop, not free on the panel's Mali GPU with a dozen tiles on screen.

        One switch turns the whole system off, so the embedded build can drop
        the cost in a single place rather than by editing every card. Off, the
        cards keep their border and read correctly - the shadow is depth, not
        information.
    */
    readonly property bool  shadowsEnabled: Appearance.shadowsEnabled
    readonly property color shadowColor:    Qt.rgba(0, 0, 0, 0.55)
    readonly property real  shadowBlur:     0.85   // 0..1, MultiEffect scale
    readonly property int   shadowOffsetY:  6
    readonly property int   shadowMaxBlur:  28

    // ---- motion -----------------------------------------------------------
    readonly property int durationFast:   120
    readonly property int durationNormal: 200
    readonly property int durationSlow:   320
    readonly property int splashDwell:   1800

    /*!
        \qmlmethod color Theme::hoveredFill(color base, bool on)
        The base colour lifted for hover. A no-op when \a on is false, so
        callers can write hoveredFill(c, control.hovered) with no ternary.
    */
    function hoveredFill(base: color, on: bool): color {
        return on ? Qt.lighter(base, 1 + root.hoverOverlay * 2) : base;
    }

    /*!
        \qmlmethod color Theme::pressedFill(color base)
        The base colour pushed down for the pressed state.
    */
    function pressedFill(base: color): color {
        return Qt.darker(base, 1 + root.pressOverlay);
    }

    /*!
        \qmlmethod color Theme::disabledFill(color base)
        Desaturated toward the surface, so a disabled control stops competing
        for attention instead of merely fading.
    */
    function disabledFill(base: color): color {
        return Qt.tint(root.surfaceRaised, Qt.rgba(base.r, base.g, base.b, 0.28));
    }

    /*!
        \qmlmethod color Theme::textOn(color fill)
        Black or white, whichever is readable on \a fill, by measured WCAG
        contrast rather than by eye.

        Use it wherever the fill is not known at author time - a swatch, a
        chip tinted with a room's colour, anything the user picked. Where the
        fill IS the accent, \l textOnPrimary says so more clearly.
    */
    function textOn(fill: color): color {
        return Appearance.readableOn(fill);
    }

    /*!
        \qmlmethod bool Theme::isLight(color fill)
        Is \a fill a pale ground - i.e. does dark text belong on it?

        Answered by the same measurement \l textOn uses, so the two can never
        disagree. A control on an unknown ground picks its text with textOn()
        and its other treatments with this.
    */
    function isLight(fill: color): bool {
        return Appearance.readableOn(fill) !== root.textPrimary;
    }

    /*!
        \qmlmethod color Theme::surfaceFor(color solid)
        The fill a card-like surface should use in the ACTIVE theme.

        One call instead of `Theme.glass ? something : solid` repeated in
        twenty components - which is how the two themes drift apart, because
        the twenty-first component forgets. The Figma theme returns the
        measured colour untouched; the glass theme returns a translucent film
        that lets the page wash through.
    */
    function surfaceFor(solid: color): color {
        return root.glass ? root.glassFill : solid;
    }

    /*!
        \qmlmethod color Theme::borderFor(color solid)
        The matching edge. Glass needs a bright rim where the Figma treatment
        needs a dark outline; they are opposite in value, which is exactly why
        this cannot be one shared constant.
    */
    function borderFor(solid: color): color {
        return root.glass ? root.glassRim : solid;
    }

    /*!
        \qmlmethod color Theme::stateColor(int severity)
        0 normal, 1 warning, 2 critical.
    */
    function stateColor(severity: int): color {
        switch (severity) {
        case 2:  return root.danger;
        case 1:  return root.warning;
        default: return root.success;
        }
    }
}
