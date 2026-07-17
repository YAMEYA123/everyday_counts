from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), color="#1E1E1E")  # 深炭灰背景
draw = ImageDraw.Draw(img)

TILE_W, TILE_H = 440, 480
TILE_X = (SIZE - TILE_W) // 2
TILE_Y = (SIZE - TILE_H) // 2 + 10
RADIUS = 52
LINE_W = 9

HEADER_H = 110
header_color = "#2A2A2A"

# Header
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill=header_color
)
# Body
BODY_Y = TILE_Y + HEADER_H
draw.rectangle([TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H], fill="#1A1A1A")
draw.rounded_rectangle(
    [TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill="#1A1A1A"
)
draw.rectangle(
    [TILE_X, TILE_Y + RADIUS, TILE_X + TILE_W, BODY_Y],
    fill=header_color
)

# Binding holes
HOLE_R = 18
HOLE_Y = TILE_Y - HOLE_R + 6
for hx in [TILE_X + TILE_W // 3, TILE_X + 2 * TILE_W // 3]:
    draw.ellipse([hx - HOLE_R, HOLE_Y - HOLE_R, hx + HOLE_R, HOLE_Y + HOLE_R],
                 fill="#1E1E1E")

# Divider
draw.line([(TILE_X, BODY_Y), (TILE_X + TILE_W, BODY_Y)], fill="#3A3A3A", width=2)

# Outline
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, outline="#E8E8E8", width=LINE_W
)

# Center dot
body_center_x = SIZE // 2
body_center_y = BODY_Y + (TILE_Y + TILE_H - BODY_Y) // 2 + 6
DOT_R = 52
draw.ellipse(
    [body_center_x - DOT_R, body_center_y - DOT_R,
     body_center_x + DOT_R, body_center_y + DOT_R],
    fill="#F0F0F0"
)

REPO = "/datadisk/loomi-ait/volumes/u-d414d4ccdc9a1daf8d8409bd38243f28/sessions/9eb2c364-50ed-479f-b813-cd392cfe7576/repos/everyday_counts-963b3825"
img.save(f"{REPO}/icon_previews/icon_black_A.png")
img.save(f"{REPO}/EverydayCounts/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
print("done")
