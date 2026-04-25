from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image


SOURCE = Path(r"E:\testFlame\assets\atlas\48b0b118-b27e-41e7-9435-05589a37cf16 (1).png")
OUTPUT_ROOT = Path(r"E:\testFlame\assets\extracted_preview_clean")


def is_background(px: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = px
    return min(r, g, b) >= 236 and max(r, g, b) - min(r, g, b) <= 8


def remove_outer_background(img: Image.Image) -> Image.Image:
    crop = img.convert("RGBA")
    width, height = crop.size
    pixels = crop.load()
    visited = [[False] * height for _ in range(width)]
    queue = deque()

    def enqueue(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= width or y >= height:
            return
        if visited[x][y]:
            return
        visited[x][y] = True
        if is_background(pixels[x, y]):
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
            if 0 <= nx < width and 0 <= ny < height and not visited[nx][ny]:
                visited[nx][ny] = True
                if is_background(pixels[nx, ny]):
                    queue.append((nx, ny))

    bbox = crop.getbbox()
    return crop.crop(bbox) if bbox else crop


def save_crop(img: Image.Image, out_path: Path, box: tuple[int, int, int, int]) -> list[int]:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cleaned = remove_outer_background(img.crop(box))
    cleaned.save(out_path)
    return [cleaned.width, cleaned.height]


ASSETS: dict[str, tuple[int, int, int, int]] = {
    "walk/walk_down_0": (160, 70, 236, 192),
    "walk/walk_down_1": (268, 70, 344, 192),
    "walk/walk_down_2": (375, 70, 450, 192),
    "walk/walk_down_3": (482, 70, 556, 192),
    "walk/walk_up_0": (166, 208, 238, 324),
    "walk/walk_up_1": (271, 208, 342, 324),
    "walk/walk_up_2": (378, 208, 450, 324),
    "walk/walk_up_3": (484, 208, 556, 325),
    "walk/walk_left_0": (164, 341, 240, 460),
    "walk/walk_left_1": (269, 341, 344, 460),
    "walk/walk_left_2": (375, 341, 450, 460),
    "walk/walk_left_3": (478, 341, 554, 460),
    "walk/walk_right_0": (160, 473, 236, 592),
    "walk/walk_right_1": (265, 473, 342, 592),
    "walk/walk_right_2": (371, 478, 449, 596),
    "walk/walk_right_3": (475, 478, 553, 596),
    "idle/idle_down": (653, 111, 730, 239),
    "idle/idle_up": (775, 111, 853, 239),
    "idle/idle_left": (895, 112, 974, 239),
    "idle/idle_right": (1012, 111, 1090, 239),
    "sit_desk/sit_desk_left": (650, 383, 848, 543),
    "sit_desk/sit_desk_right": (898, 383, 1088, 543),
    "sofa_states/sit_sofa_left": (36, 701, 194, 850),
    "sofa_states/sit_sofa_right": (224, 701, 382, 849),
    "sofa_states/sleep_sofa_left": (486, 696, 730, 850),
    "sofa_states/sleep_sofa_right": (790, 694, 1030, 850),
    "meeting_states/talk_left": (22, 955, 233, 1078),
    "meeting_states/talk_right": (252, 955, 475, 1078),
    "meeting_states/talk_up": (553, 955, 762, 1078),
    "meeting_states/talk_down": (813, 955, 1018, 1078),
    "office_props/desk_empty": (1140, 78, 1316, 206),
    "office_props/chair_empty": (1332, 78, 1433, 208),
    "office_props/computer_on": (1454, 78, 1583, 208),
    "office_props/computer_off": (1584, 77, 1716, 210),
    "office_props/cabinet": (1723, 73, 1840, 208),
    "office_props/bookshelf": (1856, 74, 2004, 215),
    "lounge_props/sofa_empty": (1140, 360, 1338, 482),
    "lounge_props/coffee_table": (1358, 382, 1524, 482),
    "lounge_props/plant_large": (1546, 340, 1640, 483),
    "lounge_props/vending_machine": (1694, 340, 1832, 484),
    "lounge_props/water_dispenser": (1858, 340, 1944, 482),
    "meeting_props/meeting_table_empty": (1140, 632, 1326, 731),
    "meeting_props/meeting_chair_empty": (1328, 632, 1523, 731),
    "meeting_props/whiteboard": (1533, 632, 1682, 735),
    "meeting_props/projector_screen": (1690, 632, 1823, 733),
    "meeting_props/notice_board": (1848, 632, 2006, 731),
    "misc_props/clock": (1140, 915, 1240, 966),
    "misc_props/printer": (1260, 915, 1372, 1010),
    "misc_props/trash_can": (1392, 915, 1470, 1008),
    "misc_props/picture": (1496, 915, 1622, 966),
    "misc_props/coat_rack": (1638, 915, 1707, 978),
    "misc_props/fire_extinguisher": (1744, 915, 1820, 969),
    "misc_props/window": (1848, 915, 1988, 976),
    "bubbles/bubble_chat": (18, 1140, 123, 1226),
    "bubbles/bubble_work": (155, 1140, 262, 1226),
    "bubbles/bubble_zzz": (292, 1140, 400, 1226),
    "bubbles/bubble_idea": (431, 1140, 532, 1226),
    "bubbles/sparkle": (20, 1248, 125, 1320),
    "bubbles/exclamation": (156, 1248, 262, 1320),
    "bubbles/sweat": (292, 1248, 400, 1320),
    "bubbles/angry": (431, 1248, 532, 1320),
    "alt_chars/worker_male_02": (654, 1155, 742, 1302),
    "alt_chars/worker_male_03": (779, 1155, 869, 1302),
    "alt_chars/worker_female_01": (898, 1155, 1004, 1302),
    "alt_chars/worker_female_02": (1028, 1155, 1126, 1302),
    "alt_chars/worker_male_04": (1164, 1155, 1252, 1302),
    "alt_chars/worker_male_05": (1284, 1155, 1376, 1302),
}


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SOURCE).convert("RGBA")
    manifest = {}
    for key, box in ASSETS.items():
        out_path = OUTPUT_ROOT / f"{key}.png"
        size = save_crop(src, out_path, box)
        manifest[key] = {"path": str(out_path), "box": list(box), "size": size}

    (OUTPUT_ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(manifest)} clean assets to {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
