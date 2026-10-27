.pragma library

/*!
    Value and unit formatting shared across every module.

    .pragma library means one shared instance for the whole application
    instead of a copy per importing QML file — cheaper, and stateless
    functions cannot be corrupted by one caller.
*/

/** Rounds to \a decimals and returns a locale-independent string. */
function number(value, decimals) {
    if (value === undefined || value === null || isNaN(value))
        return "--"
    return Number(value).toFixed(decimals === undefined ? 0 : decimals)
}

/** "42 cmH2O", or "--" when the value is missing. */
function withUnit(value, unit, decimals) {
    var text = number(value, decimals)
    return unit && text !== "--" ? text + " " + unit : text
}

/** Clamps \a value into [\a lo, \a hi]. */
function clamp(value, lo, hi) {
    return Math.max(lo, Math.min(hi, value))
}

/** Position of \a value within [\a lo, \a hi], normalised to [0, 1]. */
function normalise(value, lo, hi) {
    if (hi <= lo)
        return 0
    return clamp((value - lo) / (hi - lo), 0, 1)
}

/** "Normal" / "Warning" / "Critical". */
function severityName(severity) {
    switch (severity) {
    case 2:  return qsTr("Critical")
    case 1:  return qsTr("Warning")
    default: return qsTr("Normal")
    }
}
