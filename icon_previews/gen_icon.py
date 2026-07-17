from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), color="#141414")  # 深炭灰背景
draw = ImageDraw.Draw(img)

TILE_W, TILE_H = 460, 500
TILE_X = (SIZE - TILE_W) // 2
TILE_Y = (SIZE - TILE_H) // 2 + 8
RADIUS = 56

HEADER_H = 120
BODY_Y = TILE_Y + HEADER_H

# Header: dark / near-black
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill="#1C1C1C"
)
# Fix top corners of body (straight join at divider)
draw.rectangle([TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H], fill="#FFFFFF")
draw.rounded_rectangle(
    [TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill="#FFFFFF"
)
draw.rectangle([TILE_X, TILE_Y + RADIUS, TILE_X + TILE_W, BODY_Y], fill="#1C1C1C")

# Binding holes
HOLE_R = 20
HOLE_Y = TILE_Y - HOLE_R + 8
for hx in [TILE_X + TILE_W // 3, TILE_X + 2 * TILE_W // 3]:
    draw.ellipse([hx - HOLE_R, HOLE_Y - HOLE_R, hx + HOLE_R, HOLE_Y + HOLE_R],
                 fill="#141414")

# Divider line (sharp separation header / body)
draw.line([(TILE_X, BODY_Y), (TILE_X + TILE_W, BODY_Y)], fill="#E0E0E0", width=2)

# Tile outline (subtle, on white body blends into white)
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, outline="#DDDDDD", width=3
)

# Center dot (dark on white body)
cx = SIZE // 2
cy = BODY_Y + (TILE_Y + TILE_H - BODY_Y) // 2 + 4
DOT_R = 54
draw.ellipse([cx - DOT_R, cy - DOT_R, cx + DOT_R, cy + DOT_R], fill="#1A1A1A")

REPO = "/datadisk/loomi-ait/volumes/u-d414d4ccdc9a1daf8d8409bd38243f28/sessions/9eb2c364-50ed-479f-b813-cd392cfe7576/repos/everyday_counts-963b3825"
img.save(f"{REPO}/icon_previews/icon_black_A.png")
print("done")
