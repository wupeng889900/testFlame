from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image
from PIL.Image import Image as PillowImage


ROOT = Path(__file__).resolve().parents[1]
ATLAS_ROOT = ROOT / "assets" / "atlas"
OUTPUT_ROOT = ROOT / "assets" / "office_game"


ROLE_ROWS = {
    "programmer": {
        "label": "程序员",
        "idle_down": (45, 58, 144, 226),
        "idle_up": (184, 61, 275, 226),
        "walk_up": (307, 60, 379, 202),
        "walk_down": (403, 60, 482, 218),
        "walk_left": [(507, 60, 589, 218), (626, 61, 706, 220)],
        "walk_right": [(758, 63, 841, 222)],
        "work": (903, 60, 1061, 226),
        "meeting": (1081, 54, 1262, 231),
        "rest": (1282, 65, 1440, 214),
    },
    "designer": {
        "label": "设计师",
        "idle_down": (44, 269, 141, 437),
        "idle_up": (182, 269, 266, 430),
        "walk_up": (302, 270, 369, 426),
        "walk_down": (405, 272, 480, 437),
        "walk_left": [(507, 275, 584, 431), (623, 275, 700, 432)],
        "walk_right": [(762, 276, 850, 432)],
        "work": (895, 263, 1055, 445),
        "meeting": (1057, 264, 1275, 445),
        "rest": (1274, 276, 1436, 433),
    },
    "pm": {
        "label": "项目经理",
        "idle_down": (48, 467, 132, 629),
        "idle_up": (186, 460, 267, 622),
        "walk_up": (305, 474, 369, 614),
        "walk_down": (401, 468, 481, 625),
        "walk_left": [(514, 466, 592, 624), (630, 466, 708, 623)],
        "walk_right": [(764, 463, 841, 624)],
        "work": (884, 464, 1053, 634),
        "meeting": (1059, 474, 1278, 638),
        "rest": (1293, 472, 1420, 623),
    },
    "tester": {
        "label": "测试",
        "idle_down": (46, 658, 139, 805),
        "idle_up": (192, 653, 271, 798),
        "walk_up": (302, 658, 372, 790),
        "walk_down": (409, 653, 476, 800),
        "walk_left": [(520, 655, 598, 797), (623, 656, 704, 798)],
        "walk_right": [(758, 654, 844, 799)],
        "work": (896, 654, 1058, 813),
        "meeting": (1066, 648, 1268, 813),
        "rest": (1273, 656, 1431, 796),
    },
    "ops": {
        "label": "运营",
        "idle_down": (50, 836, 137, 996),
        "idle_up": (186, 840, 270, 998),
        "walk_up": (307, 849, 381, 986),
        "walk_down": (408, 848, 482, 999),
        "walk_left": [(521, 847, 594, 997), (631, 848, 707, 997)],
        "walk_right": [(762, 846, 843, 999)],
        "work": (885, 847, 1037, 1006),
        "meeting": (1066, 845, 1237, 998),
        "rest": (1270, 846, 1429, 992),
    },
}


FURNITURE = {
    "furniture/desks/desk_laptop": (44, 75, 273, 220),
    "furniture/desks/desk_monitor_drawer": (320, 58, 564, 221),
    "furniture/desks/desk_laptop_books": (608, 80, 834, 221),
    "furniture/desks/desk_monitor_notes": (877, 59, 1103, 220),
    "furniture/desks/desk_bookshelf": (1155, 82, 1393, 223),
    "furniture/chairs/chair_mesh_front": (68, 262, 180, 433),
    "furniture/chairs/chair_mesh_alt": (238, 262, 342, 433),
    "furniture/chairs/chair_front": (394, 264, 508, 433),
    "furniture/chairs/chair_alt": (554, 272, 665, 434),
    "furniture/meeting/meeting_table_7seat": (819, 238, 1344, 464),
    "furniture/lounge/sofa_3seat": (48, 478, 337, 623),
    "furniture/lounge/sofa_1seat": (364, 494, 482, 625),
    "furniture/lounge/coffee_table": (510, 513, 690, 624),
    "furniture/decor/whiteboard": (743, 453, 925, 639),
    "furniture/decor/water_dispenser": (970, 466, 1051, 641),
    "furniture/decor/plant_large": (1096, 473, 1187, 629),
    "furniture/decor/plant_round": (1213, 519, 1297, 629),
    "furniture/decor/plant_spiky": (1316, 507, 1407, 630),
    "ui/selected_ring": (497, 807, 607, 913),
    "ui/location_pin": (654, 815, 722, 906),
    "ui/bubble_chat": (908, 820, 1009, 909),
    "ui/bubble_active": (1041, 826, 1149, 910),
    "ui/bubble_thought": (1180, 815, 1270, 904),
    "ui/bubble_sleep": (1304, 820, 1394, 907),
    "ui/state_work": (58, 799, 171, 911),
    "ui/state_meeting": (202, 801, 311, 913),
    "ui/state_rest": (342, 800, 452, 914),
    "ui/nameplate_blue": (548, 956, 689, 1045),
    "ui/nameplate_green": (754, 957, 895, 1045),
    "ui/nameplate_orange": (949, 957, 1085, 1045),
    "ui/nameplate_pink": (1125, 957, 1261, 1045),
    "ui/nameplate_purple": (1288, 957, 1417, 1045),
}


