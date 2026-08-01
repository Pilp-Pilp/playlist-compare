import math

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
img = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255))
draw = ImageDraw.Draw(img)

cx, cy = SIZE / 2 - 10, SIZE / 2 - 10
black = (0, 0, 0, 255)


def thick_arc(bbox, start, end, width):
    draw.arc(bbox, start, end, fill=black, width=width)
    r = width / 2
    for angle in (start, end):
        rad = math.radians(angle)
        x = (bbox[0] + bbox[2]) / 2 + (bbox[2] - bbox[0]) / 2 * math.cos(rad)
        y = (bbox[1] + bbox[3]) / 2 + (bbox[3] - bbox[1]) / 2 * math.sin(rad)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=black)


# outer ring
outer_r = 370
thick_arc([cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], 0, 360, 44)

# inner broken arc, opening toward bottom-right where the note sits
mid_r = 230
thick_arc([cx - mid_r, cy - mid_r, cx + mid_r, cy + mid_r], 150, 430, 44)

# center ring
small_r = 95
thick_arc([cx - small_r, cy - small_r, cx + small_r, cy + small_r], 0, 360, 44)

# center dot
dot_r = 30
draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=black)

# eighth note glyph, bottom-right, straddling the outer ring
font = ImageFont.truetype('/System/Library/Fonts/Apple Symbols.ttf', 520)
note_char = '♪'
bbox = draw.textbbox((0, 0), note_char, font=font)
note_w = bbox[2] - bbox[0]
note_h = bbox[3] - bbox[1]

note_x = cx + outer_r * 0.55 - bbox[0]
note_y = cy + outer_r * 0.45 - bbox[1]
draw.text((note_x, note_y), note_char, font=font, fill=black)

img.save('icon_source.png')
print('saved icon_source.png', note_w, note_h)
