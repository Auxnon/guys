#!/usr/bin/env python3
"""Generate guys' sprite sheets into assets/.

    python3 tools/gen_art.py

Draws in the style of items.png's little guy: big head, flat colours, and a
dark outline added automatically around every shape. Sheets are 16px tiles,
so the engine slices `sol.16.png` into sol0, sol1, ... row by row.

sol.16.png  8 frames x 7 rows: our soldier, their soldier, our commander,
            their commander (all with pistols), a civilian, our unarmed
            militia (civvies and one of our helmets) and their unarmed
            conscript. Frames (facing right): 0 idle, 1 walk a, 2 walk b,
            3 shoot, 4 punch, 5 arms up (falling, cheering, carrying),
            6 dead, 7 blade slash.
fx.16.png   effects, ring dots, crates, flags and icons (see FX below).
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "assets")

OUTLINE = (29, 26, 43, 255)
SKIN = (242, 199, 154, 255)
SKIN_D = (215, 154, 106, 255)
EYE = (29, 26, 43, 255)
GUN = (88, 92, 110, 255)
GUN_L = (150, 156, 172, 255)
BOOT = (66, 46, 38, 255)
RED = (196, 52, 52, 255)
GOLD = (240, 196, 64, 255)
WHITE = (250, 246, 236, 255)

TEAMS = {
    # ours: orange shirts like the guy in items.png, olive helmets
    "us": dict(coat=(230, 120, 40, 255), coat_d=(184, 84, 30, 255),
               hat=(112, 124, 64, 255), hat_d=(80, 90, 46, 255),
               pants=(96, 78, 60, 255)),
    # theirs: slate blue, grey helmets with a red band
    "them": dict(coat=(86, 104, 168, 255), coat_d=(60, 74, 126, 255),
                 hat=(132, 136, 150, 255), hat_d=(92, 96, 110, 255),
                 pants=(52, 56, 72, 255)),
    # civilians: linen shirts, brown trousers
    "civ": dict(coat=(214, 200, 168, 255), coat_d=(176, 160, 128, 255),
                hat=(112, 124, 64, 255), hat_d=(80, 90, 46, 255),
                pants=(120, 86, 58, 255)),
}
BLADE = (214, 222, 232, 255)
HILT = (120, 80, 40, 255)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height:
                im.putpixel((x, y), c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def outline(im):
    """Every clear pixel touching an opaque one (4-way) becomes outline."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height:
                    if src.getpixel((nx, ny))[3] != 0 and src.getpixel((nx, ny)) != OUTLINE:
                        im.putpixel((x, y), OUTLINE)
                        break
    return im


def head(im, t, hat, hx, hy):
    """Head with its top-left at (hx, hy), facing right; 8 wide, 7 tall."""
    rect(im, hx, hy + 2, hx + 7, hy + 6, SKIN)
    rect(im, hx, hy + 5, hx + 1, hy + 6, SKIN_D)
    px(im, hx + 6, hy + 4, EYE)
    px(im, hx + 6, hy + 3, WHITE)
    px(im, hx + 7, hy + 6, SKIN_D)
    # chin: a dark line between head and collar, so the coat doesn't read as a beard
    rect(im, hx + 1, hy + 7, hx + 7, hy + 7, OUTLINE)
    px(im, hx + 5, hy + 6, SKIN_D)
    if hat == "cap":
        # peaked officer's cap with a gold badge, peak forward
        rect(im, hx, hy, hx + 7, hy + 2, t["hat"])
        rect(im, hx, hy + 2, hx + 7, hy + 2, RED)
        rect(im, hx + 6, hy + 2, hx + 9, hy + 2, t["hat_d"])
        px(im, hx + 4, hy + 1, GOLD)
    elif hat == "bald":
        # bald like the guy in items.png: a highlight and a tuft
        px(im, hx + 3, hy + 3, WHITE)
        rect(im, hx + 1, hy + 1, hx + 6, hy + 1, SKIN)
        px(im, hx, hy + 2, SKIN_D)
    else:
        # round helmet with a brim all the way round
        rect(im, hx + 1, hy, hx + 6, hy, t["hat"])
        rect(im, hx, hy + 1, hx + 7, hy + 2, t["hat"])
        rect(im, hx - 1, hy + 2, hx + 8, hy + 2, t["hat_d"])


