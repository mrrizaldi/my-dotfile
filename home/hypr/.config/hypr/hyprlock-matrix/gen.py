#!/usr/bin/env python3
"""Render the hyprlock Matrix theme frames (matches SDDM TerminalStyleLogin + MatrixHud).

hyprlock can't animate, but background/image widgets can swap pictures every second
(reload_cmd + reload_time, background also crossfades). So this pre-renders:
  rain/NN.png  matrix rain, glyphs fixed per cell, the bright "drop" moves down
  hud/NN.png   HUD rings, each ring rotated by a small step that loops seamlessly
Only 1 update/s is possible, so motion per frame is kept small (rain ~3 rows,
rings 1-5 deg) and the background crossfades almost the whole second.
Run once (needs ImageMagick `magick`). Re-run after editing the knobs below.
"""
import math, os, random, shutil, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
RAIN_FRAMES = 24                   # 1 frame/s; more frames = smaller step per second
HUD_FRAMES = 72                    # 1 frame/s -> 72 s loop, rings creep 1-5 deg/s

# ---- knobs (same values as the SDDM theme) ----
GREEN = (0x00, 0xFF, 0x41)
HEAD = (0xD8, 0xFF, 0xD8)          # bright leading glyph
RAIN_OPACITY = 0.55                # SDDM MatrixRain opacity
W, H, CELL = 1920, 1080, 18        # SDDM size; 1440p just scales it up (rain is soft anyway)
TRAIL = (14, 28)                   # min/max glyphs in a drop's fading tail (random per drop)
GLYPH_FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
GLYPHS = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789Z:.=*+-<>"
HUD = 620                          # px; SDDM MatrixHud is 460, rings below scale with it
HUD_INTENSITY = 0.45               # SDDM ring group opacity

random.seed(1337)  # deterministic: re-running gives the same theme


def rgba(c, a):
    return f"rgba({c[0]},{c[1]},{c[2]},{a:.3f})"


def render(mvg, size, out, bg):
    # Debian's ImageMagick policy blocks `-draw @file`; reading the file via the MVG coder is allowed.
    path = out + ".mvg"
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"viewbox 0 0 {size[0]} {size[1]}\n" + mvg)
    # Light PNGs: hyprlock refuses a new frame while the previous one is still decoding,
    # and that also stalls label (clock) updates. 8-bit, palette for the opaque rain.
    fmt = ["-depth", "8", "-colors", "96", f"PNG8:{out}"] if bg == "black" else ["-depth", "8", f"PNG32:{out}"]
    subprocess.run(["magick", "-background", bg, f"mvg:{path}", *fmt], check=True)
    os.remove(path)


def esc(ch):
    return ch.replace("\\", "\\\\").replace("'", "\\'")


def rain():
    cols, rows = W // CELL, H // CELL
    cycle = rows + TRAIL[1]                   # rows a drop travels before it wraps
    grid = [[random.choice(GLYPHS) for _ in range(rows)] for _ in range(cols)]
    drops = []                                 # (column, start offset, tail length); one speed = no big jumps
    for c in range(cols):
        for _ in range(random.choice((1, 1, 2))):
            drops.append((c, random.randrange(cycle), random.randint(*TRAIL)))
    out = fresh_dir("rain")
    for f in range(RAIN_FRAMES):
        cells = {}
        for c, off, trail in drops:
            head = (off + f * cycle // RAIN_FRAMES) % cycle
            for t in range(trail):
                r = head - t
                if 0 <= r < rows:
                    a = (1 - t / trail) ** 1.6 * RAIN_OPACITY
                    if a > cells.get((c, r), (0,))[0]:
                        cells[(c, r)] = (a, t == 0)
        mvg = [f"font '{GLYPH_FONT}'", f"font-size {CELL - 2}", "stroke none"]
        for (c, r), (a, is_head) in cells.items():
            ch = grid[c][r] if random.random() > 0.02 else random.choice(GLYPHS)  # a few glyphs flicker
            col = HEAD if is_head else GREEN
            mvg += [f"fill '{rgba(col, min(1, a * 1.4) if is_head else a)}'",
                    f"text {c * CELL},{(r + 1) * CELL - 4} '{esc(ch)}'"]
        render("\n".join(mvg), (W, H), os.path.join(out, f"{f:02d}.png"), "black")


# (radius, arcs, span°, line width, opacity, direction) - SDDM HudRing set.
# Each ring turns one symmetry period (360/arcs) per HUD loop, so the last frame
# flows into the first: 1.25° / 1.7° / 5° / 0.8° per second.
RINGS = [
    (210, 4, 20, 2, 0.50, -1),     # counter-clockwise
    (180, 3, 70, 2, 1.00, 1),
    (135, 1, 270, 3, 0.80, 1),     # SDDM 120 - pushed out for padding around clock/password
    (115, 6, 25, 2, 0.60, -1),     # SDDM 95  - same
]
TICKS = (155, 60, 2, 0.70)         # radius, count, width, opacity (static: a 6° period is invisible)


def fresh_dir(name):
    d = os.path.join(HERE, name)
    shutil.rmtree(d, ignore_errors=True)   # next.sh counts the files, so no stale frames
    os.makedirs(d)
    return d


def hud():
    c = HUD / 2
    out = fresh_dir("hud")
    for f in range(HUD_FRAMES):
        k = HUD / 460                     # ring radii are in SDDM (460 px) units
        mvg = ["fill 'rgba(0,0,0,0.75)'", "stroke none", f"circle {c},{c} {c},{c - 220 * k}", "fill none"]
        for radius, arcs, span, lw, op, direction in RINGS:
            rot = direction * f * (360 / arcs) / HUD_FRAMES
            mvg += [f"stroke '{rgba(GREEN, op * HUD_INTENSITY)}'", f"stroke-width {lw}"]
            for i in range(arcs):
                a0 = rot + i * 360 / arcs
                mvg.append(f"ellipse {c},{c} {radius * k:.1f},{radius * k:.1f} {a0:.2f},{a0 + span:.2f}")
        radius, count, lw, op = TICKS
        mvg += [f"stroke '{rgba(GREEN, op * HUD_INTENSITY)}'", f"stroke-width {lw}"]
        for i in range(count):
            ang = math.radians(i * 360 / count)
            r0, r1 = radius * k - 6, radius * k + 6
            mvg.append(f"line {c + r0 * math.cos(ang):.2f},{c + r0 * math.sin(ang):.2f} "
                       f"{c + r1 * math.cos(ang):.2f},{c + r1 * math.sin(ang):.2f}")
        render("\n".join(mvg), (HUD, HUD), os.path.join(out, f"{f:02d}.png"), "none")


if __name__ == "__main__":
    import sys
    parts = sys.argv[1:] or ["rain", "hud"]   # e.g. `gen.py hud` to redo only the rings
    if "rain" in parts:
        rain()
    if "hud" in parts:
        hud()
    print("frames written to", HERE)
