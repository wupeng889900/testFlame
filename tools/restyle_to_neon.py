from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "characters"

# Define Neon Palette
NEON_CYAN = (0, 255, 255, 255)
NEON_PURPLE = (191, 0, 255, 255)
DEEP_DARK = (20, 20, 30, 255)
PALE_SKIN = (240, 230, 220, 255)

CHARACTER_MAPS = {
    "programmer.png": {
        "specific": {
            (43, 52, 67, 255): DEEP_DARK,        # Dark clothes
            (227, 233, 240, 255): NEON_CYAN,     # Accent 1
            (113, 147, 187, 255): NEON_PURPLE,   # Accent 2
            (153, 108, 76, 255): PALE_SKIN,      # Skin
        }
    },
    "designer.png": {
        "specific": {
            (104, 86, 55, 255): DEEP_DARK,
            (143, 117, 78, 255): NEON_PURPLE,
            (170, 140, 99, 255): NEON_CYAN,
            (235, 202, 178, 255): PALE_SKIN,
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
        # Only replace if exact match in lookup
        pixels.append(lookup.get(pixel, pixel))

    image.putdata(pixels)
    # Save as a new file to avoid overwriting original assets during demo
    new_path = ASSET_DIR / f"neon_{file_name}"
    image.save(new_path)
    print(f"Created neon version: {new_path.name}")

def main() -> None:
    for file_name in CHARACTER_MAPS:
        restyle(file_name)

if __name__ == "__main__":
    main()
