pragma Singleton
import QtQml

/*!
    \qmltype FloorPlanHelper
    \inqmlmodule SmarTon.Ui.Helpers
    \brief Turns a list of rooms into a floor plan, from the only spatial fact
           the model actually holds.

    THE PROBLEM. Frame 18 draws devices pinned onto a floor plan. A real floor
    plan is survey data - wall positions, doorways, orientation - and SmarTon
    has none of it: a room is a name, an area and a device count. The view was
    therefore shipped as a placeholder saying so.

    THE DECISION. Do not fake walls. Generate a PLAN FROM AREA, which is real
    data, and let it look like what it is: a proportional plan where each room
    occupies space in the same ratio it does in the house. A 32 m² living room
    is visibly twice a 16 m² bedroom. Nobody can navigate their actual hallway
    with it, and nobody is invited to - but "which room is big, which devices
    are where" is answered correctly, and that is what the frame's map is FOR.

    THE ALGORITHM is a squarified treemap (Bruls, Huizing & van Wijk 2000).
    Slice-and-dice - the obvious approach - lays rooms in strips and produces
    slivers: a 4 m² bathroom becomes a 400x12 splinter that cannot hold a
    label, let alone a device pin. Squarifying picks the split that keeps each
    rectangle's aspect ratio closest to 1, so every room stays a room-shaped
    box. It is also deterministic: the same rooms in the same order always
    produce the same plan, which matters because a floor plan that reshuffles
    when a lamp is renamed is not a map of anything.

    WHY IN THE VIEW LAYER. This is not a fact about the home - the house does
    not have these rectangles. It is a way of DRAWING the home, chosen by this
    screen, and a different screen could reasonably choose another. Putting it
    in the domain would state as truth something the product does not know.
*/
QtObject {
    id: root

    /*! Below this, a rectangle cannot hold its own label. */
    readonly property int minCell: 72

    /*!
        \a rooms is a list of { roomId, name, areaSqm, deviceCount }.
        Returns the same records with x, y, w, h added, laid out inside
        \a width x \a height.

        Rooms with no area are given the median of those that have one, so a
        half-configured house still produces a plan instead of a pile of
        zero-width rectangles.
    */
    function layout(rooms: var, width: real, height: real): var {
        if (!rooms || rooms.length === 0 || width <= 0 || height <= 0)
            return [];

        const known = rooms.map(r => Number(r.areaSqm) || 0).filter(a => a > 0);
        const fallback = known.length > 0
                       ? known.slice().sort((a, b) => a - b)[Math.floor(known.length / 2)]
                       : 1;

        // Largest first. Squarifying only produces square-ish tiles if the big
        // ones are placed while there is still room to choose; fed smallest
        // first it degenerates to slice-and-dice.
        const items = rooms.map((r, i) => ({
            source: r,
            order: i,
            area: (Number(r.areaSqm) || 0) > 0 ? Number(r.areaSqm) : fallback
        })).sort((a, b) => b.area - a.area || a.order - b.order);

        const total = items.reduce((sum, it) => sum + it.area, 0);
        const scale = (width * height) / total;
        items.forEach(it => { it.scaled = it.area * scale; });

        const out = [];
        root._squarify(items, { x: 0, y: 0, w: width, h: height }, out);

        // Back to the caller's original order, so a Repeater's delegates do not
        // reshuffle every time an area is edited.
        return out.sort((a, b) => a.order - b.order)
                  .map(it => ({
                      roomId: it.source.roomId,
                      name: it.source.name,
                      areaSqm: it.source.areaSqm,
                      deviceCount: it.source.deviceCount,
                      x: it.x, y: it.y, w: it.w, h: it.h
                  }));
    }

    /*! Worst (i.e. largest) aspect ratio in \a row if laid along \a side. */
    function _worstRatio(row: var, side: real): real {
        if (row.length === 0 || side <= 0)
            return Infinity;
        let sum = 0;
        let min = Infinity;
        let max = 0;
        for (let i = 0; i < row.length; ++i) {
            const a = row[i].scaled;
            sum += a;
            min = Math.min(min, a);
            max = Math.max(max, a);
        }
        if (sum <= 0 || min <= 0)
            return Infinity;
        const s2 = side * side;
        const sum2 = sum * sum;
        return Math.max((s2 * max) / sum2, sum2 / (s2 * min));
    }

    /*! Places \a row along the short side of \a rect; returns what is left. */
    function _placeRow(row: var, rect: var, out: var): var {
        let sum = 0;
        for (let i = 0; i < row.length; ++i)
            sum += row[i].scaled;
        if (sum <= 0)
            return rect;

        const horizontal = rect.w >= rect.h;
        // Thickness of the band this row occupies: its total area over the
        // side it runs along.
        const band = horizontal ? sum / rect.h : sum / rect.w;

        let offset = 0;
        for (let i = 0; i < row.length; ++i) {
            const it = row[i];
            const extent = it.scaled / band;
            if (horizontal) {
                it.x = rect.x;          it.y = rect.y + offset;
                it.w = band;            it.h = extent;
            } else {
                it.x = rect.x + offset; it.y = rect.y;
                it.w = extent;          it.h = band;
            }
            offset += extent;
            out.push(it);
        }

        return horizontal
            ? { x: rect.x + band, y: rect.y, w: Math.max(0, rect.w - band), h: rect.h }
            : { x: rect.x, y: rect.y + band, w: rect.w, h: Math.max(0, rect.h - band) };
    }

    /*! Iterative, not recursive: a deep house would otherwise be a deep stack,
        and this runs on every resize. */
    function _squarify(items: var, rect: var, out: var): void {
        let remaining = items.slice();
        let area = rect;
        let row = [];

        while (remaining.length > 0) {
            const side = Math.min(area.w, area.h);
            if (side <= 0)
                break;

            const next = remaining[0];
            const grown = row.concat([next]);

            // Keep adding to this row while doing so makes the shapes rounder.
            // The moment it makes them worse, close the row and start again in
            // what is left - that comparison IS the algorithm.
            if (row.length === 0
                || root._worstRatio(grown, side) <= root._worstRatio(row, side)) {
                row = grown;
                remaining.shift();
            } else {
                area = root._placeRow(row, area, out);
                row = [];
            }
        }

        if (row.length > 0)
            root._placeRow(row, area, out);
    }
}
