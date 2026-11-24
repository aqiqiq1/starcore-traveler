"""后景遗迹细化预览 V1：只从 V7 静态背景派生，不执行旧生成器。

输入：云海遗迹背景概念示意/background_only_v7.png（不修改）
      generate_background_v6.py 仅隔离读取桥体几何定义
输出：本目录 1280x720 / 640x360 各一张纯背景，另附技术掩膜与自审对比。
"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageChops

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / '云海遗迹背景概念示意'
V7 = SRC / 'background_only_v7.png'
V6 = SRC / 'generate_background_v6.py'
V7_MD = SRC / 'source_v7.md'
INPUTS = [V7, V6, V7_MD]
BEFORE = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in INPUTS}

original = Image.open(V7).convert('RGB')
assert original.size == (1280, 720)
base = original.resize((640, 360), Image.Resampling.NEAREST)
# 确认 V7 是 640 逻辑图的精确 NEAREST 2x，避免在缩放图上猜像素。
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

# ---- 掩膜：桥体 / 三处远建筑 / 云中残拱足部 ----
bridge_full = Image.new('L', (640, 360))
bridge = Image.new('L', (640, 360))
for y in range(130, 300):
    for x in range(640):
        if struct.getpixel((x, y))[3] != 255:
            continue
        bridge_full.putpixel((x, y), 255)
        # V7 已把墩脚渐隐为云色；云色像素一律不再细化，也不改云。
        if y <= 277 and base.getpixel((x, y)) not in CLOUD:
            bridge.putpixel((x, y), 255)

def building_mask(box):
    """远建筑：在紧包围盒内以“非天空梯度”取形体，并排除桥柱。"""
    m = Image.new('L', (640, 360))
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            if base.getpixel((x, y)) != sky(y) and not bridge.getpixel((x, y)):
                m.putpixel((x, y), 255)
    return m

left_isl = building_mask((28, 160, 112, 204))       # 左端残厅/柱列
far_cluster = building_mask((232, 160, 322, 204))   # 左后远院落（桥后）
right_isl = building_mask((436, 138, 540, 204))     # 右浮岛/小祠

# 云中残拱只取暗部石面，绝不把云色或天空纳入。
arch = Image.new('L', (640, 360))
for y in range(278, 306):
    for x in range(279, 328):
        p = base.getpixel((x, y))
        if p not in CLOUD and p[0] <= 120 and p[2] - p[0] >= 15:
            arch.putpixel((x, y), 255)

# ---- 冷色细节阶；只在既有形体掩膜内落笔 ----
B_HI=(118,144,154); B_LIGHT=(110,136,149); B_MID=(99,126,141)
B_JOINT=(89,116,134); B_SHADOW=(81,107,126)
F_HI=(114,154,165); F_LIGHT=(108,148,160); F_MID=(102,143,156)
F_SH=(97,138,152); F_JOINT=(92,133,147); F_DEEP=(88,128,143)
R_HI=(114,154,165); R_SH=(97,137,151); R_DEEP=(89,131,146); R_JOINT=(92,132,146)
C_HI=(120,157,168); C_SH=(100,136,154)

im = base.copy()
detail = Image.new('L', (640, 360))

def put(x, y, c, m):
    if 0 <= x < 640 and 0 <= y < 360 and m.getpixel((x, y)):
        old = im.getpixel((x, y))
        if old != c:
            im.putpixel((x, y), c)
            detail.putpixel((x, y), 255)

def hline(x0, x1, y, c, m):
    for x in range(x0, x1 + 1):
        put(x, y, c, m)

def vline(x, y0, y1, c, m):
    for y in range(y0, y1 + 1):
        put(x, y, c, m)

def line(pts, c, m):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n) if n else x0
            y = round(y0 + (y1 - y0) * i / n) if n else y0
            put(x, y, c, m)

# ================= 左右断桥 =================
# 桥板：两道通长横缝 + 檐下投影；只在原实体上落笔，断口自然断开。
for x0, x1 in [(25, 284), (438, 570)]:
    hline(x0, x1, 212, B_JOINT, bridge)
    hline(x0, x1, 219, B_JOINT, bridge)
# 错缝竖砌：上/下层错开，数量控制在可读但不噪。
for x in (41, 74, 107, 139, 172, 204, 237, 269):
    vline(x, 209, 211, B_JOINT, bridge)
for x in (57, 90, 123, 155, 188, 220, 253):
    vline(x, 213, 215, B_JOINT, bridge)
for x in (454, 486, 518, 550):
    vline(x, 209, 211, B_JOINT, bridge)
for x in (470, 502, 534, 566):
    vline(x, 213, 215, B_JOINT, bridge)

# 墩面转角倒角与少量竖向风化；不改变墩宽、拱跨或支撑。
for x, y0, y1 in [(46,220,268),(144,220,266),(465,220,266),(538,220,266)]:
    vline(x, y0, y1, B_LIGHT, bridge)
for x, y0, y1 in [(68,220,268),(191,220,266),(481,220,266),(550,220,266)]:
    vline(x, y0, y1, B_SHADOW, bridge)
for x, y0, y1 in [(52,231,238),(161,224,231),(474,236,243),(545,229,236)]:
    vline(x, y0, y1, B_JOINT, bridge)

# 三道拱券：外缘受光、拱冠石锁石与两侧券缝，均在原券石上。
for cx, cy, rx, ry in [(106,267,30,34),(230,267,30,34),(510,267,27,34)]:
    # 只保留 1px 外缘受光；原有券石分缝已足够，不再叠加径向线。
    for deg in range(252, 289):
        a = math.radians(deg)
        put(round(cx + (rx + 8) * math.cos(a)),
            round(cy + (ry + 8) * math.sin(a)), B_HI, bridge)

# 左桥板集中断口：只加密破口截面，不散落碎石。
hline(260, 281, 206, B_HI, bridge)
line([(263,208),(268,209),(273,210),(278,211)], B_HI, bridge)
# 两处外露砌块截面。
for x0, y0, x1, y1 in [(262,213,266,216),(273,216,276,219)]:
    hline(x0, x1, y0, B_LIGHT, bridge)
    for y in range(y0 + 1, y1):
        hline(x0, x1, y, B_MID, bridge)
    hline(x0, x1, y1, B_SHADOW, bridge)
vline(262, 213, 216, B_SHADOW, bridge)
vline(266, 213, 216, B_SHADOW, bridge)
line([(264,217),(263,221),(265,225)], B_JOINT, bridge)
hline(261, 269, 221, B_SHADOW, bridge)

# 右桥板断头：破口亮边、外露砌块、下缘阴影。
hline(438, 445, 207, B_HI, bridge)
for x0, y0, x1, y1 in [(440,211,444,214)]:
    hline(x0, x1, y0, B_LIGHT, bridge)
    for y in range(y0 + 1, y1):
        hline(x0, x1, y, B_MID, bridge)
    hline(x0, x1, y1, B_SHADOW, bridge)
hline(435, 443, 217, B_SHADOW, bridge)
line([(445,215),(444,219),(445,222)], B_JOINT, bridge)

# 右横梁断端：断口亮面与下方阴影（只落在可见的阶梯状残端上）。
hline(565, 568, 145, B_LIGHT, bridge)
hline(566, 569, 149, B_SHADOW, bridge)
vline(564, 146, 149, B_SHADOW, bridge)

# 柱头/柱脚：檐下影、柱身左缘受光、残柱断口。
for x in (148, 188, 546):
    hline(x - 5, x + 5, 156, B_SHADOW, bridge)
    vline(x - 4, 160, 197, B_LIGHT, bridge)
for x in (228, 478):
    hline(x - 3, x + 3, 183, B_SHADOW, bridge)
    put(x - 1, 177, B_HI, bridge)
    line([(x, 183),(x - 1, 187),(x + 1, 191)], B_JOINT, bridge)
# 左横梁下沿的浅影，强化梁与柱的受力关系。
hline(138, 197, 151, B_SHADOW, bridge)
hline(537, 563, 151, B_SHADOW, bridge)

# ================= 左端残厅/浮岛 =================
# 岛缘：顶面受光、连续下缘影、局部浅层理；不扩展轮廓。
for x0, x1, y in [(34,49,192),(58,74,192),(90,98,193)]:
    hline(x0, x1, y, F_HI, left_isl)
# 只在每列最底的岛体像素上加 1px 下缘影，形成连续石檐而不是漂浮短线。
for x in range(31, 101):
    ys = [y for y in range(190, 201) if left_isl.getpixel((x, y))]
    if ys:
        put(x, max(ys), F_SH, left_isl)
# 柱列：左缘光、右缘影、柱头下影与中段石缝。
vline(44, 172, 189, F_HI, left_isl); vline(49, 172, 189, F_SH, left_isl)
vline(65, 178, 189, F_HI, left_isl); vline(69, 178, 189, F_SH, left_isl)
hline(42, 51, 171, F_SH, left_isl)
hline(61, 73, 177, F_SH, left_isl)
hline(44, 49, 182, F_JOINT, left_isl)
hline(65, 69, 184, F_JOINT, left_isl)
hline(43, 48, 172, F_HI, left_isl)
# 残墙：两条砌缝、错缝、顶部亮边与基脚影。
hline(80, 92, 184, F_JOINT, left_isl)
hline(80, 92, 189, F_JOINT, left_isl)
vline(86, 180, 183, F_JOINT, left_isl)
hline(79, 84, 180, F_HI, left_isl)
hline(85, 90, 183, F_HI, left_isl)
hline(80, 93, 194, F_SH, left_isl)

# ================= 左后远院落 =================
# 塔身：亮/暗面、两道层缝、错缝与断顶。
vline(245, 177, 203, F_HI, far_cluster)
vline(258, 177, 203, F_SH, far_cluster)
hline(246, 258, 185, F_JOINT, far_cluster)
hline(246, 258, 194, F_JOINT, far_cluster)
vline(251, 186, 193, F_JOINT, far_cluster)
vline(255, 195, 203, F_JOINT, far_cluster)
hline(247, 250, 176, F_HI, far_cluster)
hline(252, 258, 178, F_SH, far_cluster)
# 门洞/拱：外缘亮、内壁影、两道券缝与锁石；洞口天空不落笔。
line([(273,184),(277,181),(284,180),(288,182)], F_LIGHT, far_cluster)
vline(275, 192, 203, F_SH, far_cluster)
vline(288, 191, 203, F_DEEP, far_cluster)
line([(274,188),(272,184)], F_JOINT, far_cluster)
line([(289,188),(291,184)], F_JOINT, far_cluster)
# 远拱三道低对比券缝，只在石环内；不碰洞口天空。
line([(271,188),(277,189)], F_JOINT, far_cluster)
line([(278,182),(280,186)], F_JOINT, far_cluster)
line([(289,183),(285,187)], F_JOINT, far_cluster)
hline(280, 283, 180, F_LIGHT, far_cluster)
# 右侧残墙：层缝、竖缝、顶缘与暗侧。
hline(296, 311, 198, F_JOINT, far_cluster)
hline(296, 311, 203, F_JOINT, far_cluster)
vline(302, 191, 197, F_JOINT, far_cluster)
hline(296, 301, 190, F_HI, far_cluster)
vline(311, 192, 203, F_SH, far_cluster)
# 远台基前缘一线受光，接住桥后的层次。
hline(245, 310, 204, F_HI, far_cluster)

# ================= 右浮岛/小祠 =================
# 小祠：檐口亮/影、两侧转角、门洞内壁。
hline(475, 488, 138, R_HI, right_isl)
hline(475, 489, 143, R_SH, right_isl)
vline(475, 144, 157, R_HI, right_isl)
vline(488, 144, 157, R_SH, right_isl)
hline(478, 481, 145, R_HI, right_isl)
vline(481, 146, 155, R_DEEP, right_isl)
hline(475, 506, 158, R_SH, right_isl)
# 附屋：压顶亮边、檐下影。
hline(498, 506, 150, R_HI, right_isl)
hline(499, 506, 152, R_SH, right_isl)
# 岛台前缘：受光边、错缝与檐下暗线。
hline(450, 530, 164, R_HI, right_isl)
for x in (455, 476, 497, 518):
    vline(x, 164, 169, R_JOINT, right_isl)
for x0, x1, y in [(455,475,170),(481,500,170),(506,525,170)]:
    hline(x0, x1, y, R_SH, right_isl)
# 浮岛下缘：上迎光、檐下影；保留原有岩面转折，不另划长裂缝。
hline(470, 479, 174, R_HI, right_isl)
hline(489, 500, 177, R_HI, right_isl)
hline(510, 521, 180, R_HI, right_isl)
hline(492, 501, 183, R_SH, right_isl)
hline(518, 524, 188, R_SH, right_isl)

# ================= 云中残拱（仅足部，极克制） =================
# 只取暗部石面 20 余像素，给两足加一道受光边和一道下缘影；冠部不动。
hline(280, 286, 290, C_HI, arch)
hline(279, 286, 293, C_SH, arch)
hline(319, 325, 296, C_HI, arch)
hline(318, 324, 303, C_SH, arch)

# ---- 像素保护 ----
diff = ImageChops.difference(base, im)
# 用逐通道非零判定，避免 convert('L') 把极小色差吞掉。
changed = Image.new('L', (640, 360))
for y in range(360):
    for x in range(640):
        if base.getpixel((x, y)) != im.getpixel((x, y)):
            changed.putpixel((x, y), 255)
allowed = ImageChops.lighter(ImageChops.lighter(ImageChops.lighter(
    ImageChops.lighter(bridge, left_isl), far_cluster), right_isl), arch)
assert ImageChops.subtract(changed, allowed).getbbox() is None
assert diff.crop((0, 0, 640, 130)).getbbox() is None

# 云色、天空梯度、原 V7 云海/碎岩均不得被改。
n_changed = 0
for y in range(360):
    for x in range(640):
        if not changed.getpixel((x, y)):
            continue
        n_changed += 1
        old = base.getpixel((x, y))
        assert old not in CLOUD, (x, y, old)
        assert old != sky(y), (x, y, old)

# 输出主图：先 640 逻辑图，再 NEAREST 2x。
out640 = im.copy()
out640.save(HERE / 'background_detail_v1_640x360.png')
out = im.resize((1280, 720), Image.Resampling.NEAREST)
out.save(HERE / 'background_detail_v1.png')
assert out.resize((640, 360), Image.Resampling.NEAREST).tobytes() == out640.tobytes()

# 技术掩膜：细化像素 + 未来刚性分组。
detail.save(HERE / 'mask_detail_v1.png')
groups = Image.new('RGB', (640, 360), (0, 0, 0))
group_defs = [
    ('G1_left_bridge', bridge_full.crop((0, 0, 320, 360)), (220, 80, 80), 0),
    ('G2_right_bridge', bridge_full.crop((320, 0, 640, 360)), (80, 190, 120), 320),
    ('G3_left_hall_island', left_isl, (90, 140, 220), 0),
    ('G4_left_far_courtyard', far_cluster, (220, 190, 80), 0),
    ('G5_right_floating_island', right_isl, (210, 100, 200), 0),
    ('G6_cloud_arch_foot', arch, (80, 200, 210), 0),
]
group_stats = []
for name, m, col, ox in group_defs:
    px = groups.load()
    for y in range(360):
        for x in range(m.width):
            if m.getpixel((x, y)):
                px[x + ox, y] = col
    bbox = m.getbbox()
    if bbox:
        bbox = (bbox[0] + ox, bbox[1], bbox[2] + ox, bbox[3])
    group_stats.append({'id': name, 'bbox': list(bbox) if bbox else None,
                        'pixels': sum(m.histogram()[1:])})
groups.save(HERE / 'masks_groups_v1.png')

# 自审对比：三处远建筑，左 V7 / 右 V1，4x NEAREST；无文字，仅供读形。
crops = [(28, 160, 112, 204), (232, 160, 322, 204), (436, 138, 540, 204)]
scale = 4
cw = max(b[2] - b[0] for b in crops) * scale
ch = max(b[3] - b[1] for b in crops) * scale
pad = 8
comp = Image.new('RGB', (cw * 2 + pad * 3, ch * len(crops) + pad * (len(crops) + 1)), (18, 24, 28))
for i, box in enumerate(crops):
    w = (box[2] - box[0]) * scale; h = (box[3] - box[1]) * scale
    old = base.crop(box).resize((w, h), Image.Resampling.NEAREST)
    new = im.crop(box).resize((w, h), Image.Resampling.NEAREST)
    y = pad + i * (ch + pad)
    comp.paste(old, (pad, y))
    comp.paste(new, (pad * 2 + cw, y))
comp.save(HERE / 'check_buildings_v7_vs_v1.png')

for p, digest in BEFORE.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest() == digest, str(p)

out_hash = hashlib.sha256((HERE / 'background_detail_v1.png').read_bytes()).hexdigest()
out640_hash = hashlib.sha256((HERE / 'background_detail_v1_640x360.png').read_bytes()).hexdigest()
manifest = {
    'version': 'V1',
    'date': '2026-11-02',
    'canvas': {'logical': [640, 360], 'preview': [1280, 720], 'scale': 'NEAREST 2x'},
    'inputs': {p.name: BEFORE[p] for p in INPUTS},
    'outputs': {
        'background_detail_v1.png': out_hash,
        'background_detail_v1_640x360.png': out640_hash,
        'generate_background_detail_v1.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    },
    'changed_pixels_logical': n_changed,
    'changed_bbox_logical': list(diff.getbbox()),
    'protection': {
        'outside_masks': 0,
        'sky_above_y130_exact': True,
        'cloud_palette_pixels_changed': 0,
        'sky_gradient_pixels_changed': 0,
        'v7_unchanged': True,
    },
    'groups': group_stats,
    'unverified': [
        '未接入 Godot、未做引擎截图或连续试玩',
        '未制作浮动动画、未验证大幅度位移与遮挡补面',
        '未修 DS02 两个动态问题（左右断桥遮挡、右桥下静止白云）',
        '云中残拱仅两足 1px 受光/影，拱冠结构仍按原图读取',
        '桥后/云后不可见建筑面未补绘',
        '右浮岛 G5 与右桥断柱 G2 在画面上相接；独立浮移会断开支撑，需先定组合/遮挡方案',
    ],
}
import json
(HERE / 'manifest_v1.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('changed logical pixels:', n_changed)
print('changed bbox:', diff.getbbox())
print('bridge mask:', sum(bridge.histogram()[1:]))
print('left_isl:', left_isl.getbbox(), 'far_cluster:', far_cluster.getbbox(), 'right_isl:', right_isl.getbbox())
print('arch mask:', sum(arch.histogram()[1:]))
print('group stats:', group_stats)
print('sha256 source v7 :', BEFORE[V7])
print('sha256 output    :', out_hash)
print('sha256 output640 :', out640_hash)
print('V7 / V6 / source_v7.md unchanged.')
