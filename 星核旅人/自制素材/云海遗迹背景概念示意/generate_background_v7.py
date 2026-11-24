"""V7: V6 geometry retained; local, stepped atmospheric perspective only."""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageChops

HERE = Path(__file__).resolve().parent
TEMP = Path(r'C:\Users\aqiqiqi\AppData\Local\Temp\opencode')
inputs = [HERE / name for name in
          ('background_only_v6.png', 'generate_background_v6.py', 'source_v6.md')]
hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
original = Image.open(inputs[0]).convert('RGB')
base = original.resize((640, 360), Image.Resampling.NEAREST)
im = base.copy()

# Execute only the isolated geometry definitions, not the V6 generator:
# no V5 loading, background erasure, image writing or directory enumeration.
source = inputs[1].read_text(encoding='utf-8')
geometry = source[source.index("layer=Image.new('RGBA'"):source.index('im.paste(layer,')]
STONE=(67,94,116); SHADE=(48,74,97); LIGHT=(101,128,145)
MID=(82,110,132); JOINT=(55,82,104); EDGE=(112,139,153)
ns = dict(Image=Image, ImageDraw=ImageDraw, ImageChops=ImageChops,
          math=math, STONE=STONE, SHADE=SHADE, LIGHT=LIGHT,
          MID=MID, JOINT=JOINT, EDGE=EDGE)
exec(compile(geometry, 'v6_geometry_only', 'exec'), ns)
layer = ns['layer']
palette = {STONE:(94,122,138), SHADE:(82,110,128),
           LIGHT:(113,139,151), MID:(101,128,143),
           JOINT:(91,119,135), EDGE:(118,144,154)}
def mix(a, b, t):
    return tuple(round(x*(1-t)+z*t) for x,z in zip(a,b))

bridge_mask = Image.new('L', base.size)
changed_bridge = 0
for y in range(130, 300):
    for x in range(640):
        rgba = layer.getpixel((x,y))
        old = base.getpixel((x,y))
        # Exact source identity excludes clouds already occluding the bridge.
        if rgba[3] != 255 or old != rgba[:3]:
            continue
        bridge_mask.putpixel((x,y),255)
        stone = palette[old]
        if y < 205:
            stone = mix(old, stone, .78)  # readable capitals and upper beam
        # Selected joints merge into their face; retain a few structural cues.
        if old == JOINT and (y >= 220 or (x//18)%3 != 0):
            stone = (95,123,139)
        # Eight finite haze levels, with horizontal cloud-lobe offsets.
        # Only stone pixels are changed. No blur, glow or sky recoloring.
        wave = (0,2,3,1,-1,-2,-1,1)[(x//24)%8]
        depth = y + wave
        fog = 0.0
        for start, amount in [(231,.08),(239,.18),(247,.31),(254,.46),
                              (260,.62),(266,.77),(272,.90),(279,1.0)]:
            if depth >= start:
                fog = amount
        stone = mix(stone, (133,173,181), fog)
        im.putpixel((x,y),stone)
        changed_bridge += stone != old

# Isolated debris zones only. Existing distant courtyards/islands are untouched.
# The blue-green interval identifies stone in these zones, not cyan sky/cloud.
zones = [
    ((203,174,224,190), .44, 'upper_small'),
    ((395,190,425,217), .55, 'far_rock'),
    ((300,205,345,247), .29, 'near_central'),
    ((263,242,290,264), .23, 'near_small'),
    ((285,255,296,266), .48, 'small_far'),
    ((378,233,390,248), .48, 'right_small'),
    ((277,272,328,306), .62, 'cloud_arch_left'),
    ((389,272,440,307), .57, 'cloud_arch_right'),
    ((227,286,266,329), .34, 'near_low_rock'),
    ((344,283,361,299), .58, 'cloud_chip'),
]
debris_mask = Image.new('L',base.size)
for (x0,y0,x1,y1),strength,label in zones:
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            c = base.getpixel((x,y))
            if bridge_mask.getpixel((x,y)):
                continue
            if label == 'upper_small':
                eligible = c in {(70,100,121),(51,79,102),(98,126,143)}
            else:
                eligible = c[2]-c[1] >= 15 and c[0] <= 125
            if not eligible:
                continue
            # Compress contrast before adding distance-specific atmospheric color.
            reduced = mix(c,(100,132,147),.22)
            haze = (119,160,172) if y < 265 else (142,181,187)
            t = strength
            if y >= 275:
                t = min(.87, strength + max(0,(y-282)//5)*.06)
            im.putpixel((x,y), mix(reduced,haze,t))
            debris_mask.putpixel((x,y),255)

diff = ImageChops.difference(base,im)
assert diff.crop((0,0,640,130)).getbbox() is None
allowed = ImageChops.lighter(bridge_mask,debris_mask)
changed = diff.convert('L').point(lambda v: 255 if v else 0)
assert ImageChops.subtract(changed,allowed).getbbox() is None
# Every pixel outside the explicit stone masks, including all sky/cloud, is exact.
assert ImageChops.difference(original,base.resize(original.size,Image.Resampling.NEAREST)).getbbox() is None
out = im.resize((1280,720),Image.Resampling.NEAREST)
out.save(HERE/'background_only_v7.png')
out.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_background_v7_check_720.png')
for p,digest in hashes.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest() == digest
print('V7: 1280x720 NEAREST; unchanged V6 geometry; bridge pixels adjusted:',changed_bridge)
print('Sky/cloud and y<130 exact; changes confined to structural/debris masks; three V6 inputs unchanged.')
