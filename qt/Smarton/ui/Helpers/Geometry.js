.pragma library

/*! Geometry helpers for arc and dial drawing. */

var TAU = Math.PI * 2

/** Degrees to radians. */
function rad(degrees) {
    return degrees * Math.PI / 180
}

/** Point on a circle of radius \a r about (\a cx, \a cy) at \a angle radians. */
function pointOnCircle(cx, cy, r, angle) {
    return Qt.point(cx + r * Math.cos(angle), cy + r * Math.sin(angle))
}

/** Largest radius that fits a stroke of \a stroke inside \a w x \a h. */
function fitRadius(w, h, stroke) {
    return Math.max(0, Math.min(w, h) / 2 - stroke)
}
