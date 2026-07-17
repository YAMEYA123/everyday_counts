from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), color="#080808")
draw = ImageDraw.Draw(img)

# Calendar tile dimensions
TILE_W, TILE_H = 440, 480
TILE_X = (SIZE - TILE_W) // 2
TILE_Y = (SIZE - TILE_H) // 2 + 10
RADIUS = 52
LINE_W = 9

# Header bar (calendar top strip)
HEADER_H = 110
header_color = "#1A1A1A"
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill=header_color
)
# Body of tile (slightly lighter)
BODY_Y = TILE_Y + HEADER_H
draw.rectangle(
    [TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    fill="#111111"
)
# Bottom rounded corners fix
draw.rounded_rectangle(
    [TILE_X, BODY_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, fill="#111111"
)
# Re-fill header area on top of above rounded rect
draw.rectangle(
    [TILE_X, TILE_Y + RADIUS, TILE_X + TILE_W, BODY_Y],
    fill=header_color
)

# Two binding holes at top of header
HOLE_R = 18
HOLE_Y = TILE_Y - HOLE_R + 6
for hx in [TILE_X + TILE_W // 3, TILE_X + 2 * TILE_W // 3]:
    draw.ellipse([hx - HOLE_R, HOLE_Y - HOLE_R, hx + HOLE_R, HOLE_Y + HOLE_R],
                 fill="#080808")

# Divider line between header and body
draw.line([(TILE_X, BODY_Y), (TILE_X + TILE_W, BODY_Y)],
          fill="#2A2A2A", width=2)

# Tile outline (white, thin)
draw.rounded_rectangle(
    [TILE_X, TILE_Y, TILE_X + TILE_W, TILE_Y + TILE_H],
    radius=RADIUS, outline="#E8E8E8", width=LINE_W
)

# Center dot in body area
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
print("saved icon_black_A.png")