def is_checker_background(px: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = px
    return min(r, g, b) >= 218 and max(r, g, b) - min(r, g, b) <= 18


def remove_edge_background(img: PillowImage) -> PillowImage:
    crop = img.convert("RGBA")
    width, height = crop.size
    pixels = crop.load()
    visited = [[False] * height for _ in range(width)]
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= width or y >= height or visited[x][y]:
            return
        visited[x][y] = True
        if is_checker_background(pixels[x, y]):
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
                if is_checker_background(pixels[nx, ny]):
                    queue.append((nx, ny))

    _clean_checker_alias_pixels(crop)
    bbox = crop.getbbox()
    return crop.crop(bbox) if bbox else crop


def _clean_checker_alias_pixels(img: PillowImage) -> None:
    width, height = img.size
    pixels = img.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if min(r, g, b) >= 232 and max(r, g, b) - min(r, g, b) <= 12:
                pixels[x, y] = (r, g, b, 0)


def pad_to_canvas(
    img: PillowImage,
    size: tuple[int, int],
    *,
    bottom_padding: int = 8,
) -> PillowImage:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (size[0] - img.width) // 2
    y = size[1] - img.height - bottom_padding
    canvas.alpha_composite(img, (x, max(0, y)))
    return canvas


def save_crop(
    source: PillowImage,
    key: str,
    box: tuple[int, int, int, int],
    *,
    canvas_size: tuple[int, int] | None = None,
) -> dict[str, object]:
    target = OUTPUT_ROOT / f"{key}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    cut = remove_edge_background(source.crop(box))
    if canvas_size is not None:
        cut = pad_to_canvas(cut, canvas_size)
    cut.save(target)
    return {
        "asset": str(target.relative_to(ROOT)).replace("\\", "/"),
        "box": list(box),
        "size": [cut.width, cut.height],
    }


def mirror_asset(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(path)


def export_role_assets(source: PillowImage, manifest: dict[str, object]) -> None:
    for role, spec in ROLE_ROWS.items():
        base = f"characters/{role}"
        role_manifest: dict[str, object] = {"label": spec["label"], "assets": {}}

        def export(
            name: str,
            box: tuple[int, int, int, int],
            *,
            normalized: bool = False,
        ) -> None:
            role_manifest["assets"][name] = save_crop(
                source,
                f"{base}/{name}",
                box,
                canvas_size=(128, 184) if normalized else None,
            )

        export("idle/idle_down", spec["idle_down"], normalized=True)
        export("idle/idle_up", spec["idle_up"], normalized=True)
        export("idle/idle_left", spec["walk_left"][0], normalized=True)
        export("idle/idle_right", spec["walk_right"][0], normalized=True)

        walk_down_boxes = [spec["idle_down"], spec["walk_down"], spec["walk_right"][0], spec["walk_left"][0]]
        walk_up_boxes = [spec["idle_up"], spec["walk_up"], spec["walk_left"][1], spec["walk_right"][0]]
        for index, box in enumerate(walk_down_boxes):
            export(f"walk/walk_down_{index}", box, normalized=True)
        for index, box in enumerate(walk_up_boxes):
            export(f"walk/walk_up_{index}", box, normalized=True)
        for index, box in enumerate([*spec["walk_left"], spec["walk_down"], spec["idle_down"]]):
            export(f"walk/walk_left_{index}", box, normalized=True)
        for index, box in enumerate([spec["walk_right"][0], spec["walk_down"], spec["idle_down"], spec["walk_left"][0]]):
            export(f"walk/walk_right_{index}", box, normalized=True)
            if index == 3:
                mirror_asset(OUTPUT_ROOT / f"{base}/walk/walk_right_{index}.png")

        export("sit_desk/sit_desk_front", spec["work"])
        export("sit_desk/sit_desk_left", spec["work"])
        export("sit_desk/sit_desk_right", spec["work"])
        export("meeting_states/talk_up", spec["meeting"])
        export("meeting_states/talk_left", spec["meeting"])
        export("meeting_states/talk_right", spec["meeting"])
        manifest[f"characters/{role}"] = role_manifest


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    character_source = Image.open(ATLAS_ROOT / "人物切图.png").convert("RGBA")
    furniture_source = Image.open(ATLAS_ROOT / "家具切图.png").convert("RGBA")

    manifest: dict[str, object] = {"source": {}, "assets": {}}
    manifest["source"] = {
        "characters": "assets/atlas/人物切图.png",
        "furniture": "assets/atlas/家具切图.png",
    }

    export_role_assets(character_source, manifest["assets"])
    for key, box in FURNITURE.items():
        manifest["assets"][key] = save_crop(furniture_source, key, box)

    (OUTPUT_ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported office game assets to {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
