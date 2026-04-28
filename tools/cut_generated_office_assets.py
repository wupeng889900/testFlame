from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets" / "atlas"
OFFICE = ROOT / "assets" / "office_game" / "furniture"


def is_checker(px: tuple[int, int, int, int]) -> bool:
    r, g, b, a = px
    if a == 0:
        return True
    if max(r, g, b) - min(r, g, b) > 8:
        return False
    return 232 <= r <= 255 and 232 <= g <= 255 and 232 <= b <= 255


def remove_outer_checker(img: Image.Image) -> Image.Image:
    crop = img.convert("RGBA")
    width, height = crop.size
    pixels = crop.load()
    visited = [[False] * height for _ in range(width)]
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= width or y >= height or visited[x][y]:
            return
        visited[x][y] = True
        if is_checker(pixels[x, y]):
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            enqueue(nx, ny)

    for x in range(width):
        for y in range(height):
            if is_checker(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)

    bbox = crop.getbbox()
    if not bbox:
        return crop
    return crop.crop(bbox)


def crop_clean(src: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return remove_outer_checker(src.crop(box))


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def cut_lounge() -> None:
    src = Image.open(ATLAS / "3.png").convert("RGBA")
    assets = {
        "sofa_3seat.png": (640, 158, 1115, 390),
        "sofa_chair_left.png": (548, 420, 718, 768),
        "sofa_chair_right.png": (1005, 420, 1186, 768),
        "sofa_bottom.png": (690, 790, 1045, 980),
        "coffee_table.png": (780, 450, 972, 735),
    }
    for name, box in assets.items():
        save(crop_clean(src, box), OFFICE / "lounge" / name)


def cut_workstations() -> None:
    src = Image.open(ATLAS / "4.png").convert("RGBA")
    desk_boxes = [
        (520, 70, 810, 260),
        (865, 70, 1155, 260),
        (520, 325, 810, 515),
        (865, 325, 1155, 515),
        (520, 580, 810, 770),
        (865, 580, 1155, 770),
    ]
    chair_boxes = [
        (76, 860, 190, 1055),
        (278, 860, 392, 1055),
        (480, 860, 594, 1055),
        (680, 860, 795, 1055),
        (880, 860, 996, 1055),
        (1080, 860, 1198, 1055),
    ]

    for index, (desk_box, chair_box) in enumerate(
        zip(desk_boxes, chair_boxes), start=1
    ):
        desk = crop_clean(src, desk_box)
        chair = crop_clean(src, chair_box)
        canvas = Image.new("RGBA", (320, 360), (0, 0, 0, 0))
        canvas.alpha_composite(desk, ((canvas.width - desk.width) // 2, 0))
        canvas.alpha_composite(
            chair, ((canvas.width - chair.width) // 2, 148)
        )
        bbox = canvas.getbbox()
        out = canvas.crop(bbox) if bbox else canvas
        save(out, OFFICE / "desks" / f"desk_chair_row2_{index:02d}.png")


def cut_meeting() -> None:
    src = Image.open(
        ATLAS / "ChatGPT Image 2026年4月25日 21_56_22 (2).png"
    ).convert("RGBA")
    assets = {
        "meeting_table_top.png": (86, 66, 367, 660),
        "meeting_chair_top.png": (78, 690, 225, 880),
        "meeting_chair_upper_left.png": (525, 698, 665, 878),
        "meeting_chair_mid_left.png": (525, 698, 665, 878),
        "meeting_chair_lower_left.png": (525, 698, 665, 878),
        "meeting_chair_upper_right.png": (690, 950, 815, 1178),
        "meeting_chair_mid_right.png": (690, 950, 815, 1178),
        "meeting_chair_lower_right.png": (690, 950, 815, 1178),
        "meeting_chair_front_left.png": (70, 925, 230, 1188),
        "meeting_chair_front_right.png": (300, 925, 458, 1188),
        "meeting_chair_bottom_left.png": (535, 950, 665, 1178),
        "meeting_chair_bottom_right.png": (690, 950, 815, 1178),
    }
    for name, box in assets.items():
        save(crop_clean(src, box), OFFICE / "meeting" / name)


def main() -> None:
    cut_workstations()
    cut_lounge()
    cut_meeting()
    print("Generated office game furniture assets.")


if __name__ == "__main__":
    main()
