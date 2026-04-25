from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image
from PIL.Image import Image as PillowImage


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "renwu"
OUTPUT_DIR = ROOT / "assets" / "office_game" / "characters"

ROLE_SOURCE_MAP = {
    "programmer": SOURCE_DIR / "程序员.png",
    "designer": SOURCE_DIR / "设计师.png",
    "pm": SOURCE_DIR / "项目经理.png",
    "tester": SOURCE_DIR / "ChatGPT Image 2026年4月25日 07_20_26 (4).png",
    "ops": SOURCE_DIR / "ChatGPT Image 2026年4月25日 07_20_26 (5).png",
}

BACKGROUND_MIN = 222
BACKGROUND_SPREAD = 26
CANVAS_SIZE = (160, 240)
BOTTOM_PADDING = 10
COMPONENT_MIN_AREA = 3500
ROW_GROUP_TOLERANCE = 95
ROW_ORDER = [
    "walk_down",
    "walk_up",
    "walk_left",
    "walk_right",
    "sit_chair",
    "sit_sofa",
]


def is_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a == 0 or (
        min(r, g, b) >= BACKGROUND_MIN
        and max(r, g, b) - min(r, g, b) <= BACKGROUND_SPREAD
    )


def detect_components(image: PillowImage) -> list[tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    foreground = [[False] * height for _ in range(width)]
    for x in range(width):
        for y in range(height):
            foreground[x][y] = not is_background(pixels[x, y])

    seen = [[False] * height for _ in range(width)]
    boxes: list[tuple[int, int, int, int]] = []
    for x in range(width):
        for y in range(height):
            if not foreground[x][y] or seen[x][y]:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[x][y] = True
            min_x = max_x = x
            min_y = max_y = y
            area = 0
            while queue:
                cx, cy = queue.popleft()
                area += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                ):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and foreground[nx][ny]
                        and not seen[nx][ny]
                    ):
                        seen[nx][ny] = True
                        queue.append((nx, ny))

            if area >= COMPONENT_MIN_AREA:
                boxes.append((min_x, min_y, max_x + 1, max_y + 1))

    return sorted(boxes, key=lambda box: ((box[1] + box[3]) / 2, box[0]))


def group_rows(boxes: list[tuple[int, int, int, int]]) -> list[list[tuple[int, int, int, int]]]:
    rows: list[list[tuple[int, int, int, int]]] = []
    for box in boxes:
        center_y = (box[1] + box[3]) / 2
        if not rows:
            rows.append([box])
            continue
        last_row = rows[-1]
        last_center = sum((item[1] + item[3]) / 2 for item in last_row) / len(last_row)
        if center_y - last_center > ROW_GROUP_TOLERANCE:
            rows.append([box])
        else:
            last_row.append(box)

    if len(rows) != len(ROW_ORDER):
        raise RuntimeError(f"Expected {len(ROW_ORDER)} rows, found {len(rows)}.")

    return [sorted(row, key=lambda box: box[0]) for row in rows]


def remove_background_from_edges(image: PillowImage) -> PillowImage:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    visited = [[False] * height for _ in range(width)]
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= width or y >= height or visited[x][y]:
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

    bbox = rgba.getbbox()
    return rgba.crop(bbox) if bbox else rgba


def pad_to_canvas(image: PillowImage) -> PillowImage:
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    scale = min(
        (CANVAS_SIZE[0] - 8) / image.width,
        (CANVAS_SIZE[1] - 8) / image.height,
        1.0,
    )
    target_size = (
        max(1, round(image.width * scale)),
        max(1, round(image.height * scale)),
    )
    resized = image.resize(target_size, Image.Resampling.LANCZOS)
    offset_x = (CANVAS_SIZE[0] - resized.width) // 2
    offset_y = CANVAS_SIZE[1] - resized.height - BOTTOM_PADDING
    canvas.alpha_composite(resized, (offset_x, max(0, offset_y)))
    return canvas


def crop_pose(source: PillowImage, box: tuple[int, int, int, int]) -> PillowImage:
    pose = remove_background_from_edges(source.crop(box))
    return pad_to_canvas(pose)


def save_asset(role: str, name: str, image: PillowImage) -> None:
    target = OUTPUT_DIR / role / f"{name}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)


def export_role(role: str, source_path: Path) -> None:
    if not source_path.exists():
        raise FileNotFoundError(source_path)

    source = Image.open(source_path).convert("RGBA")
    row_map = dict(zip(ROW_ORDER, group_rows(detect_components(source)), strict=True))

    for key, expected in {
        "walk_down": 3,
        "walk_up": 3,
        "walk_left": 3,
        "walk_right": 3,
        "sit_chair": 4,
        "sit_sofa": 4,
    }.items():
        actual = len(row_map[key])
        if actual != expected:
            raise RuntimeError(f"{role} {key} expected {expected} cells, found {actual}.")

    exported: dict[str, PillowImage] = {}

    walk_name_map = {
        "walk_down": "down",
        "walk_up": "up",
        "walk_left": "left",
        "walk_right": "right",
    }
    for row_key, direction in walk_name_map.items():
        frames = [crop_pose(source, box) for box in row_map[row_key]]
        exported[f"idle/idle_{direction}"] = frames[1].copy()
        exported[f"walk/walk_{direction}_0"] = frames[0]
        exported[f"walk/walk_{direction}_1"] = frames[1]
        exported[f"walk/walk_{direction}_2"] = frames[2]
        exported[f"walk/walk_{direction}_3"] = frames[1].copy()

    chair_frames = [crop_pose(source, box) for box in row_map["sit_chair"]]
    sofa_frames = [crop_pose(source, box) for box in row_map["sit_sofa"]]

    exported["sit_desk/sit_desk_front"] = chair_frames[0]
    exported["meeting_states/talk_up"] = chair_frames[1]
    exported["sit_desk/sit_desk_left"] = chair_frames[2]
    exported["sit_desk/sit_desk_right"] = chair_frames[3]
    exported["meeting_states/talk_left"] = chair_frames[2].copy()
    exported["meeting_states/talk_right"] = chair_frames[3].copy()

    exported["sofa_states/sit_sofa_front"] = sofa_frames[0]
    exported["sofa_states/sit_sofa_up"] = sofa_frames[1]
    exported["sofa_states/sit_sofa_left"] = sofa_frames[2]
    exported["sofa_states/sit_sofa_right"] = sofa_frames[3]

    for name, image in exported.items():
        save_asset(role, name, image)


def main() -> None:
    for role, source_path in ROLE_SOURCE_MAP.items():
        export_role(role, source_path)
        print(f"{role}: {source_path.name}")


if __name__ == "__main__":
    main()