def body(im, t, cmd, armed, frame):
    """Torso, arms and legs for one frame. Ground is y 15."""
    coat, coat_d, pants = t["coat"], t["coat_d"], t["pants"]
    # legs: (back x, front x) shift per frame
    legs = {1: (-1, 1), 2: (1, -1)}.get(frame, (0, 0))
    lb, lf = legs
    rect(im, 5 + lb, 12, 6 + lb, 13, pants)
    rect(im, 5 + lb, 14, 6 + lb, 14, BOOT)
    rect(im, 8 + lf, 12, 9 + lf, 13, pants)
    rect(im, 8 + lf, 14, 9 + lf, 14, BOOT)
    # torso
    rect(im, 4, 8, 10, 11, coat)
    rect(im, 4, 8, 4, 11, coat_d)
    rect(im, 4, 11, 10, 11, coat_d)  # belt line
    if cmd:
        # a red sash, shoulder to hip
        for i in range(4):
            px(im, 9 - i, 8 + i, RED)
            px(im, 8 - i, 8 + i, RED)
    # back arm hangs, front arm by frame
    rect(im, 3, 9, 3, 10, coat_d)
    px(im, 3, 11, SKIN_D)
    if frame == 3 and armed:  # shoot: arm out, pistol level
        rect(im, 10, 9, 12, 9, coat)
        px(im, 13, 9, SKIN)
        rect(im, 13, 8, 15, 8, GUN)
        px(im, 13, 9, GUN_L)
    elif frame == 7:  # slash: blade swung forward and up
        rect(im, 10, 9, 12, 9, coat)
        px(im, 13, 9, SKIN)
        px(im, 13, 10, HILT)
        for i in range(5):
            px(im, 13 + (i + 1) // 2, 8 - i, BLADE)
    elif frame == 4 or (frame == 3 and not armed):  # punch: fist out
        rect(im, 10, 9, 13, 9, coat)
        rect(im, 14, 8, 15, 9, SKIN)
    elif frame == 5:  # arms up (falling / cheering / carrying)
        rect(im, 12, 5, 12, 8, coat)
        px(im, 11, 8, coat)
        px(im, 12, 4, SKIN)
        rect(im, 1, 6, 1, 8, coat_d)
        px(im, 2, 8, coat_d)
        px(im, 1, 5, SKIN_D)
    else:  # at the side, pistol pointing down
        rect(im, 9, 9, 9, 10, coat)
        px(im, 9, 11, SKIN)
        if armed:
            rect(im, 10, 11, 10, 12, GUN)


def guy(t, hat, armed, cmd, frame):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    hy = 1
    if frame in (1, 2):
        hy = 2 if frame == 1 else 1
    body(im, t, cmd, armed, frame)
    head(im, t, hat, 3, hy)
    if frame == 6:
        # dead: on its back, head to the left, at the bottom of the tile
        im = im.rotate(90, expand=False)
        shifted = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        shifted.paste(im, (0, 5), im)
        im = shifted
        px(im, 5, 12, OUTLINE)  # closed eye
    if frame == 5:
        px(im, 9, 6, EYE)  # open mouth: falling
    return outline(im)


def sheet_sol():
    rows = [
        (TEAMS["us"], "helmet", True, False),
        (TEAMS["them"], "helmet", True, False),
        (TEAMS["us"], "cap", True, True),
        (TEAMS["them"], "cap", True, True),
        (TEAMS["civ"], "bald", False, False),
        (TEAMS["civ"], "helmet", False, False),
        (TEAMS["them"], "helmet", False, False),
    ]
    out = Image.new("RGBA", (16 * 8, 16 * len(rows)), (0, 0, 0, 0))
    for r, (t, hat, armed, cmd) in enumerate(rows):
        for f in range(8):
            out.paste(guy(t, hat, armed, cmd, f), (f * 16, r * 16))
    out.save(os.path.join(ASSETS, "sol.16.png"))


# -- fx ---------------------------------------------------------------------

def blank():
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def disc(im, cx, cy, r, c):
    for y in range(16):
        for x in range(16):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                im.putpixel((x, y), c)


def fx_flash():
    im = blank()
    disc(im, 7.5, 7.5, 5.5, (255, 200, 60, 230))
    disc(im, 7.5, 7.5, 3.5, (255, 240, 160, 255))
    disc(im, 7.5, 7.5, 1.5, WHITE)
    for i in range(16):
        if i % 4 == 0:
            px(im, i, 7, (255, 220, 90, 255))
            px(im, 7, i, (255, 220, 90, 255))
    return im


def fx_tracer():
    im = blank()
    disc(im, 7.5, 7.5, 3, (255, 210, 80, 140))
    disc(im, 7.5, 7.5, 1.6, (255, 250, 200, 255))
    return im


def fx_dust():
    im = blank()
    for cx, cy, r in ((5, 9, 4), (10, 9, 3.5), (8, 6, 3.5)):
        disc(im, cx, cy, r, (214, 200, 176, 200))
    disc(im, 6, 8, 2, (240, 232, 214, 220))
    return im


def fx_spark():
    im = blank()
    c = (255, 236, 140, 255)
    for i in range(3, 13):
        px(im, i, 7, c)
        px(im, 7, i, c)
    for i in range(5, 11):
        px(im, i, i, (255, 180, 60, 255))
        px(im, i, 14 - i, (255, 180, 60, 255))
    disc(im, 7, 7, 1.2, WHITE)
    return im


def fx_dot(c, core):
    im = blank()
    disc(im, 7.5, 7.5, 4.5, c)
    disc(im, 7.5, 7.5, 2.5, core)
    return im


def fx_pow():
    im = blank()
    pts = [(7, 1), (9, 5), (14, 4), (11, 8), (14, 13), (8, 11), (4, 14), (5, 9), (1, 6), (6, 5)]
    # filled star by scanning against a polygon
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    d.polygon(pts, fill=(255, 250, 220, 255))
    d.polygon([(7, 4), (9, 7), (11, 8), (9, 10), (7, 11), (6, 8)], fill=(255, 196, 60, 255))
    return outline(im)


def crate(icon):
    im = blank()
    wood = (176, 122, 70, 255)
    wood_d = (128, 84, 48, 255)
    rect(im, 1, 4, 14, 14, wood)
    rect(im, 1, 4, 14, 5, wood_d)
    rect(im, 1, 9, 14, 9, wood_d)
    icon(im)
    return outline(im)


def icon_megaphone(im):
    rect(im, 4, 7, 6, 11, GOLD)
    for i in range(4):
        rect(im, 7 + i, 6 - i // 2, 7 + i, 12 + i // 2, (230, 180, 50, 255))
    px(im, 5, 12, OUTLINE)


def icon_radio(im):
    rect(im, 3, 7, 12, 12, (70, 84, 60, 255))
    rect(im, 4, 8, 7, 11, (40, 46, 36, 255))
    px(im, 9, 9, RED)
    px(im, 11, 9, GOLD)
    rect(im, 10, 1, 10, 6, OUTLINE)


def icon_speaker(im):
    rect(im, 3, 6, 12, 13, (60, 60, 70, 255))
    disc(im, 7.5, 9.5, 2.6, (150, 150, 160, 255))
    disc(im, 7.5, 9.5, 1, OUTLINE)
    rect(im, 2, 2, 13, 3, GOLD)


def flag(c, c_d):
    im = blank()
    rect(im, 3, 1, 3, 15, (110, 80, 50, 255))
    rect(im, 4, 2, 12, 7, c)
    rect(im, 4, 6, 12, 7, c_d)
    px(im, 13, 3, c)
    px(im, 13, 4, c)
    return outline(im)


def reticle():
    im = blank()
    c = (255, 240, 120, 255)
    for i in range(16):
        for j in range(16):
            d = ((i - 7.5) ** 2 + (j - 7.5) ** 2) ** 0.5
            if 5.5 <= d <= 7 and not (abs(i - 7.5) < 2 or abs(j - 7.5) < 2):
                im.putpixel((i, j), c)
    disc(im, 7.5, 7.5, 1, c)
    return im


def chevron(c):
    im = blank()
    for i in range(6):
        rect(im, 2 + i, 4 + i, 13 - i, 4 + i, c)
    rect(im, 5, 1, 10, 3, c)
    return outline(im)


def glyph(rows, c):
    im = blank()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                px(im, x + 5, y + 2, c)
    return outline(im)


QUESTION = [".###.", "#...#", "....#", "...#.", "..#..", "..#..", ".....", "..#.."]
BANG = ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#..", "....."]


def star():
    im = blank()
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    d.polygon([(7, 1), (9, 6), (14, 6), (10, 9), (12, 14), (7, 11), (3, 14), (5, 9), (1, 6), (6, 6)],
              fill=GOLD)
    return outline(im)


def cloud():
    im = blank()
    for cx, cy, r in ((5, 9, 4), (10, 9, 4.5), (8, 6, 4), (12, 10, 3)):
        disc(im, cx, cy, r, (250, 250, 255, 210))
    return im


def pickup_gun():
    im = blank()
    rect(im, 3, 7, 12, 8, GUN)
    rect(im, 3, 7, 5, 7, GUN_L)
    rect(im, 10, 9, 12, 12, HILT)
    px(im, 9, 9, GUN)
    return outline(im)


def pickup_ammo():
    im = blank()
    rect(im, 3, 7, 12, 13, (92, 104, 64, 255))
    rect(im, 3, 7, 12, 8, (70, 80, 48, 255))
    for x in (5, 8, 11):
        rect(im, x, 4, x, 6, GOLD)
        px(im, x, 3, (190, 110, 60, 255))
    return outline(im)


def pickup_blade():
    im = blank()
    for i in range(9):
        px(im, 4 + i, 12 - i, BLADE)
        px(im, 5 + i, 12 - i, (170, 180, 196, 255))
    rect(im, 2, 12, 4, 14, HILT)
    rect(im, 3, 11, 5, 11, GOLD)
    return outline(im)


def shell():
    im = blank()
    rect(im, 5, 6, 10, 13, (60, 64, 70, 255))
    rect(im, 6, 4, 9, 5, (60, 64, 70, 255))
    rect(im, 7, 3, 8, 3, (60, 64, 70, 255))
    rect(im, 5, 11, 10, 11, GOLD)
    rect(im, 6, 6, 6, 10, (110, 116, 124, 255))
    return outline(im)


def shell_pile():
    im = blank()
    wood = (150, 104, 60, 255)
    rect(im, 1, 11, 14, 14, wood)
    rect(im, 1, 11, 14, 11, (110, 76, 44, 255))
    for x in (2, 6, 10):
        rect(im, x, 5, x + 3, 10, (60, 64, 70, 255))
        rect(im, x + 1, 3, x + 2, 4, (60, 64, 70, 255))
        rect(im, x, 9, x + 3, 9, GOLD)
    return outline(im)


def cannon():
    im = blank()
    iron = (52, 56, 64, 255)
    for i in range(9):
        rect(im, 4 + i, 8 - i // 3, 5 + i, 10 - i // 3, iron)
    rect(im, 13, 4, 14, 7, (40, 42, 48, 255))
    rect(im, 5, 7, 7, 8, (96, 100, 110, 255))
    disc(im, 6, 12, 3, (130, 90, 52, 255))
    disc(im, 6, 12, 1, (80, 54, 30, 255))
    rect(im, 1, 12, 3, 14, (110, 76, 44, 255))
    return outline(im)


def pips(n):
    im = blank()
    for i in range(n):
        y = 11 - i * 4
        for k in range(4):
            px(im, 4 + k, y + k // 2 + (1 if k == 0 or k == 3 else 0) - 1, GOLD)
            px(im, 11 - k, y + k // 2 + (1 if k == 0 or k == 3 else 0) - 1, GOLD)
        rect(im, 7, y + 1, 8, y + 1, GOLD)
    return outline(im)


def explosion(r, core):
    im = blank()
    disc(im, 7.5, 7.5, r, (240, 120, 40, 230))
    disc(im, 7.5, 7.5, r * 0.7, (255, 200, 80, 255))
    disc(im, 7.5, 7.5, r * 0.35, core)
    return im


# Indices are fixed: scripts refer to fx<N> by these (see art.lua).
FX = [
    fx_flash(),                                                 # 0 muzzle flash
    fx_tracer(),                                                # 1 bullet
    fx_dust(),                                                  # 2 dust
    fx_spark(),                                                 # 3 hit spark
    fx_dot((255, 210, 70, 220), (255, 246, 190, 255)),          # 4 ring: selected
    fx_dot((214, 200, 170, 150), (240, 232, 214, 200)),         # 5 ring: other commander
    fx_dot((220, 60, 60, 200), (255, 150, 140, 230)),           # 6 ring: enemy
    fx_pow(),                                                   # 7 punch
    crate(icon_megaphone),                                      # 8 megaphone crate
    crate(icon_radio),                                          # 9 radio crate
    crate(icon_speaker),                                        # 10 sound system crate
    flag((230, 120, 40, 255), (184, 84, 30, 255)),              # 11 our flag
    flag((86, 104, 168, 255), (60, 74, 126, 255)),              # 12 their flag
    reticle(),                                                  # 13 cursor on the ground
    chevron((255, 220, 90, 255)),                               # 14 selected commander
    glyph(QUESTION, WHITE),                                     # 15 lost soldier
    glyph(BANG, (255, 90, 70, 255)),                            # 16 alert
    star(),                                                     # 17 promoted
    cloud(),                                                    # 18 cloud puff
    fx_dot((120, 220, 255, 200), (220, 250, 255, 255)),         # 19 ring: radio relay
    pickup_gun(),                                               # 20 pistol on the ground
    pickup_ammo(),                                              # 21 box of rounds
    pickup_blade(),                                             # 22 blade
    shell(),                                                    # 23 cannon shell (carried)
    shell_pile(),                                               # 24 munitions pile
    cannon(),                                                   # 25 cannon
    pips(1),                                                    # 26 level 1
    pips(2),                                                    # 27 level 2
    pips(3),                                                    # 28 level 3
    explosion(7.5, WHITE),                                      # 29 blast
    fx_dot((60, 200, 90, 200), (190, 255, 200, 255)),           # 30 ring: civilians' town
]


def sheet_fx():
    cols = 8
    rows = (len(FX) + cols - 1) // cols
    out = Image.new("RGBA", (16 * cols, 16 * rows), (0, 0, 0, 0))
    for i, im in enumerate(FX):
        out.paste(im, ((i % cols) * 16, (i // cols) * 16))
    out.save(os.path.join(ASSETS, "fx.16.png"))


def icon():
    """The game's icon: our commander, 4x."""
    im = guy(TEAMS["us"], "cap", True, True, 5).resize((64, 64), Image.NEAREST)
    bg = Image.new("RGBA", (64, 64), (121, 153, 204, 255))
    bg.paste(im, (0, 0), im)
    bg.save(os.path.join(ASSETS, "icon.png"))
    bg.save(os.path.join(HERE, "..", "icon.png"))


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    sheet_sol()
    sheet_fx()
    icon()
    print("wrote sol.16.png, fx.16.png, icon.png")
