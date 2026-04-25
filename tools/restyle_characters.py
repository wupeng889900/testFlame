from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "characters"


TRANSLUCENT_SHADOW = (56, 46, 40, 60)
COMMON_BASE_MAP = {
    (76, 63, 56, 255): "hair_dark",
    (244, 220, 198, 255): "skin_base",
    (226, 192, 170, 255): "skin_shadow",
    (182, 147, 108, 255): "skin_warm",
    (124, 101, 94, 255): "hair_light",
    (255, 255, 255, 255): "shirt_light",
    (208, 226, 237, 255): "accent_light",
    TRANSLUCENT_SHADOW: "ground_shadow",
}

CHARACTER_MAPS = {
    "rosalind.png": {
        "common": {
            "hair_dark": (88, 54, 46, 255),
            "hair_light": (133, 92, 84, 255),
            "skin_base": (232, 199, 174, 255),
            "skin_shadow": (208, 169, 145, 255),
            "skin_warm": (178, 128, 98, 255),
            "shirt_light": (249, 240, 231, 255),
            "accent_light": (224, 205, 177, 255),
            "ground_shadow": (44, 31, 26, 54),
        },
        "specific": {
            (58, 60, 68, 255): (88, 61, 82, 255),
            (92, 93, 102, 255): (128, 91, 116, 255),
            (120, 124, 138, 255): (170, 132, 152, 255),
            (248, 248, 244, 255): (243, 234, 226, 255),
            (223, 223, 219, 255): (215, 198, 188, 255),
            (84, 85, 93, 255): (104, 78, 96, 255),
        },
    },
    "reviewer.png": {
        "common": {
            "hair_dark": (53, 44, 41, 255),
            "hair_light": (110, 93, 90, 255),
            "skin_base": (222, 188, 161, 255),
            "skin_shadow": (193, 153, 126, 255),
            "skin_warm": (163, 117, 85, 255),
            "shirt_light": (244, 247, 250, 255),
            "accent_light": (195, 217, 236, 255),
            "ground_shadow": (38, 31, 29, 54),
        },
        "specific": {
            (30, 37, 56, 255): (47, 58, 77, 255),
            (70, 83, 105, 255): (91, 113, 138, 255),
            (74, 120, 170, 255): (124, 156, 196, 255),
            (245, 247, 250, 255): (233, 239, 245, 255),
            (220, 222, 225, 255): (197, 207, 217, 255),
            (64, 76, 96, 255): (76, 93, 117, 255),
        },
    },
    "designer.png": {
        "common": {
            "hair_dark": (93, 67, 57, 255),
            "hair_light": (145, 108, 93, 255),
            "skin_base": (235, 202, 178, 255),
            "skin_shadow": (210, 171, 146, 255),
            "skin_warm": (184, 137, 101, 255),
            "shirt_light": (247, 240, 230, 255),
            "accent_light": (230, 214, 194, 255),
            "ground_shadow": (45, 32, 28, 54),
        },
        "specific": {
            (57, 57, 69, 255): (104, 86, 55, 255),
            (69, 71, 80, 255): (143, 117, 78, 255),
            (63, 63, 75, 255): (170, 140, 99, 255),
            (235, 229, 220, 255): (239, 230, 214, 255),
            (249, 242, 233, 255): (251, 243, 232, 255),
            (211, 206, 198, 255): (220, 204, 181, 255),
            (142, 117, 100, 255): (110, 147, 124, 255),
            (63, 65, 73, 255): (124, 100, 69, 255),
        },
    },
    "programmer.png": {
        "common": {
            "hair_dark": (42, 41, 49, 255),
            "hair_light": (86, 81, 96, 255),
            "skin_base": (222, 184, 156, 255),
            "skin_shadow": (189, 147, 120, 255),
            "skin_warm": (153, 108, 76, 255),
            "shirt_light": (237, 242, 247, 255),
            "accent_light": (191, 214, 237, 255),
            "ground_shadow": (31, 28, 36, 54),
        },
        "specific": {
            (46, 51, 60, 255): (43, 52, 67, 255),
            (68, 77, 94, 255): (72, 93, 118, 255),
            (92, 128, 166, 255): (113, 147, 187, 255),
            (238, 242, 247, 255): (227, 233, 240, 255),
            (214, 217, 222, 255): (191, 202, 214, 255),
            (62, 70, 86, 255): (55, 69, 91, 255),
            (252, 255, 255, 255): (244, 248, 252, 255),
        },
    },
}


def build_lookup(file_name: str) -> dict[tuple[int, int, int, int], tuple[int, int, int, int]]:
    config = CHARACTER_MAPS[file_name]
    lookup: dict[tuple[int, int, int, int], tuple[int, int, int, int]] = {}

    for source_color, token in COMMON_BASE_MAP.items():
        lookup[source_color] = config["common"][token]

    for source_color, target_color in config["specific"].items():
        lookup[source_color] = target_color

    return lookup


def restyle(file_name: str) -> None:
    path = ASSET_DIR / file_name
    image = Image.open(path).convert("RGBA")
    lookup = build_lookup(file_name)

    pixels = []
    for pixel in image.getdata():
        pixels.append(lookup.get(pixel, pixel))

    image.putdata(pixels)
    image.save(path)
    print(f"restyled {file_name}")


def main() -> None:
    for file_name in CHARACTER_MAPS:
        restyle(file_name)


if __name__ == "__main__":
    main()
