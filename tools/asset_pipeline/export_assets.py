import argparse
import json
import math
from pathlib import Path

from PIL import Image


MASTER_TARGETS = {
    "1K": 1024,
    "2K": 2048,
    "4K": 4096,
}

SLICE_TARGETS = {
    "1x": 1,
    "2x": 2,
    "3x": 3,
}

FORMATS = ("png", "webp", "jpg")


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def load_manifest(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fp:
        return json.load(fp)


def validate_grid(value: int, name: str) -> None:
    if value % 8 != 0:
        raise ValueError(f"{name}={value} 不符合 8px 网格要求")


def validate_slice(item: dict) -> None:
    for key in ("x", "y", "width", "height"):
        validate_grid(int(item[key]), f"{item['name']}.{key}")


def resize_keep_ratio(image: Image.Image, target_width: int) -> Image.Image:
    ratio = target_width / image.width
    target_height = int(round(image.height * ratio))
    return image.resize((target_width, target_height), Image.Resampling.LANCZOS)


def save_image(image: Image.Image, file_path: Path, fmt: str) -> None:
    if fmt == "png":
        image.save(file_path, format="PNG", optimize=False, compress_level=0)
    elif fmt == "webp":
        image.save(file_path, format="WEBP", quality=95, method=6, lossless=False)
    elif fmt == "jpg":
        rgb = image.convert("RGB")
        image2 = rgb.copy()
        image2.save(
            file_path,
            format="JPEG",
            quality=92,
            optimize=True,
            progressive=True,
            subsampling=0,
        )
    else:
        raise ValueError(f"不支持格式: {fmt}")


def export_master_visual(source: Image.Image, output_dir: Path, gamut: str, base_name: str) -> list:
    exported = []
    for label, width in MASTER_TARGETS.items():
        resized = resize_keep_ratio(source, width)
        for fmt in FORMATS:
            filename = f"{base_name}_{label}_{gamut}.{fmt}"
            out_path = output_dir / filename
            save_image(resized, out_path, fmt)
            exported.append(
                {
                    "file": filename,
                    "width": resized.width,
                    "height": resized.height,
                    "format": fmt,
                    "gamut": gamut,
                }
            )
    return exported


def export_slices(source: Image.Image, slices: list, output_dir: Path, gamut: str) -> list:
    exported = []
    for item in slices:
        validate_slice(item)
        crop = source.crop(
            (
                int(item["x"]),
                int(item["y"]),
                int(item["x"]) + int(item["width"]),
                int(item["y"]) + int(item["height"]),
            )
        )
        for label, scale in SLICE_TARGETS.items():
            size = (crop.width * scale, crop.height * scale)
            resized = crop.resize(size, Image.Resampling.NEAREST)
            for fmt in FORMATS:
                filename = f"{item['name']}_{label}_{gamut}.{fmt}"
                out_path = output_dir / filename
                save_image(resized, out_path, fmt)
                exported.append(
                    {
                        "name": item["name"],
                        "file": filename,
                        "x": item["x"],
                        "y": item["y"],
                        "width": crop.width,
                        "height": crop.height,
                        "scale": label,
                        "format": fmt,
                        "gamut": gamut,
                    }
                )
    return exported


def export_css_sprite(slices: list, output_dir: Path) -> None:
    lines = [
        ".sprite {",
        "  background-image: url('sprite_sheet.png');",
        "  background-repeat: no-repeat;",
        "  display: inline-block;",
        "}",
        "",
    ]
    for item in slices:
        lines.extend(
            [
                f".sprite-{item['name']} {{",
                f"  width: {item['width']}px;",
                f"  height: {item['height']}px;",
                f"  background-position: -{item['x']}px -{item['y']}px;",
                "}",
                "",
            ]
        )
    (output_dir / "sprite_sheet.css").write_text("\n".join(lines), encoding="utf-8")


def write_report(output_dir: Path, master_files: list, slice_files: list, manifest: dict) -> None:
    report = {
        "source_image": manifest["source_image"],
        "grid": manifest.get("grid", 8),
        "master_visual_exports": master_files,
        "slice_exports": slice_files,
        "slice_count": len(manifest.get("slices", [])),
    }
    (output_dir / "切图坐标与尺寸说明.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="8px 网格切图与多格式导出工具")
    parser.add_argument("--manifest", required=True, help="切图清单 JSON 路径")
    parser.add_argument("--output", required=True, help="输出目录")
    parser.add_argument("--gamut", default="sRGB", help="色域标签，如 sRGB / AdobeRGB / Rec709")
    parser.add_argument("--export-css-sprite", action="store_true", help="生成 CSS sprite 清单")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    output_dir = Path(args.output)
    ensure_dir(output_dir)

    manifest = load_manifest(manifest_path)
    source_path = manifest_path.parent / manifest["source_image"]
    source = Image.open(source_path).convert("RGBA")

    master_name = manifest.get("master_name", "主视觉")
    master_files = export_master_visual(source, output_dir, args.gamut, master_name)
    slice_files = export_slices(source, manifest.get("slices", []), output_dir, args.gamut)

    if args.export_css_sprite:
      export_css_sprite(manifest.get("slices", []), output_dir)

    write_report(output_dir, master_files, slice_files, manifest)


if __name__ == "__main__":
    main()
