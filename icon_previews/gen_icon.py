from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), color="#FFFFFF")
draw = ImageDraw.Draw(img)

HEADER_H = int(SIZE * 0.24)
BODY_Y = HEADER_H

# Header: black
draw.rectangle([0, 0, SIZE, HEADER_H], fill="#111111")
# Body: dark gray
draw.rectangle([0, BODY_Y, SIZE, SIZE], fill="#383838")
draw.line([(0, BODY_Y), (SIZE, BODY_Y)], fill="#1A1A1A", width=4)

# Binding rings
HOLE_R = 20
HOLE_Y = BODY_Y + HOLE_R + 22
for hx in [SIZE // 3, SIZE * 2 // 3]:
    draw.ellipse([hx - HOLE_R, HOLE_Y - HOLE_R,
                  hx + HOLE_R, HOLE_Y + HOLE_R],
                 outline="#FFFFFF", width=5, fill="#383838")

# ── Camera body ──
cx = SIZE // 2
body_usable_top = HOLE_Y + HOLE_R + 40
body_bottom = SIZE - 60
cy = (body_usable_top + body_bottom) // 2

CAM_W, CAM_H = 380, 260
CAM_R = 36
cam_x0 = cx - CAM_W // 2
cam_y0 = cy - CAM_H // 2
cam_x1 = cx + CAM_W // 2
cam_y1 = cy + CAM_H // 2

# Camera body rectangle
draw.rounded_rectangle([cam_x0, cam_y0, cam_x1, cam_y1],
                        radius=CAM_R, fill="#FFFFFF")

# Shutter bump on top-center
BUMP_W, BUMP_H = 110, 44
bump_x0 = cx - BUMP_W // 2
bump_x1 = cx + BUMP_W // 2
bump_y0 = cam_y0 - BUMP_H + 6
bump_y1 = cam_y0 + 6
draw.rounded_rectangle([bump_x0, bump_y0, bump_x1, bump_y1],
                        radius=14, fill="#FFFFFF")

# Lens circle (centered on camera body, slightly above vertical center)
lens_cy = cy + 8
LENS_OR = 88   # outer radius
LENS_IR = 62   # inner (dark)
LENS_CR = 22   # focus dot

draw.ellipse([cx - LENS_OR, lens_cy - LENS_OR,
              cx + LENS_OR, lens_cy + LENS_OR], fill="#383838")
draw.ellipse([cx - LENS_IR, lens_cy - LENS_IR,
              cx + LENS_IR, lens_cy + LENS_IR], fill="#FFFFFF")
draw.ellipse([cx - LENS_CR, lens_cy - LENS_CR,
              cx + LENS_CR, lens_cy + LENS_CR], fill="#383838")

# Viewfinder (small rect top-left of camera body)
VF_W, VF_H = 52, 32
draw.rounded_rectangle(
    [cam_x0 + 28, cam_y0 + 24, cam_x0 + 28 + VF_W, cam_y0 + 24 + VF_H],
    radius=6, fill="#383838"
)

REPO = "/datadisk/loomi-ait/volumes/u-d414d4ccdc9a1daf8d8409bd38243f28/sessions/9eb2c364-50ed-479f-b813-cd392cfe7576/repos/everyday_counts-963b3825"
img.save(f"{REPO}/icon_previews/icon_black_A.png")
print("done")
