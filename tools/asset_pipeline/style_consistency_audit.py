from __future__ import annotations

import colorsys
import json
from pathlib import Path

from PIL import Image, ImageStat


PROJECT_ROOT = Path(r"e:\testFlame")
REFERENCE = PROJECT_ROOT / r"assets\d35cc568-a05a-4e53-a760-38b3c9b176e1_optimized.png"
CATALOG = PROJECT_ROOT / r"assets\AssetCatalog.json"
REPORT = PROJECT_ROOT / r"deliverables\风格一致性检查报告.md"


def mean_rgb(path: Path) -> tuple[float, float, float]:
    img = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(img)
    return tuple(channel / 255.0 for channel in stat.mean)


def rgb_to_hsv_triplet(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    return colorsys.rgb_to_hsv(*rgb)


def hsv_distance(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    dh = min(abs(a[0] - b[0]), 1 - abs(a[0] - b[0])) * 360
    ds = abs(a[1] - b[1]) * 100
    dv = abs(a[2] - b[2]) * 100
    return round((dh + ds + dv) / 3, 2)


def main() -> None:
    reference_hsv = rgb_to_hsv_triplet(mean_rgb(REFERENCE))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    rows: list[str] = []

    def evaluate(items: list[dict], title: str) -> None:
        rows.append(f"## {title}")
        rows.append("")
        rows.append("| 资源 | 当前路径 | 平均 HSV 距离 | 说明 |")
        rows.append("|---|---|---:|---|")
        for item in items:
          asset_path = PROJECT_ROOT / item["currentPath"]
          hsv = rgb_to_hsv_triplet(mean_rgb(asset_path))
          distance = hsv_distance(reference_hsv, hsv)
          note = "接近参考风格" if distance <= 25 else "建议继续重绘或离线调色"
          rows.append(
              f"| {item['guid']} | `{item['currentPath']}` | {distance} | {note} |"
          )
        rows.append("")

    evaluate(catalog.get("characters", []), "角色资源")
    evaluate(catalog.get("props", []), "道具资源")

    REPORT.write_text(
        "\n".join(
            [
                "# 风格一致性检查报告",
                "",
                f"- 参考图: `{REFERENCE}`",
                "- 说明: 当前使用平均 HSV 距离做工程内快速风格接近度检查。",
                "- 注意: 这不是严格的专业 DeltaE 色差流程，不能替代 Adobe / ICC 色彩工作流。",
                "",
                *rows,
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
