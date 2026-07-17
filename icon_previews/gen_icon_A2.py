"""
Icon A2: Full-bleed calendar design
- Entire canvas IS the calendar (iOS squircle clips the corners)
- Dark header bar (~22% height) at top
- White dot centered in body
- Two small binding rings at top edge
"""
from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), color="#0C0C0C")
draw = ImageDraw.Draw(img)

# Header strip (~22% of height)
HEADER_H = int(SIZE * 0.22)
HEADER_COLOR = "#161616"
draw.rectangle([0, 0, SIZE, HEADER_H], fill=HEADER_COLOR)

# Subtle divider
draw.line([(0, HEADER_H), (SIZE, HEADER_H)], fill="#2C2C2C", width=3)

# Binding rings (two circles straddling the top edge of header)
RING_R = 36
RING_Y = HEADER_H - 2  # sit on the divider line
for rx in [SIZE // 3, SIZE * 2 // 3]:
    # Ring shadow/cutout
    draw.ellipse([rx - RING_R, RING_Y - RING_R, rx + RING_R, RING_Y + RING_R],
                 fill="#0C0C0C", outline="#383838", width=5)

# Center dot
CX, CY = SIZE // 2, HEADER_H + (SIZE - HEADER_H) // 2 + 10
DOT_R = 68
draw.ellipse([CX - DOT_R, CY - DOT_R, CX + DOT_R, CY + DOT_R], fill="#EBEBEB")

REPO = "/datadisk/loomi-ait/volumes/u-d414d4ccdc9a1daf8d8409bd38243f28/sessions/9eb2c364-50ed-479f-b813-cd392cfe7576/repos/everyday_counts-963b3825"
img.save(f"{REPO}/icon_previews/icon_black_A2.png")
print("saved icon_black_A2.png")
