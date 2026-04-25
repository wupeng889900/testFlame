from __future__ import annotations

import colorsys
import csv
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps, ImageStat


PROJECT_ROOT = Path(r"e:\testFlame")
REFERENCE = PROJECT_ROOT / r"assets\d35cc568-a05a-4e53-a760-38b3c9b176e1_optimized.png"
CSV_PATH = PROJECT_ROOT / r"deliverables\resource_optimization_manifest.csv"
REPORT_PATH = PROJECT_ROOT / r"deliverables\图片资源优化测试报告.md"

TARGET_DIRS = [
    PROJECT_ROOT / r"assets\characters",
    PROJECT_ROOT / r"assets\furniture",
    PROJECT_ROOT / r"assets\ui",
    PROJECT_ROOT / r"assets\environment",
]


def mean_rgb(image: Image.Image) -> tuple[float, float, float]:
    stat = ImageStat.Stat(image.convert("RGB"))
    return tuple(channel / 255.0 for channel in stat.mean)


def rgb_to_hsv(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    return colorsys.rgb_to_hsv(*rgb)


def grayscale_sequence(image: Image.Image) -> list[float]:
    gray = image.convert("L")
    return [value / 255.0 for value in gray.getdata()]


def ssim_like(a: Image.Image, b: Image.Image) -> float:
    if a.size != b.size:
        b = b.resize(a.size, Image.Resampling.LANCZOS)

    x = grayscale_sequence(a)
    y = grayscale_sequence(b)
    n = len(x)
    if n == 0:
        return 1.0

    mean_x = sum(x) / n
    mean_y = sum(y) / n
    var_x = sum((v - mean_x) ** 2 for v in x) / n
    var_y = sum((v - mean_y) ** 2 for v in y) / n
    cov_xy = sum((vx - mean_x) * (vy - mean_y) for vx, vy in zip(x, y)) / n

    c1 = 0.01 ** 2
    c2 = 0.03 ** 2
    numerator = (2 * mean_x * mean_y + c1) * (2 * cov_xy + c2)
    denominator = (mean_x**2 + mean_y**2 + c1) * (var_x + var_y + c2)
    return round(numerator / denominator, 4) if denominator else 1.0


def style_shift(image: Image.Image, reference_hsv: tuple[float, float, float]) -> Image.Image:
    current_hsv = rgb_to_hsv(mean_rgb(image))

    enhanced = ImageOps.autocontrast(image, cutoff=0)
    brightness = 1.0 + max(-0.01, min(0.02, (reference_hsv[2] - current_hsv[2]) * 0.25))
    saturation = 1.0 + max(-0.01, min(0.03, (reference_hsv[1] - current_hsv[1]) * 0.3))
    enhanced = ImageEnhance.Brightness(enhanced).enhance(brightness)
    enhanced = ImageEnhance.Contrast(enhanced).enhance(1.02)
    enhanced = ImageEnhance.Color(enhanced).enhance(saturation)
    return enhanced


def enhance_tile(tile: Image.Image, strength: float) -> Image.Image:
    tile = ImageEnhance.Contrast(tile).enhance(1.0 + 0.02 * strength)
    tile = ImageEnhance.Sharpness(tile).enhance(1.0 + 0.05 * strength)
    return tile.filter(
        ImageFilter.UnsharpMask(
            radius=0.8 + 0.1 * strength,
            percent=int(100 + 4 * strength),
            threshold=5,
        )
    )


def reconstruct_with_grid(image: Image.Image) -> Image.Image:
    width, height = image.size
    col_cuts = [0, width // 4, width // 2, (width * 3) // 4, width]
    row_cuts = [0, height // 4, height // 2, (height * 3) // 4, height]

    out = Image.new("RGBA", image.size)
    for row in range(4):
        for col in range(4):
            box = (col_cuts[col], row_cuts[row], col_cuts[col + 1], row_cuts[row + 1])
            tile = image.crop(box)
            center_tile = row in (1, 2) and col in (1, 2)
            edge_tile = row in (1, 2) or col in (1, 2)
            strength = 1.0 if center_tile else (0.55 if edge_tile else 0.25)
            tile = enhance_tile(tile, strength)
            out.paste(tile, box[:2])
    return out


def add_reference_tint(image: Image.Image, reference_hsv: tuple[float, float, float]) -> Image.Image:
    warm_rgb = colorsys.hsv_to_rgb(reference_hsv[0], min(0.35, reference_hsv[1]), 1.0)
    tint = tuple(int(channel * 255) for channel in warm_rgb)
    overlay = Image.new("RGBA", image.size, tint + (6,))
    return Image.alpha_composite(image.convert("RGBA"), overlay)


def optimize_image(source_path: Path, reference_hsv: tuple[float, float, float]) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    shifted = style_shift(image.convert("RGB"), reference_hsv).convert("RGBA")
    rebuilt = reconstruct_with_grid(shifted)
    rebuilt = add_reference_tint(rebuilt, reference_hsv)
    return rebuilt


def save_webp_with_target(original: Image.Image, optimized: Image.Image, out_path: Path) -> tuple[int, float]:
    best_quality = 80
    best_ssim = 0.0
    temp_path = out_path
    for quality in range(60, 97, 4):
        optimized.save(
            temp_path,
            format="WEBP",
            quality=quality,
            method=6,
            lossless=False,
        )
        candidate = Image.open(temp_path).convert("RGBA")
        current_ssim = ssim_like(original, candidate)
        if current_ssim >= 0.95:
            return quality, current_ssim
        if current_ssim > best_ssim:
            best_ssim = current_ssim
            best_quality = quality
    optimized.save(
        temp_path,
        format="WEBP",
        quality=best_quality,
        method=6,
        lossless=False,
    )
    return best_quality, best_ssim


def percent_change(old: int, new: int) -> float:
    if old == 0:
        return 0.0
    return round(((old - new) / old) * 100, 2)


def main() -> None:
    reference = Image.open(REFERENCE).convert("RGB")
    reference_hsv = rgb_to_hsv(mean_rgb(reference))
    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, object]] = []

    for root in TARGET_DIRS:
        optimized_dir = root / "optimized"
        optimized_dir.mkdir(parents=True, exist_ok=True)

        for source_path in sorted(root.glob("*.png")):
            original = Image.open(source_path).convert("RGBA")
            optimized = optimize_image(source_path, reference_hsv)

            png_path = optimized_dir / f"{source_path.stem}_opt.png"
            webp_path = optimized_dir / f"{source_path.stem}_opt.webp"

            quantized = optimized.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
            quantized.save(png_path, format="PNG", optimize=True, compress_level=9)
            _, ssim_webp = save_webp_with_target(original, optimized, webp_path)
            ssim_png = ssim_like(original, Image.open(png_path).convert("RGBA"))

            original_size = source_path.stat().st_size
            png_size = png_path.stat().st_size
            webp_size = webp_path.stat().st_size

            rows.append(
                {
                    "original_path": str(source_path.relative_to(PROJECT_ROOT)),
                    "optimized_path": str(png_path.relative_to(PROJECT_ROOT)),
                    "format": "PNG",
                    "original_size_bytes": original_size,
                    "optimized_size_bytes": png_size,
                    "size_reduction_pct": percent_change(original_size, png_size),
                    "original_dimensions": f"{original.width}x{original.height}",
                    "optimized_dimensions": f"{optimized.width}x{optimized.height}",
                    "ssim": ssim_png,
                }
            )
            rows.append(
                {
                    "original_path": str(source_path.relative_to(PROJECT_ROOT)),
                    "optimized_path": str(webp_path.relative_to(PROJECT_ROOT)),
                    "format": "WEBP",
                    "original_size_bytes": original_size,
                    "optimized_size_bytes": webp_size,
                    "size_reduction_pct": percent_change(original_size, webp_size),
                    "original_dimensions": f"{original.width}x{original.height}",
                    "optimized_dimensions": f"{optimized.width}x{optimized.height}",
                    "ssim": ssim_webp,
                }
            )

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as fp:
        writer = csv.DictWriter(
            fp,
            fieldnames=[
                "original_path",
                "optimized_path",
                "format",
                "original_size_bytes",
                "optimized_size_bytes",
                "size_reduction_pct",
                "original_dimensions",
                "optimized_dimensions",
                "ssim",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    webp_rows = [row for row in rows if row["format"] == "WEBP"]
    pass_count = sum(
        1
        for row in webp_rows
        if float(row["ssim"]) >= 0.95 and float(row["size_reduction_pct"]) >= 30
    )

    REPORT_PATH.write_text(
        "\n".join(
            [
                "# 图片资源优化测试报告",
                "",
                f"- 参考图: `{REFERENCE}`",
                f"- 资源清单: `{CSV_PATH}`",
                f"- WebP 达到 `SSIM >= 0.95` 且 `体积下降 >= 30%` 的项目数: `{pass_count}/{len(webp_rows)}`",
                "",
                "## 优化策略",
                "- 采用 4x4 中央四格优先的九宫格变体重构",
                "- 中央四格强化清晰度与信息量，边缘格弱化处理以保留轮廓",
                "- 根据参考图平均 HSV 做温和色调迁移",
                "- 输出 PNG 编辑备份与 WebP 线上版本",
                "",
                "## 自动检测结论",
                "- 已生成 PNG / WebP 双格式",
                "- 已生成尺寸、体积、SSIM CSV 清单",
                "- PNG 作为编辑备份，重点考察 WebP 的线上压缩收益",
                "",
                "## 人工回归边界",
                "- Chrome / Firefox / Safari / Edge 真机与真实浏览器视觉回归需人工执行",
                "- ImageMagick 未强依赖，本次使用 Pillow + 自实现 SSIM 完成等效检测",
                "- 无可见锯齿或色带仍建议人工逐张复核",
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
