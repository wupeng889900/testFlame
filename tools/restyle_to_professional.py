from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "characters"

# Define Professional Palette based on the reference image
PROFESSIONAL_BROWN = (105, 87, 85, 255)   # Suit jacket base
PROFESSIONAL_BROWN_SHADOW = (75, 61, 59, 255) # Suit jacket shadow
PROFESSIONAL_GREY = (70, 75, 85, 255)    # Skirt/Pants base
PROFESSIONAL_GREY_SHADOW = (50, 55, 60, 255)  # Skirt/Pants shadow
PROFESSIONAL_SKIN = (235, 205, 190, 255)  # Realistic skin base
PROFESSIONAL_SKIN_SHADOW = (210, 170, 145, 255) # Realistic skin shadow
PROFESSIONAL_HAIR = (60, 55, 70, 255)    # Dark hair base
PROFESSIONAL_HAIR_SHADOW = (45, 36, 50, 255)  # Dark hair shadow

CHARACTER_MAPS = {
    "programmer.png": {
        "specific": {
            # Clothes (Dark/Grey style)
            (43, 52, 67, 255): PROFESSIONAL_GREY,
            (62, 70, 86, 255): PROFESSIONAL_GREY_SHADOW,
            (227, 233, 240, 255): (245, 245, 245, 255), # White shirt
            (191, 202, 214, 255): (220, 220, 220, 255), # White shirt shadow
            (113, 147, 187, 255): PROFESSIONAL_BROWN,   # Brown jacket accent
            # Skin
            (153, 108, 76, 255): PROFESSIONAL_SKIN,
            (189, 147, 120, 255): PROFESSIONAL_SKIN_SHADOW,
            (222, 184, 156, 255): (245, 220, 210, 255), # Light skin highlight
            # Hair
            (42, 41, 49, 255): PROFESSIONAL_HAIR,
            (31, 28, 36, 54): (40, 35, 45, 54), # Shadow ground
            (86, 81, 96, 255): PROFESSIONAL_HAIR_SHADOW,
        }
    },
    "designer.png": {
        "specific": {
            # Suit (Brown style)
            (104, 86, 55, 255): PROFESSIONAL_BROWN,
            (124, 100, 69, 255): PROFESSIONAL_BROWN_SHADOW,
            (143, 117, 78, 255): PROFESSIONAL_GREY,     # Secondary grey
            (170, 140, 99, 255): (245, 245, 245, 255), # White shirt highlight
            (220, 204, 181, 255): (220, 220, 220, 255), # White shirt shadow
            # Skin
            (235, 202, 178, 255): PROFESSIONAL_SKIN,
            (210, 171, 146, 255): PROFESSIONAL_SKIN_SHADOW,
            # Hair
            (93, 67, 57, 255): PROFESSIONAL_HAIR,
            (145, 108, 93, 255): PROFESSIONAL_HAIR_SHADOW,
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
    # Save as a new file to avoid overwriting original assets
    new_path = ASSET_DIR / f"prof_{file_name}"
    image.save(new_path)
    print(f"Created professional version: {new_path.name}")

def main() -> None:
    for file_name in CHARACTER_MAPS:
        restyle(file_name)

if __name__ == "__main__":
    main()
