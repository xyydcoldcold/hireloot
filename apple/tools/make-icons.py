"""Draws the Hireloot icon (the hero's head over sky and grass) on a 16x16 pixel grid
and writes every icon file: favicon.svg, favicon-32.png, apple-touch-icon.png and the
iPhone / Mac AppIcon set.   python3 apple/tools/make-icons.py   (run from the repo root)
The head is symmetric and spans columns 3-12, so it sits exactly in the middle."""
from PIL import Image

SKY, CLOUD, GRASS_HI, GRASS = '#5b6ee1', '#a9b8f0', '#4f9a45', '#3f7a3a'
K, HAIR, HAIR_HI, SKIN, EYE, MOUTH = '#07061a', '#3b2a1a', '#6b4a2b', '#f1c27d', '#1b1a2b', '#c0392b'
PAL = {'k': K, 'h': HAIR, 'H': HAIR_HI, 's': SKIN, 'e': EYE, 'm': MOUTH}
HEAD = {  # row: 16 columns, '.' = background
    4:  '.....kkkkkk.....',
    5:  '....khhhhhhk....',
    6:  '...khHhhhhhhk...',
    7:  '...khsssssshk...',
    8:  '...ksessssesk...',
    9:  '...kssssssssk...',
    10: '....kssmmssk....',
    11: '.....kkkkkk.....',
}

def grid():
    g = [[SKY] * 16 for _ in range(10)] + [[GRASS_HI] * 16] + [[GRASS] * 16 for _ in range(5)]
    for x in range(1, 4): g[1][x] = CLOUD
    for x in range(12, 15): g[2][x] = CLOUD
    for y, row in HEAD.items():
        for x, c in enumerate(row):
            if c != '.': g[y][x] = PAL[c]
    return g

def png(size, path):
    g = grid()
    small = Image.new('RGB', (16, 16))
    small.putdata([tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for row in g for c in row])
    small.resize((size, size), Image.NEAREST).save(path)

def svg(path):
    g = grid()
    rects = ''.join(f'<rect x="{x}" y="{y}" width="1" height="1" fill="{c}"/>'
                    for y, row in enumerate(g) for x, c in enumerate(row))
    open(path, 'w').write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" shape-rendering="crispEdges">' + rects + '</svg>\n')

if __name__ == '__main__':
    svg('favicon.svg')
    png(32, 'favicon-32.png')
    png(180, 'apple-touch-icon.png')
    d = 'apple/Hireloot/Assets.xcassets/AppIcon.appiconset/'
    png(1024, d + 'icon-1024.png')
    for s in (16, 32, 128, 256, 512):
        png(s, d + f'mac-{s}@1x.png')
        png(s * 2, d + f'mac-{s}@2x.png')
    print('icons written')
