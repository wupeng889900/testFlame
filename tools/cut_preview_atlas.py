from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


SOURCE = Path(r"E:\testFlame\assets\atlas\48b0b118-b27e-41e7-9435-05589a37cf16 (1).png")
OUTPUT_ROOT = Path(r"E:\testFlame\assets\extracted_preview")


@dataclass(frozen=True)
class Section:
    key: str
    roi: tuple[int, int, int, int]
    names: list[str]
    crop_size: tuple[int, int]
    y_cluster: int = 60


SECTIONS = [
    Section(
        key="walk",
        roi=(120, 40, 590, 620),
        names=[
            "walk_down_0",
            "walk_down_1",
            "walk_down_2",
            "walk_down_3",
            "walk_up_0",
            "walk_up_1",
            "walk_up_2",
            "walk_up_3",
            "walk_left_0",
            "walk_left_1",
            "walk_left_2",
            "walk_left_3",
            "walk_right_0",
            "walk_right_1",
            "walk_right_2",
            "walk_right_3",
        ],
        crop_size=(138, 138),
        y_cluster=72,
    ),
    Section(
        key="idle",
        roi=(640, 50, 1100, 250),
        names=["idle_down", "idle_up", "idle_left", "idle_right"],
        crop_size=(138, 138),
    ),
    Section(
        key="sit_desk",
        roi=(650, 350, 1090, 560),
        names=["sit_desk_left", "sit_desk_right"],
        crop_size=(248, 176),
    ),
    Section(
        key="sofa_states",
        roi=(20, 700, 1080, 950),
        names=[
            "sit_sofa_left",
            "sit_sofa_right",
            "sleep_sofa_left",
            "sleep_sofa_right",
        ],
        crop_size=(260, 176),
        y_cluster=90,
    ),
    Section(
        key="meeting_states",
        roi=(20, 960, 1090, 1235),
        names=["talk_left", "talk_right", "talk_up", "talk_down"],
        crop_size=(248, 176),
        y_cluster=88,
    ),
    Section(
        key="office_props",
        roi=(1140, 60, 2010, 285),
        names=[
            "desk_empty",
            "chair_empty",
            "computer_on",
            "computer_off",
            "cabinet",
            "bookshelf",
        ],
        crop_size=(150, 150),
    ),
    Section(
        key="lounge_props",
        roi=(1140, 345, 2010, 575),
        names=[
            "sofa_empty",
            "coffee_table",
            "plant_large",
            "vending_machine",
            "water_dispenser",
        ],
        crop_size=(150, 150),
    ),
    Section(
        key="meeting_props",
        roi=(1140, 635, 2010, 840),
        names=[
            "meeting_table_empty",
            "meeting_chair_empty",
            "whiteboard",
            "projector_screen",
            "notice_board",
        ],
        crop_size=(150, 150),
    ),
    Section(
        key="misc_props",
        roi=(1140, 920, 2010, 1128),
        names=[
            "clock",
            "printer",
            "trash_can",
            "picture",
            "coat_rack",
            "fire_extinguisher",
            "window",
        ],
        crop_size=(150, 150),
    ),
    Section(
        key="bubbles",
        roi=(0, 1135, 715, 1365),
        names=[
            "bubble_chat",
            "bubble_work",
            "bubble_zzz",
            "bubble_idea",
            "sparkle",
            "exclamation",
            "sweat",
            "angry",
        ],
        crop_size=(128, 128),
        y_cluster=96,
    ),
    Section(
        key="alt_chars",
        roi=(660, 1160, 1710, 1365),
        names=[
            "worker_male_02",
            "worker_male_03",
            "worker_female_01",
            "worker_female_02",
            "worker_male_04",
            "worker_male_05",
        ],
        crop_size=(138, 138),
    ),
]


