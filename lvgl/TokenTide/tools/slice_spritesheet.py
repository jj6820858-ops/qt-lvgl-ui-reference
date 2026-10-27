#!/usr/bin/env python3
"""Slice a flat-magenta spritesheet into the saver fauna sprites.

Input: a grid spritesheet on a single flat magenta background (the color
is sampled from the top-left corner, so slight off-magenta is fine).
Output: trimmed RGBA sprites in assets/sprites/, sized for the big
(320x240) and small (240x135) screens, with -l/-r mirrored variants for
directional creatures, plus a preview.png contact sheet on the real
sky/sea colors to eyeball edge quality.

Usage: slice_spritesheet.py <spritesheet.png> <out_dir>
"""

import sys
from PIL import Image

# name -> (grid row, grid col, native facing or None, big width, small width)
# Facing marks which way the sheet art points; -r/-l variants are emitted
# for directional sprites by mirroring. None = symmetric, single file.
SPRITES = {
    "fish-orange": (0, 0, "r", 36, 22),
    "fish-yellow": (0, 1, "r", 40, 24),
    "fish-teal": (0, 2, "l", 36, 22),
    "seahorse": (0, 3, "r", 28, 18),
    "fish-purple": (1, 0, "r", 64, 38),
    "jellyfish": (1, 1, None, 44, 26),
    "octopus": (1, 2, None, 56, 32),
    "shark": (1, 3, "r", 96, 52),
    "bubbles": (2, 0, None, 36, 22),
    "seaweed": (2, 1, None, 56, 32),
    "seagull": (2, 2, "r", 48, 28),
    "bat": (2, 3, "r", 40, 24),
    "star": (3, 0, "r", 56, 32),
    "ufo": (3, 1, None, 48, 28),
    "plane": (3, 2, "r", 64, 36),
}

KEY_FUZZ = 100      # euclidean RGB distance to the key color -> background
FRINGE_FUZZ = 130   # edge pixels closer than this to the key -> dropped
MERGE_RADIUS = 24   # parts closer than this merge into one sprite (bubbles)


def color_dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def build_mask(img, key):
    """1 = sprite pixel, 0 = background."""
    w, h = img.size
    px = img.load()
    fuzz2 = KEY_FUZZ ** 2
    mask = [[0] * w for _ in range(h)]
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if color_dist2(px[x, y], key) > fuzz2:
                row[x] = 1
    return mask


def find_components(mask, w, h):
    """Bounding boxes of connected components, merged within MERGE_RADIUS."""
    seen = [[False] * w for _ in range(h)]
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if not mask[sy][sx] or seen[sy][sx]:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            x0 = x1 = sx
            y0 = y1 = sy
            npx = 0
            while stack:
                x, y = stack.pop()
                npx += 1
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if npx >= 12:  # ignore stray specks
                boxes.append([x0, y0, x1, y1])
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if (a[0] - MERGE_RADIUS <= b[2] and b[0] - MERGE_RADIUS <= a[2]
                        and a[1] - MERGE_RADIUS <= b[3] and b[1] - MERGE_RADIUS <= a[3]):
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]),
                                max(a[2], b[2]), max(a[3], b[3])]
                    del boxes[j]
                    merged = True
                    break
            if merged:
                break
    return boxes


def extract(img, box, key):
    """Crop -> RGBA with keyed background and edge defringe."""
    x0, y0, x1, y1 = box
    crop = img.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGB")
    w, h = crop.size
    px = crop.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    key2 = KEY_FUZZ ** 2
    fringe2 = FRINGE_FUZZ ** 2
    alpha = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if color_dist2(px[x, y], key) > key2:
                alpha[y][x] = 1
    for y in range(h):
        for x in range(w):
            if not alpha[y][x]:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or nx >= w or ny < 0 or ny >= h or not alpha[ny][nx]:
                    edge = True
                    break
            # Edge pixels still tinted toward the key are keying residue.
            if edge and color_dist2(px[x, y], key) < fringe2:
                continue
            r, g, b = px[x, y]
            opx[x, y] = (r, g, b, 255)
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    out_dir = sys.argv[2].rstrip("/")
    w, h = sheet.size
    key = sheet.getpixel((2, 2))
    print(f"sheet {w}x{h}, key color {key}")

    mask = build_mask(sheet, key)
    boxes = find_components(mask, w, h)
    print(f"{len(boxes)} sprites found")

    # Assign boxes to grid cells by center point.
    cell_w, cell_h = w / 4.0, h / 4.0
    by_cell = {}
    for box in boxes:
        cx = (box[0] + box[2]) / 2.0
        cy = (box[1] + box[3]) / 2.0
        by_cell[(int(cy // cell_h), int(cx // cell_w))] = box

    previews = []
    for name, (row, col, facing, big_w, small_w) in SPRITES.items():
        box = by_cell.get((row, col))
        if box is None:
            print(f"MISSING: {name} at cell ({row},{col})")
            continue
        sprite = extract(sheet, box, key)
        for label, target_w in (("big", big_w), ("small", small_w)):
            ratio = target_w / sprite.width
            scaled = sprite.resize(
                (target_w, max(1, round(sprite.height * ratio))), Image.LANCZOS)
            if facing is None:
                scaled.save(f"{out_dir}/{name}-{label}.png")
            else:
                mirrored = scaled.transpose(Image.FLIP_LEFT_RIGHT)
                right, left = (scaled, mirrored) if facing == "r" else (mirrored, scaled)
                right.save(f"{out_dir}/{name}-{label}-r.png")
                left.save(f"{out_dir}/{name}-{label}-l.png")
            if label == "big":
                previews.append(scaled)
        print(f"{name}: box {box} -> big {big_w}px, small {small_w}px")

    # Contact sheet on the real saver colors: top half sky, bottom half sea.
    pad = 8
    pw = sum(p.width + pad for p in previews) + pad
    ph = max(p.height for p in previews) * 2 + 3 * pad
    contact = Image.new("RGBA", (pw, ph), (0, 0, 0, 255))
    for y in range(ph // 2, ph):
        for x in range(pw):
            contact.putpixel((x, y), (0x1D, 0x4E, 0x79, 255))
    x = pad
    for p in previews:
        contact.alpha_composite(p, (x, pad))
        contact.alpha_composite(p, (x, ph // 2 + pad))
        x += p.width + pad
    contact.save(f"{out_dir}/preview.png")
    print(f"preview: {out_dir}/preview.png")


if __name__ == "__main__":
    main()
