#pragma once

#include <QtCore/QObject>
#include <QtGui/QColor>
#include <QtQml/qqml.h>
#include <QtQml/qqmlprivate.h>
#include <QtQml/qqmlregistration.h>

namespace smarton::backend {

/**
 * @brief The SmarTon design tokens, taken verbatim from Figma.
 *
 * Every value below is an exact hex from the Figma file's selection-colour
 * panel or measured from the 1440x1024 exports - none are approximations.
 *
 * SmarTon ships a **single dark theme**. There is deliberately no light
 * variant and no runtime switch: the product runs on one fixed panel, and a
 * second theme would double the review surface for no user benefit. If one is
 * ever needed, add it here rather than scattering colours through QML.
 *
 * @note Exposed to QML as a singleton so QML never hard-codes a colour.
 */
class DesignTokens : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // --- surfaces ----------------------------------------------------------
    Q_PROPERTY(QColor background     READ background     CONSTANT)
    Q_PROPERTY(QColor surfaceDeep    READ surfaceDeep    CONSTANT)
    Q_PROPERTY(QColor surface        READ surface        CONSTANT)
    Q_PROPERTY(QColor surfaceAlt     READ surfaceAlt     CONSTANT)
    Q_PROPERTY(QColor surfaceRaised  READ surfaceRaised  CONSTANT)
    Q_PROPERTY(QColor outline        READ outline        CONSTANT)
    Q_PROPERTY(QColor outlineSubtle  READ outlineSubtle  CONSTANT)
    Q_PROPERTY(QColor outlineStrong  READ outlineStrong  CONSTANT)
    Q_PROPERTY(QColor dialRing       READ dialRing       CONSTANT)
    Q_PROPERTY(QColor overlaySubtle  READ overlaySubtle  CONSTANT)
    Q_PROPERTY(QColor overlay        READ overlay        CONSTANT)

    // --- text --------------------------------------------------------------
    Q_PROPERTY(QColor textPrimary    READ textPrimary    CONSTANT)
    Q_PROPERTY(QColor textSecondary  READ textSecondary  CONSTANT)
    Q_PROPERTY(QColor textMuted      READ textMuted      CONSTANT)
    Q_PROPERTY(QColor textDisabled   READ textDisabled   CONSTANT)
    Q_PROPERTY(QColor textOnActive   READ textOnActive   CONSTANT)

    // --- brand and state ---------------------------------------------------
    Q_PROPERTY(QColor primary        READ primary        CONSTANT)
    Q_PROPERTY(QColor primaryForeground READ primaryForeground CONSTANT)
    Q_PROPERTY(QColor focus          READ focus          CONSTANT)
    Q_PROPERTY(QColor info           READ info           CONSTANT)
    Q_PROPERTY(QColor infoDeep       READ infoDeep       CONSTANT)
    Q_PROPERTY(QColor infoSoft       READ infoSoft       CONSTANT)
    Q_PROPERTY(QColor success        READ success        CONSTANT)
    Q_PROPERTY(QColor successSoft    READ successSoft    CONSTANT)
    Q_PROPERTY(QColor warning        READ warning        CONSTANT)
    Q_PROPERTY(QColor warningSoft    READ warningSoft    CONSTANT)
    Q_PROPERTY(QColor danger         READ danger         CONSTANT)
    Q_PROPERTY(QColor accentViolet   READ accentViolet   CONSTANT)
    Q_PROPERTY(QColor accentVioletSoft READ accentVioletSoft CONSTANT)

public:
    explicit DesignTokens(QObject *parent = nullptr) : QObject(parent) {}

