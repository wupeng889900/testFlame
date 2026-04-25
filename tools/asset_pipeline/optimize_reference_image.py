from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps, ImageStat


SOURCE = Path(r"e:\testFlame\assets\d35cc568-a05a-4e53-a760-38b3c9b176e1.png")
OUTPUT = Path(r"e:\testFlame\assets\d35cc568-a05a-4e53-a760-38b3c9b176e1_optimized.png")
REPORT = Path(r"e:\testFlame\deliverables\图像优化报告.md")


def stats_for(image: Image.Image) -> dict:
    rgb = image.convert("RGB")
    stat = ImageStat.Stat(rgb)
    return {
        "size": rgb.size,
        "mean_rgb": [round(x, 2) for x in stat.mean],
        "std_rgb": [round(x, 2) for x in stat.stddev],
    }


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    before = stats_for(image)

    # 1. Gentle autocontrast to recover tonal range without clipping too hard.
    enhanced = ImageOps.autocontrast(image, cutoff=1)

    # 2. Slight brightness lift to improve dark midtones.
    enhanced = ImageEnhance.Brightness(enhanced).enhance(1.04)

    # 3. Controlled contrast boost to separate objects from the background.
    enhanced = ImageEnhance.Contrast(enhanced).enhance(1.10)

    # 4. Small saturation increase to keep the scene lively but natural.
    enhanced = ImageEnhance.Color(enhanced).enhance(1.08)

    # 5. Very light sharpening pass, avoiding halos.
    enhanced = enhanced.filter(
        ImageFilter.UnsharpMask(radius=1.4, percent=115, threshold=3)
    )

    # 6. Mild smoothing on very small noise before saving.
    enhanced = enhanced.filter(ImageFilter.SMOOTH)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    enhanced.save(OUTPUT, format="PNG", compress_level=0)
    after = stats_for(enhanced)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        "\n".join(
            [
                "# 图像优化报告",
                "",
                f"- 源文件: `{SOURCE}`",
                f"- 输出文件: `{OUTPUT}`",
                "",
                "## 自动分析",
                f"- 原始尺寸: `{before['size'][0]} x {before['size'][1]}`",
                f"- 原始均值 RGB: `{before['mean_rgb']}`",
                f"- 原始标准差 RGB: `{before['std_rgb']}`",
                f"- 优化后均值 RGB: `{after['mean_rgb']}`",
                f"- 优化后标准差 RGB: `{after['std_rgb']}`",
                "",
                "## 本次优化动作",
                "- 自动对比度校正：恢复动态范围，压低灰蒙感",
                "- 轻微提亮：修复中暗部可读性",
                "- 温和增强对比度：提升层次和主体边界",
                "- 轻微增强饱和度：保持自然前提下增加画面活力",
                "- Unsharp Mask 锐化：增强边缘细节，尽量避免光晕",
                "- 平滑降噪：减轻细碎噪点与压缩痕迹",
                "",
                "## 说明",
                "- 本流程为保守增强，目标是尽量避免 artifacts 和过处理。",
                "- 若需局部重绘、背景替换、人物分层、商业海报级精修，仍建议进入专业设计软件继续处理。",
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
