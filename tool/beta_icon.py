"""(15-11-2026, his decisions) THE SKETCHLINE BETA APP's icon: the Sketchline lion with a gold "BETA" pill – so a tester never mixes the
two apps on his phone. Run only by .github/workflows/beta.yml on its own checkout, before the build (the files in git stay the
Sketchline ones). Usage: python3 tool/beta_icon.py [res-folder]   (default android/app/src/main/res)"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

RES = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/res'
FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'fonts', 'Montserrat_800ExtraBold.ttf')
GOLD, INK = (217, 119, 6, 255), (255, 255, 255, 255)


def mark(path, top, height, width):
    """the pill [top, top+height] (parts of the picture's height), [width] of its width, centred"""
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    pw, ph = int(w * width), max(6, int(h * height))
    x0, y0 = (w - pw) // 2, int(h * top)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x0, y0, x0 + pw, y0 + ph], radius=ph // 2, fill=GOLD, outline=INK, width=max(1, ph // 14))
    size = int(ph * 0.66)
    f = ImageFont.truetype(FONT, size)
    while size > 4 and d.textlength('BETA', font=f) > pw * 0.8:
        size -= 1
        f = ImageFont.truetype(FONT, size)
    d.text((w / 2, y0 + ph / 2), 'BETA', font=f, fill=INK, anchor='mm')
    im.save(path)


n = 0
# the adaptive icon's picture (shown inside the phone's mask, 16 % in from each side – mipmap-anydpi-v26/ic_launcher.xml)
for p in glob.glob(os.path.join(RES, 'drawable-*', 'ic_launcher_foreground.png')):
    mark(p, 0.71, 0.15, 0.58)
    n += 1
# the older phones' whole icon
for p in glob.glob(os.path.join(RES, 'mipmap-*', 'ic_launcher.png')):
    mark(p, 0.72, 0.15, 0.56)
    n += 1
if n == 0:
    sys.exit('beta_icon: no launcher icon under ' + RES)
print('beta_icon: %d pictures marked BETA' % n)
