"""后景遗迹细化预览 V2：从 V7 静态背景重新派生，不执行旧生成器。

输入：云海遗迹背景概念示意/background_only_v7.png（只读）
      generate_background_v6.py 仅隔离读取桥体几何定义
输出：本目录 1280x720 / 640x360 纯背景，及自审用局部 V1/V2 对比。

V2 取舍：
- 不沿用 V1 的通长砌缝、外圈拱券高光、桥墩长竖线、远建筑格子线。
- 桥墩细节只到 y238 并向下淡出，所有色阶以当地像素为基准，随云前渐隐。
- 断口按受光方向处理：左桥断头朝右=背光，右桥断头朝左=受光。
- 右浮岛底与断柱顶切开 5px 空气，断柱另做受光断口，使岛读为远处独立浮体。
- 远遗迹只用少量平面明暗与顶面受光，不加砖缝。
"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageChops

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / '云海遗迹背景概念示意'
V1_DIR = HERE.parent / '后景遗迹细化预览_V1'
V7 = SRC / 'background_only_v7.png'
V6 = SRC / 'generate_background_v6.py'
V7_MD = SRC / 'source_v7.md'
V1_MAIN = V1_DIR / 'background_detail_v1.png'
INPUTS = [V7, V6, V7_MD, V1_MAIN]
BEFORE = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in INPUTS}

original = Image.open(V7).convert('RGB')
assert original.size == (1280, 720)
base = original.resize((640, 360), Image.Resampling.NEAREST)
assert base.resize((1280, 720), Image.Resampling.NEAREST).tobytes() == original.tobytes()

CLOUD = {(133,173,181),(148,186,191),(142,181,187),(151,189,193),
         (164,198,201),(157,192,197),(135,174,182),(148,184,190)}

def sky(y):
    return tuple(round(a + (b - a) * min(1, y / 315))
                 for a, b in zip((45, 90, 112), (120, 165, 174)))

# ---- 只在文本层读取 V6 桥体定义，不执行 V6 的读写逻辑。 ----
source = V6.read_text(encoding='utf-8')
geometry = source[source.index("layer=Image.new('RGBA'"):source.index('im.paste(layer,')]
STONE=(67,94,116); SHADE=(48,74,97); LIGHT=(101,128,145)
MID=(82,110,132); JOINT=(55,82,104); EDGE=(112,139,153)
ns = dict(Image=Image, ImageDraw=ImageDraw, ImageChops=ImageChops, math=math,
          STONE=STONE, SHADE=SHADE, LIGHT=LIGHT, MID=MID, JOINT=JOINT, EDGE=EDGE)
exec(compile(geometry, 'v6_geometry_only', 'exec'), ns)
struct = ns['layer']

# ---- 掩膜 ----
bridge = Image.new('L', (640, 360))
for y in range(130, 300):
    for x in range(640):
        if struct.getpixel((x, y))[3] != 255:
            continue
        # V7 已把墩脚渐隐为云色；云色像素一律不再细化，也不改云。
        if y <= 277 and base.getpixel((x, y)) not in CLOUD:
            bridge.putpixel((x, y), 255)

def building_mask(box):
    """远建筑：紧包围盒内以“非天空梯度”取形体，并排除桥柱/桥体。"""
    m = Image.new('L', (640, 360))
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            if base.getpixel((x, y)) != sky(y) and not bridge.getpixel((x, y)):
                m.putpixel((x, y), 255)
    return m

left_isl = building_mask((28, 160, 112, 204))       # 左端残厅/浮岛
far_cluster = building_mask((232, 160, 322, 206))   # 左后远院落（桥后）
right_isl = building_mask((436, 138, 540, 204))     # 右浮岛/小祠

# ---- 色阶：一律以当地像素为基准，避免硬色块在渐隐区形成切口。 ----
BR_LIGHT=(150, 176, 188); BR_DARK=(50, 80, 102)
FAR_LIGHT=(150, 184, 192); FAR_DARK=(66, 104, 122)

def tone(p, f, far=False):
    light, dark = (FAR_LIGHT, FAR_DARK) if far else (BR_LIGHT, BR_DARK)
    q = light if f >= 0 else dark
    t = abs(f)
    return tuple(round(a + (b - a) * t) for a, b in zip(p, q))

im = base.copy()
detail = Image.new('L', (640, 360))

def put(x, y, c, m):
    if not (0 <= x < 640 and 0 <= y < 360) or not m.getpixel((x, y)):
        return
    old = im.getpixel((x, y))
    if old != c:
        im.putpixel((x, y), c)
        detail.putpixel((x, y), 255)

def tint_px(x, y, f, m, far=False):
    p = im.getpixel((x, y))
    put(x, y, tone(p, f, far), m)

def band(mask, x0, x1, y0, y1, f, far=False):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if mask.getpixel((x, y)):
                tint_px(x, y, f, mask, far)

def plane(mask, x0, x1, y0, y1, f, far=False):
    """矩形面内统一微调；用于大面明暗，不描边。"""
    band(mask, x0, x1, y0, y1, f, far)

def top_ledges(mask, x0, x1, y0, y1, f, far=False):
    """只点亮真正朝上的轮廓台阶（上方无同物体像素）。"""
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            if mask.getpixel((x, y)) and not mask.getpixel((x, y - 1)):
                tint_px(x, y, f, mask, far)
                break

def side_face(mask, x0, x1, y0, y1, side, f, far=False):
    """沿某侧最外像素压 1px，用作断口/背光面；side=-1 左面，+1 右面。"""
    rng = range(x0, x1 + 1) if side < 0 else range(x1, x0 - 1, -1)
    for y in range(y0, y1 + 1):
        for x in rng:
            if mask.getpixel((x, y)):
                tint_px(x, y, f, mask, far)
                break

# ================= 左右断桥：同一中景，只做受力/断口，不铺满砌缝 =================
# 桥板与墩交接：檐下一道 1px 接触影，随后交给 V7 原有的墩面渐变。
for x0, x1 in [(46, 68), (144, 192), (465, 482), (538, 551)]:
    band(bridge, x0, x1, 220, 220, -0.11)

# 左桥板断头：外露截面朝右（背光），先压断面，再点朝上小台阶。
side_face(bridge, 256, 286, 206, 219, +1, -0.13)
top_ledges(bridge, 256, 286, 206, 219, +0.11)
# 右桥板断头：截面朝左（受光），与左桥同一套明暗逻辑。
side_face(bridge, 432, 450, 206, 219, -1, +0.12)
top_ledges(bridge, 432, 450, 206, 219, +0.10)
# 右横梁残端：端面朝右=背光；顶面另给 1px 受光。
side_face(bridge, 560, 572, 145, 150, +1, -0.12)
top_ledges(bridge, 560, 572, 143, 150, +0.08)

# ================= 右浮岛与断柱：切开空气，重建断柱顶 =================
# 岛底 y183 与柱顶 y184 原本硬接；将柱顶下移 5px，露出天空，岛仍保持原轮廓。
GAP_X0, GAP_X1 = 474, 482
GAP_Y0, GAP_Y1 = 184, 188
for y in range(GAP_Y0, GAP_Y1 + 1):
    for x in range(GAP_X0, GAP_X1 + 1):
        assert bridge.getpixel((x, y))
        assert base.getpixel((x, y)) not in CLOUD
        p = sky(y)
        if im.getpixel((x, y)) != p:
            im.putpixel((x, y), p)
            detail.putpixel((x, y), 255)
# 新柱顶：左半受光、右半背光，读成断口而不是平切。
for x in range(475, 478):
    tint_px(x, 189, +0.16, bridge)
for x in range(478, 482):
    tint_px(x, 189, -0.12, bridge)
for x in range(476, 482):
    tint_px(x, 190, -0.10, bridge)

# ================= 左端残厅/浮岛：只读大形体 =================
# 柱身：左 1px 受光、右 1px 背光；柱头下 1px 接触影；柱脚 1px 落在岛台上。
plane(left_isl, 44, 44, 172, 189, +0.10, True)
plane(left_isl, 49, 49, 172, 189, -0.07, True)
plane(left_isl, 65, 65, 178, 189, +0.09, True)
plane(left_isl, 69, 69, 178, 189, -0.06, True)
band(left_isl, 44, 49, 171, 171, -0.06, True)
band(left_isl, 65, 69, 177, 177, -0.05, True)
band(left_isl, 44, 49, 189, 189, -0.06, True)
band(left_isl, 65, 69, 189, 189, -0.06, True)
# 残墙：左侧受光面、右侧背光面，不划砖缝。
plane(left_isl, 79, 81, 180, 189, +0.06, True)
plane(left_isl, 90, 92, 180, 189, -0.07, True)
# 岛台顶面只在无可遮拦处点 1px 受光。
top_ledges(left_isl, 31, 100, 188, 199, +0.09, True)

# ================= 左后远院落：大面明暗 + 顶面受光，不加格子 =================
# 塔身左亮右暗；断顶由 top_ledges 统一受光。
plane(far_cluster, 245, 247, 177, 203, +0.06, True)
plane(far_cluster, 257, 259, 177, 203, -0.07, True)
# 门洞内右侧 1px 影，交代拱券厚度；不画外圈高光。
plane(far_cluster, 288, 288, 190, 203, -0.09, True)
# 右残墙左亮右暗。
plane(far_cluster, 296, 298, 190, 203, +0.05, True)
plane(far_cluster, 306, 308, 190, 203, -0.06, True)
# 顶面受光：塔顶、拱冠、墙头各自的小台阶，一线即可。
top_ledges(far_cluster, 244, 310, 172, 205, +0.08, True)

# ================= 右浮岛/小祠：弱化体块边，不加平台横带 =================
# 小祠：左墙受光、右墙背光；门洞保持原暗部。
plane(right_isl, 477, 478, 144, 157, +0.05, True)
plane(right_isl, 487, 488, 144, 157, -0.05, True)
# 附屋：同样只分左右面。
plane(right_isl, 498, 499, 153, 157, +0.05, True)
plane(right_isl, 505, 506, 153, 157, -0.05, True)
# 檐口与岛台只点朝上的边；平台前脸不划横带、不划竖缝。
top_ledges(right_isl, 470, 510, 136, 160, +0.06, True)
top_ledges(right_isl, 444, 536, 160, 176, +0.05, True)

# ---- 像素保护 ----
changed = Image.new('L', (640, 360))
for y in range(360):
    for x in range(640):
        if base.getpixel((x, y)) != im.getpixel((x, y)):
            changed.putpixel((x, y), 255)
allowed = ImageChops.lighter(ImageChops.lighter(bridge, left_isl),
                             ImageChops.lighter(far_cluster, right_isl))
assert ImageChops.subtract(changed, allowed).getbbox() is None
assert ImageChops.difference(base, im).crop((0, 0, 640, 130)).getbbox() is None

n_changed = 0
n_gap = 0
for y in range(360):
    for x in range(640):
        if not changed.getpixel((x, y)):
            continue
        n_changed += 1
        old = base.getpixel((x, y))
        assert old not in CLOUD, (x, y, old)
        assert old != sky(y), (x, y, old)
        if GAP_X0 <= x <= GAP_X1 and GAP_Y0 <= y <= GAP_Y1:
            n_gap += 1
            assert im.getpixel((x, y)) == sky(y)
assert n_gap == (GAP_X1 - GAP_X0 + 1) * (GAP_Y1 - GAP_Y0 + 1)

# ---- 输出 ----
out640 = im.copy()
out640.save(HERE / 'background_detail_v2_640x360.png')
out = im.resize((1280, 720), Image.Resampling.NEAREST)
out.save(HERE / 'background_detail_v2.png')
assert out.resize((640, 360), Image.Resampling.NEAREST).tobytes() == out640.tobytes()

detail.save(HERE / 'mask_detail_v2.png')

# 自审：局部 V1 / V2 对比（左 V1、右 V2），5x NEAREST，无文字。
v1 = Image.open(V1_MAIN).convert('RGB').resize((640, 360), Image.Resampling.NEAREST)
crops = [(248, 196, 300, 232), (232, 160, 322, 208), (455, 172, 500, 210)]
scale = 5
cw = max(b[2] - b[0] for b in crops) * scale
ch = max(b[3] - b[1] for b in crops) * scale
pad = 8
comp = Image.new('RGB', (cw * 2 + pad * 3, ch * len(crops) + pad * (len(crops) + 1)), (18, 24, 28))
for i, box in enumerate(crops):
    w = (box[2] - box[0]) * scale; h = (box[3] - box[1]) * scale
    old = v1.crop(box).resize((w, h), Image.Resampling.NEAREST)
    new = im.crop(box).resize((w, h), Image.Resampling.NEAREST)
    yy = pad + i * (ch + pad)
    comp.paste(old, (pad, yy))
    comp.paste(new, (pad * 2 + cw, yy))
comp.save(HERE / 'check_local_v1_vs_v2.png')

for p, digest in BEFORE.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest() == digest, str(p)

out_hash = hashlib.sha256((HERE / 'background_detail_v2.png').read_bytes()).hexdigest()
out640_hash = hashlib.sha256((HERE / 'background_detail_v2_640x360.png').read_bytes()).hexdigest()
manifest = {
    'version': 'V2',
    'date': '2026-11-02',
    'canvas': {'logical': [640, 360], 'preview': [1280, 720], 'scale': 'NEAREST 2x'},
    'inputs': {p.name: BEFORE[p] for p in INPUTS},
    'outputs': {
        'background_detail_v2.png': out_hash,
        'background_detail_v2_640x360.png': out640_hash,
        'generate_background_detail_v2.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    },
    'changed_pixels_logical': n_changed,
    'gap_pixels_logical': n_gap,
    'changed_bbox_logical': list(ImageChops.difference(base, im).getbbox()),
    'structure_changes': [
        '右浮岛底与断柱顶之间切开 5px 天空（x474-482, y184-188），断柱顶下移并重做受光断口',
        '桥墩细节在 y220 接触影后不再向下描边，保留 V7 原有随云渐隐',
        '左桥断头按朝右背光处理，右桥断头按朝左受光处理；右横梁端面压暗',
        '远遗迹只用顶面受光与左右大面微差，不铺砖缝/不描外圈',
    ],
    'protection': {
        'outside_masks': 0,
        'sky_above_y130_exact': True,
        'cloud_palette_pixels_changed': 0,
        'sky_gradient_pixels_changed': 0,
        'v7_unchanged': True,
        'v1_unchanged': True,
    },
    'unverified': [
        '未接 Godot、无引擎截图或连续试玩',
        '未制作浮动动画；右浮岛与断柱的空气间隙只是静态遮挡修正，动态分组/隐藏补面未验证',
        '未修 DS02 的左右断桥遮挡与右桥下静止白云',
        '桥后/云后不可见建筑面未补绘',
        '云中残拱、游离浮石、天空云、云海未改',
        '用户是否认可 V2 尚未确定',
    ],
}
import json
(HERE / 'manifest_v2.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('changed logical pixels:', n_changed)
print('gap pixels:', n_gap)
print('changed bbox:', diff_bbox := ImageChops.difference(base, im).getbbox())
print('bridge mask:', sum(bridge.histogram()[1:]))
print('left_isl:', left_isl.getbbox(), 'far_cluster:', far_cluster.getbbox(),
      'right_isl:', right_isl.getbbox())
print('sha256 source v7 :', BEFORE[V7])
print('sha256 output    :', out_hash)
print('sha256 output640 :', out640_hash)
print('V7 / V6 / source_v7.md / V1 unchanged.')
