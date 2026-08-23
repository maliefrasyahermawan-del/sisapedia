from PIL import Image, ImageDraw

GREEN = (14, 159, 110, 255)   # AppColors.primary
BLUE = (37, 99, 235, 255)     # AppColors.anorganik

SIZE = 1024
CX, CY = SIZE // 2, SIZE // 2


def draw_bowtie(draw, half_width, half_height):
    green = [
        (CX - half_width, CY - half_height),
        (CX - half_width, CY + half_height),
        (CX, CY),
    ]
    blue = [
        (CX + half_width, CY - half_height),
        (CX + half_width, CY + half_height),
        (CX, CY),
    ]
    draw.polygon(green, fill=GREEN)
    draw.polygon(blue, fill=BLUE)


# Main icon: white square background (iOS + legacy Android + web).
main_img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
draw_bowtie(ImageDraw.Draw(main_img), half_width=300, half_height=185)
main_img.save("assets/icon/app_icon.png")

# Adaptive icon foreground: transparent background, shrunk to fit Android's
# adaptive-icon safe zone (~66% of canvas) so it isn't clipped by the mask.
fg_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_bowtie(ImageDraw.Draw(fg_img), half_width=200, half_height=123)
fg_img.save("assets/icon/app_icon_foreground.png")

print("done")
