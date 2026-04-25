from pathlib import Path
import re
for name in [r'e:\testFlame\tmp\downloads\topdown_characters.zip', r'e:\testFlame\tmp\downloads\office_furniture.zip']:
    s = Path(name).read_text(encoding='utf-8', errors='ignore')
    print('\nFILE:', name)
    for m in re.findall(r'<script[^>]+src="([^"]+)"', s):
        print(m)