def is_background(px: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = px
    return min(r, g, b) >= 236 and max(r, g, b) - min(r, g, b) <= 8


def is_seed(px: tuple[int, int, int, int]) -> bool:
    if is_background(px):
        return False
    r, g, b, _ = px
    return min(r, g, b) <= 225 or max(r, g, b) - min(r, g, b) >= 10


def connected_components(img: Image.Image, roi: tuple[int, int, int, int]) -> list[dict[str, int]]:
    x0, y0, x1, y1 = roi
    width = x1 - x0
    height = y1 - y0
    pixels = img.load()
    visited = bytearray(width * height)
    results: list[dict[str, int]] = []

    def mark(x: int, y: int) -> int:
        return y * width + x

    for ry in range(height):
        for rx in range(width):
            idx = mark(rx, ry)
            if visited[idx]:
                continue
            visited[idx] = 1
            if not is_seed(pixels[x0 + rx, y0 + ry]):
                continue

            queue = deque([(rx, ry)])
            min_x = max_x = rx
            min_y = max_y = ry
            area = 0

            while queue:
                cx, cy = queue.popleft()
                area += 1
                min_x = min(min_x, cx)
                min_y = min(min_y, cy)
                max_x = max(max_x, cx)
                max_y = max(max_y, cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    nidx = mark(nx, ny)
                    if visited[nidx]:
                        continue
                    visited[nidx] = 1
                    if is_seed(pixels[x0 + nx, y0 + ny]):
                        queue.append((nx, ny))

            bbox_w = max_x - min_x + 1
            bbox_h = max_y - min_y + 1
            if area < 90:
                continue
            if bbox_w < 18 or bbox_h < 18:
                continue
            if bbox_w > 420 or bbox_h > 240:
                continue
            results.append(
                {
                    "x0": x0 + min_x,
                    "y0": y0 + min_y,
                    "x1": x0 + max_x + 1,
                    "y1": y0 + max_y + 1,
                    "area": area,
                }
            )
    return results


def sort_components(components: list[dict[str, int]], y_cluster: int) -> list[dict[str, int]]:
    ordered = sorted(components, key=lambda c: ((c["y0"] + c["y1"]) / 2, (c["x0"] + c["x1"]) / 2))
    rows: list[list[dict[str, int]]] = []
    for comp in ordered:
      cy = (comp["y0"] + comp["y1"]) / 2
      if not rows:
          rows.append([comp])
          continue
      last_cy = sum((r["y0"] + r["y1"]) / 2 for r in rows[-1]) / len(rows[-1])
      if abs(cy - last_cy) <= y_cluster:
          rows[-1].append(comp)
      else:
          rows.append([comp])

    flattened: list[dict[str, int]] = []
    for row in rows:
        flattened.extend(sorted(row, key=lambda c: (c["x0"] + c["x1"]) / 2))
    return flattened


def extract_crop(img: Image.Image, center_x: int, center_y: int, size: tuple[int, int], extra_top: int = 0) -> Image.Image:
    width, height = size
    x0 = max(0, int(center_x - width / 2))
    y0 = max(0, int(center_y - height / 2) - extra_top)
    x1 = min(img.width, x0 + width)
    y1 = min(img.height, y0 + height + extra_top)
    crop = img.crop((x0, y0, x1, y1)).convert("RGBA")
    remove_outer_background(crop)
    return trim_transparent(crop)


def remove_outer_background(crop: Image.Image) -> None:
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


def trim_transparent(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def section_output_dir(section: Section) -> Path:
    return OUTPUT_ROOT / section.key


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    manifest: dict[str, dict[str, object]] = {}
    debug: dict[str, object] = {}

    for section in SECTIONS:
        comps = connected_components(source, section.roi)
        ordered = sort_components(comps, section.y_cluster)
        debug[section.key] = {
            "detected": len(ordered),
            "roi": section.roi,
            "boxes": ordered,
        }

        if len(ordered) < len(section.names):
            print(f"[warn] {section.key}: detected {len(ordered)} components, expected {len(section.names)}")
            continue

        section_dir = section_output_dir(section)
        section_dir.mkdir(parents=True, exist_ok=True)

        for name, comp in zip(section.names, ordered):
            cx = int((comp["x0"] + comp["x1"]) / 2)
            cy = int((comp["y0"] + comp["y1"]) / 2)
            extra_top = 28 if name.startswith("sleep_sofa_") else 0
            crop = extract_crop(source, cx, cy, section.crop_size, extra_top=extra_top)
            out_path = section_dir / f"{name}.png"
            crop.save(out_path)
            manifest[name] = {
                "section": section.key,
                "path": str(out_path),
                "sourceCenter": [cx, cy],
                "sourceBounds": [comp["x0"], comp["y0"], comp["x1"], comp["y1"]],
                "size": list(crop.size),
            }

    (OUTPUT_ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (OUTPUT_ROOT / "_debug.json").write_text(
        json.dumps(debug, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(manifest)} assets to {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
