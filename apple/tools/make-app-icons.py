"""Builds the iPhone / Mac AppIcon set from the web home-screen icon (apple-touch-icon.png),
so the app icon looks exactly like the bookmark icon (same crop, head centered).
   python3 apple/tools/make-app-icons.py   (run from the repo root)"""
from PIL import Image

src = Image.open('apple-touch-icon.png').convert('RGB')
d = 'apple/Hireloot/Assets.xcassets/AppIcon.appiconset/'

def out(size, path):
    # Nearest keeps the pixel-art edges sharp when scaling up; small Mac sizes use box filtering.
    src.resize((size, size), Image.NEAREST if size >= 180 else Image.BOX).save(path)

out(1024, d + 'icon-1024.png')
for s in (16, 32, 128, 256, 512):
    out(s, d + f'mac-{s}@1x.png')
    out(s * 2, d + f'mac-{s}@2x.png')
print('app icons written')
