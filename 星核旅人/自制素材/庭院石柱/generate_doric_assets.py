"""V4-only, silhouette-preserving stone detail; offline Pillow asset generator."""
from pathlib import Path
import hashlib
import importlib.util
import inspect
import json
import sys
from PIL import ImageDraw

OUT = Path(__file__).resolve().parent
CONCEPT = OUT.parent / '庭院地面物件概念示意'
SOURCE = CONCEPT / 'generate_concept_v4.py'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('doric_v4', SOURCE)
v4 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v4)

# Short, hand-placed value steps only. No random noise, blur or new silhouettes.
PALETTE = {
    'lip': (160, 145, 138, 255),
    'lit': (174, 161, 151, 255),
    'pit': (128, 112, 113, 255),
    'recess': (103, 87, 93, 255),
    'darklip': (122, 104, 107, 255),
    'grain': (154, 139, 133, 255),
}


def detail(original, kind):
    im = original.copy()
    d = ImageDraw.Draw(im)

    def line(points, color):
        d.line(points, fill=PALETTE[color])

    if kind in ('tall', 'broken'):
        start = 15 if kind == 'tall' else 0
        end = im.height - 9
        # A one-pixel bevel only at selected groove sections; retain V4's broad
        # left-light/right-dark bands and avoid adding more full-height stripes.
        for a, b in ((8, 16), (35, 43), (59, 65)):
            if start + b < end - 5:
                line([(17, start+a), (17, start+b)], 'lit')
                line([(23, start+a+2), (23, start+b)], 'lip')
                line([(30, start+a+1), (30, start+b-1)], 'recess')
                line([(32, start+a+1), (32, start+b-1)], 'darklip')
        # Existing V4 crack gets a tiny bevel and a short non-repeating branch.
        line([(28, start+23), (27, start+25)], 'lip')
        line([(26, start+30), (28, start+32), (28, start+34)], 'recess')
        line([(27, start+31), (28, start+32)], 'darklip')
        # A handful of broad, low-contrast stone flakes, not repeating masonry.
        line([(20, start+19), (21, start+19)], 'grain')
        line([(20, start+20), (21, start+20)], 'pit')
        line([(27, start+46), (29, start+46)], 'grain')
        line([(28, start+47), (29, start+47)], 'pit')
        line([(20, end-10), (22, end-10)], 'grain')
        line([(21, end-9), (22, end-9)], 'pit')
    if kind in ('broken', 'base'):
        # Small facet planes stay inside V4's existing broken top.
        line([(17, 4), (19, 5), (21, 5)], 'lit')
        line([(25, 3), (26, 4), (28, 4)], 'grain')
        line([(29, 5), (31, 4), (32, 4)], 'lip')
        line([(29, 6), (31, 6)], 'pit')
        line([(19, 9), (20, 10), (20, 12)], 'pit')
        line([(21, 10), (21, 11)], 'grain')
    if kind == 'tall':
        line([(15, 1), (18, 1)], 'lit')
        line([(29, 3), (30, 3)], 'grain')
        line([(18, 8), (19, 8)], 'lit')
        line([(33, 9), (34, 9)], 'darklip')
    if kind != 'fallen':
        y = im.height - 1
        line([(15, y-7), (18, y-7)], 'lit')
        line([(27, y-7), (29, y-7)], 'grain')
        line([(20, y-4), (22, y-4)], 'grain')
        line([(21, y-3), (22, y-3)], 'pit')
        line([(35, y-4), (37, y-4)], 'darklip')
    else:
        line([(15, 7), (22, 7)], 'lip')
        line([(34, 7), (41, 7)], 'lip')
        line([(16, 14), (23, 14)], 'recess')
        line([(34, 16), (41, 16)], 'darklip')
        line([(29, 7), (30, 8)], 'lip')
        line([(30, 11), (32, 12), (34, 12)], 'recess')
        line([(19, 10), (21, 10)], 'grain')
        line([(20, 11), (21, 11)], 'pit')
        line([(38, 19), (40, 19)], 'darklip')
        line([(4, 9), (5, 8), (6, 8)], 'lit')
        line([(7, 11), (8, 13), (8, 15)], 'grain')
        line([(5, 17), (6, 19)], 'lip')
        line([(48, 9), (49, 8), (50, 8)], 'darklip')
        line([(50, 16), (51, 18)], 'recess')
    # Enforce both exact alpha and unchanged transparent RGB: no outline edits.
    for y in range(im.height):
        for x in range(im.width):
            old = original.getpixel((x, y))
            new = im.getpixel((x, y))
            im.putpixel((x, y), (*new[:3], old[3]) if old[3] else old)
    return im


def originals():
    return {
        'tall': v4.column(),
        'broken': v4.column(82, broken=True),
        'base': v4.column(24, stump=True),
        'fallen': v4.fallen(),
    }


def build():
    return {kind: detail(im, kind) for kind, im in originals().items()}


def generate():
    assets = build()
    functions = {'tall': 'column()', 'broken': 'column(82, broken=True)',
                 'base': 'column(24, stump=True)', 'fallen': 'fallen()'}
    records = []
    for kind, im in assets.items():
        name = f'doric_column_{kind}.png'
        path = OUT / name
        im.save(path)
        bbox = im.getchannel('A').getbbox()
        records.append({
            'file': name, 'size': list(im.size), 'alpha_bbox': list(bbox),
            'foot_anchor': [im.width // 2, bbox[3]],
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'v4_source_function': functions[kind],
            'detail_method': '原有不透明像素内手置离散色阶：浅槽局部倒角、少量石片层理、原裂纹边缘与断面小切面；保留全部alpha及透明RGB',
        })
    manifest = {
        'version': 'v5_detail', 'status': 'transparent source assets; not engine-integrated',
        'source': '../庭院地面物件概念示意/generate_concept_v4.py',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'pixel_filter': 'nearest', 'scale': '1 source pixel = 1 logical pixel',
        'anchor_convention': 'canvas中轴x；alpha bbox bottom半开边界y；不是最后一行像素坐标',
        'assets': records,
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    # Reuse the actual V4 staging function without editing its file or assets.
    # Only substitute column providers and output filename in an isolated namespace.
    namespace = vars(v4).copy()
    namespace['column'] = lambda height=108, broken=False, stump=False: assets['base' if stump else 'broken' if broken else 'tall'].copy()
    namespace['fallen'] = lambda: assets['fallen'].copy()
    source = inspect.getsource(v4.generate).replace("'concept_v4.png'", "'concept_v5_detail.png'")
    exec(compile(source, str(SOURCE) + ':staging-copy', 'exec'), namespace)
    namespace['generate']()
    return manifest


if __name__ == '__main__':
    generate()
