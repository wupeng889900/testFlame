from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "characters"

# Define White Collar Palette (Based on character_support_02.png)
WHITE_SHIRT = (245, 245, 245, 255)
WHITE_SHIRT_SHADOW = (210, 215, 220, 255)
DARK_PANTS = (50, 50, 65, 255)
DARK_PANTS_SHADOW = (35, 35, 45, 255)
BLACK_TIE = (20, 20, 25, 255)
SKIN_BASE = (235, 205, 190, 255)
SKIN_SHADOW = (210, 170, 145, 255)

CHARACTER_MAPS = {
    "programmer.png": {
        "specific": {
            # Shirt (White)
            (227, 233, 240, 255): WHITE_SHIRT,
            (191, 202, 214, 255): WHITE_SHIRT_SHADOW,
            # Pants (Dark)
            (43, 52, 67, 255): DARK_PANTS,
            (62, 70, 86, 255): DARK_PANTS_SHADOW,
            # Tie/Accent
            (113, 147, 187, 255): BLACK_TIE,
            # Skin
            (153, 108, 76, 255): SKIN_BASE,
            (189, 147, 120, 255): SKIN_SHADOW,
        }
    },
    "designer.png": {
        "specific": {
            # Clothes to White Collar
            (104, 86, 55, 255): DARK_PANTS,
            (143, 117, 78, 255): DARK_PANTS_SHADOW,
            (170, 140, 99, 255): WHITE_SHIRT,
            (220, 204, 181, 255): WHITE_SHIRT_SHADOW,
            # Skin
            (235, 202, 178, 255): SKIN_BASE,
            (210, 171, 146, 255): SKIN_SHADOW,
        }
    }
}

def restyle(file_name: str) -> None:
    path = ASSET_DIR / file_name
    if not path.exists():
        print(f"Skip {file_name}, not found")
        return
    
    image = Image.open(path).convert("RGBA")
    config = CHARACTER_MAPS.get(file_name, {})
    lookup = config.get("specific", {})

    pixels = []
    for pixel in image.getdata():
        pixels.append(lookup.get(pixel, pixel))

    image.putdata(pixels)
    new_path = ASSET_DIR / f"whitecollar_{file_name}"
    image.save(new_path)
    print(f"Created White Collar version: {new_path.name}")

def main() -> None:
    for file_name in CHARACTER_MAPS:
        restyle(file_name)

if __name__ == "__main__":
    main()