    // Surfaces -------------------------------------------------------------
    static QColor background()    { return QColor(0x20, 0x23, 0x26); } // #202326 page
    static QColor surfaceDeep()   { return QColor(0x10, 0x11, 0x13); } // #101113 sidebar
    static QColor surface()       { return QColor(0x2D, 0x35, 0x42); } // #2D3542 inputs, cards
    static QColor surfaceAlt()    { return QColor(0x2A, 0x32, 0x40); } // #2A3240
    static QColor surfaceRaised() { return QColor(0x40, 0x46, 0x4D); } // #40464D
    static QColor outline()       { return QColor(0x55, 0x5C, 0x67); } // #555C67
    static QColor outlineSubtle() { return QColor(0x60, 0x68, 0x73); } // #606873
    /*! Measured on the space picker's border. Lighter than outlineSubtle and
        genuinely a separate value - a control that sits ON the dark band needs
        a stronger edge than one on the page ground. */
    static QColor outlineStrong() { return QColor(0x80, 0x8B, 0x9A); } // #808B9A
    static QColor dialRing()      { return QColor(0x60, 0x69, 0x74); } // #606974 frame 22
    /*! White at 15%. Measured on the conditions-strip cards, which sit on the
        band and are LIGHTER than it - they were drawn darker and vanished. */
    static QColor overlaySubtle() { return QColor(0xFF, 0xFF, 0xFF, 0x26); }
    static QColor overlay()       { return QColor(0xFF, 0xFF, 0xFF, 51); } // #FFFFFF @20%

    // Text -----------------------------------------------------------------
    static QColor textPrimary()   { return QColor(0xFF, 0xFF, 0xFF); } // #FFFFFF
    static QColor textSecondary() { return QColor(0xD9, 0xDF, 0xE6); } // #D9DFE6
    static QColor textMuted()     { return QColor(0xB3, 0xBE, 0xCD); } // #B3BECD
    static QColor textDisabled()  { return QColor(0x60, 0x68, 0x73); } // #606873
    static QColor textOnActive()  { return QColor(0xD1, 0xE6, 0xFF); } // #D1E6FF

    // Brand and state ------------------------------------------------------
    static QColor primary()       { return QColor(0xE2, 0x53, 0x19); } // #E25319
    /**
     * What the design draws ON \l primary: white, on every primary button in
     * the Figma.
     *
     * Recorded as its own token because it is a DEVIATION, and one worth being
     * able to see. White on #E25319 measures 3.83:1 - fine for the large
     * button text it is used at, below the 4.5:1 the same size would need as
     * body text, and beaten by near-black at 4.93:1. So a purely derived
     * foreground would flip every primary button in the app to dark text and
     * stop matching the design.
     *
     * Changing the brand's own look is a design decision, not something an
     * accent-picker feature should do on its way past. This token is what
     * Appearance returns while the accent is the default; a colour the user
     * picks, which the design never reviewed, gets a measured foreground.
     * Change this one line to adopt the measured answer.
     */
    static QColor primaryForeground() { return QColor(0xFF, 0xFF, 0xFF); } // #FFFFFF
    static QColor focus()         { return QColor(0x12, 0x68, 0xCC); } // #1268CC focus ring
    static QColor info()          { return QColor(0x18, 0x74, 0xFF); } // #1874FF
    static QColor infoDeep()      { return QColor(0x0C, 0x41, 0x80); } // #0C4180
    static QColor infoSoft()      { return QColor(0x74, 0xB4, 0xFF); } // #74B4FF
    static QColor success()       { return QColor(0x31, 0xAA, 0x7A); } // #31AA7A
    static QColor successSoft()   { return QColor(0x9E, 0xEA, 0xCC); } // #9EEACC
    static QColor warning()       { return QColor(0xF5, 0xBA, 0x41); } // #F5BA41
    static QColor warningSoft()   { return QColor(0xFF, 0xD6, 0x7B); } // #FFD67B
    static QColor danger()        { return QColor(0xE3, 0x1D, 0x1C); } // #E31D1C
    static QColor accentViolet()     { return QColor(0x73, 0x44, 0x97); } // #734497
    static QColor accentVioletSoft() { return QColor(0xD6, 0xBC, 0xFA); } // #D6BCFA
};

} // namespace smarton::backend
