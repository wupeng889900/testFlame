from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image


SOURCE = Path(r"E:\testFlame\assets\atlas\office_formal_generated.png")
OUTPUT_ROOT = Path(r"E:\testFlame\assets\formal_generated")


ASSETS: dict[str, tuple[int, int, int, int]] = {
    "walk/walk_down_0": (46, 28, 120, 148),
    "walk/walk_down_1": (142, 28, 216, 148),
    "walk/walk_down_2": (238, 28, 312, 148),
    "walk/walk_down_3": (334, 28, 408, 148),
    "walk/walk_up_0": (46, 148, 120, 266),
    "walk/walk_up_1": (142, 148, 216, 266),
    "walk/walk_up_2": (238, 148, 312, 266),
    "walk/walk_up_3": (334, 148, 408, 266),
    "walk/walk_left_0": (46, 262, 120, 384),
    "walk/walk_left_1": (142, 262, 216, 384),
    "walk/walk_left_2": (238, 262, 312, 384),
    "walk/walk_left_3": (334, 262, 410, 384),
    "idle/idle_down": (46, 382, 120, 506),
    "idle/idle_up": (142, 382, 216, 506),
    "idle/idle_left": (238, 382, 312, 506),
    "idle/idle_right": (334, 382, 408, 506),
    "sit_desk/sit_desk_front": (500, 72, 670, 250),
    "sit_desk/sit_desk_left": (736, 74, 900, 246),
    "sit_desk/sit_desk_right": (938, 74, 1112, 246),
    "sofa_states/sit_sofa_front": (474, 286, 648, 438),
    "sofa_states/sit_sofa_left": (694, 292, 824, 438),
    "sofa_states/sit_sofa_right": (886, 292, 1010, 438),
    "sofa_states/sleep_sofa_left": (1058, 294, 1274, 438),
    "sofa_states/sleep_sofa_right": (1280, 300, 1520, 438),
    "meeting_states/talk_left": (460, 510, 628, 664),
    "meeting_states/talk_right": (640, 512, 796, 664),
    "meeting_states/talk_up": (862, 512, 1074, 672),
    "office_props/desk_empty_front": (48, 714, 228, 824),
    "office_props/chair_empty_front": (266, 700, 356, 824),
    "office_props/chair_empty_side": (374, 706, 452, 824),
    "office_props/computer_on_desk": (466, 686, 632, 826),
    "office_props/computer_off_desk": (656, 686, 824, 826),
    "lounge_props/sofa_empty_front": (844, 690, 998, 826),
    "lounge_props/coffee_table": (1036, 706, 1192, 822),
    "meeting_props/meeting_table_empty": (1228, 682, 1526, 840),
    "meeting_props/meeting_chair_empty": (1210, 682, 1526, 840),
    "meeting_props/whiteboard": (46, 844, 200, 992),
    "meeting_props/projector_screen": (220, 846, 356, 992),
    "meeting_props/notice_board": (366, 846, 508, 992),
    "misc_props/plant_large": (538, 846, 634, 994),
    "misc_props/water_dispenser": (650, 846, 738, 994),
    "misc_props/printer": (760, 846, 892, 994),
    "misc_props/trash_can": (922, 850, 1020, 994),
    "bubbles/chat": (1058, 856, 1156, 986),
    "bubbles/work": (1168, 856, 1278, 986),
    "bubbles/sleep": (1292, 856, 1418, 986),
    "bubbles/idea": (1428, 856, 1528, 986),
}


def is_bg(px: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = px
    return min(r, g, b) >= 232 and max(r, g, b) - min(r, g, b) <= 8


def remove_edge_background(img: Image.Image) -> Image.Image:
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
        if is_bg(pixels[x, y]):
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
                if is_bg(pixels[nx, ny]):
                    queue.append((nx, ny))

    bbox = crop.getbbox()
    return crop.crop(bbox) if bbox else crop


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SOURCE).convert("RGBA")
    manifest: dict[str, dict[str, object]] = {}

    for key, box in ASSETS.items():
        out_path = OUTPUT_ROOT / f"{key}.png"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        cut = remove_edge_background(src.crop(box))
        cut.save(out_path)
        manifest[key] = {
            "path": str(out_path),
            "box": list(box),
            "size": [cut.width, cut.height],
        }

    (OUTPUT_ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(manifest)} assets to {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
