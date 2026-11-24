"""V2 审核示意；安全读取 V1 源码文本后变换，不 import / 执行原生成器。

复用 V1 的轮廓、云海控制点及完整前景合成规则，仅生成两个 *_v2.png。
依赖 Pillow 与同目录 V1 源文件；不修改工程、V1 或原始贴图。
"""
from pathlib import Path
import hashlib

HERE = Path(__file__).resolve().parent
originals = [HERE / n for n in ('concept.png', 'background_only.png', 'generate_concept.py')]
before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in originals}
source = (HERE / 'generate_concept.py').read_text(encoding='utf-8')

def replace(old, new):
    global source
    if old not in source:
        raise RuntimeError('V1 source differs; refusing unsafe generation: ' + old[:70])
    source = source.replace(old, new)

# 显著提升为冷青白昼，不加太阳、光束或泛光。
replace('(13,34,43),(53,83,87)', '(45,90,112),(120,165,174)')
for old, new in {
    '(31,55,63)': '(82,126,145)',
    '(32,56,64)': '(91,136,151)',
    '(27,48,57)': '(70,114,135)',
    '(29,51,59)': '(78,122,141)',
    '(35,62,68)': '(102,147,160)',
    '(37,63,69)': '(105,149,162)',
    'far=(51,78,83); far_hi=(62,88,92); far_sh=(44,70,77)':
        'far=(104,144,157); far_hi=(124,161,170); far_sh=(94,135,150)',
    'stone=(56,80,86,255); shade=(44,68,76,255); light=(68,92,97,255)':
        'stone=(90,125,139,255); shade=(78,111,126,255); light=(113,146,156,255)',
    '(62,85,91,255)': '(102,136,148,255)',
    '(61,86,91)': '(133,173,181)',
    '(73,98,101)': '(148,186,191)',
    '(68,94,97)': '(142,181,187)',
    '(72,98,100)': '(151,189,193)',
    '(87,110,112)': '(164,198,201)',
    '(79,103,105)': '(157,192,197)',
}.items():
    replace(old, new)

# 远岛细节保持少量、大面转折，不与中景争夺注意力。
replace('# 中景建筑独立绘制', '''# V2：远岛岩层受光/背光、断塔石缝与断面。
poly([(451,167),(465,164),(480,162),(497,164),(515,165),(524,168),
      (505,168),(490,166),(475,167),(464,170)],far_hi)
poly([(465,173),(477,175),(482,183),(473,179)],(100,140,153))
poly([(489,174),(499,177),(506,173),(502,185),(497,181)],far_sh)
d.line((480,174,484,178,485,181),fill=far_hi)
d.line((509,170,515,171,512,177),fill=far_hi)
d.rectangle((483,145,487,157),fill=far_sh)
d.line((478,148,486,148),fill=(109,149,160))
d.line((482,149,482,152),fill=far_sh)
d.line((478,154,486,154),fill=(111,150,161))
poly([(475,141),(484,140),(486,142),(478,143)],(132,167,175))
d.line((500,155,503,155),fill=far_sh)

# 中景建筑独立绘制''')

# 替换原来的随机短线为明确的构造细节，全部以原建筑 alpha 裁切。
start = source.index('# 石材稀疏、定向小细节')
end = source.index('im.paste(arch,(0,0),arch)', start)
source = source[:start] + '''# V2：构造驱动的低对比细节；不用随机纹理。
detail=Image.new('RGBA',(W,H))
dd=ImageDraw.Draw(detail)
joint=(82,116,131,255)
edge=(121,152,161,255)
mid=(99,133,146,255)

# 原拱洞与外轮廓不变：拱券内外厚度、楔形券石、内圈背光。
for cx,cy,rx,ry in [(102,263,25,31),(222,267,24,31)]:
    for k in range(11):
        a=math.pi+k*math.pi/11+0.015
        b=math.pi+(k+1)*math.pi/11-0.015
        points=[]
        for rxx,ryy,ts in [(rx+8,ry+8,[a,b]),(rx+1,ry+1,[b,a])]:
            points.extend((round(cx+rxx*math.cos(t)),round(cy+ryy*math.sin(t))) for t in ts)
        dd.polygon(points,fill=[mid,light,mid,edge,light,mid,light,mid,light,mid,light][k])
        dd.line((round(cx+(rx+1)*math.cos(a)),round(cy+(ry+1)*math.sin(a)),
                 round(cx+(rx+9)*math.cos(a)),round(cy+(ry+9)*math.sin(a))),fill=joint)
    arc=[(round(cx+(rx+1)*math.cos(math.pi+i*math.pi/40)),
          round(cy+(ry+1)*math.sin(math.pi+i*math.pi/40))) for i in range(41)]
    dd.line(arc,fill=shade,width=2)
    dd.line((cx-rx-3,cy,cx-rx-3,cy+24),fill=light,width=2)
    dd.line((cx+rx+2,cy,cx+rx+2,cy+21),fill=shade,width=2)
    for y in (cy+5,cy+16):
        dd.line((cx-rx-8,y,cx-rx-1,y),fill=joint)
        dd.line((cx+rx+1,y,cx+rx+8,y),fill=joint)

# 桥板檐口分层、砌石错缝；只在实体墙面布置。
dd.line([(28,206),(67,202),(112,203),(151,201),(192,204),(233,208),(268,213)],fill=mid)
for x,y in [(45,204),(76,202),(108,203),(139,201),(173,203),(209,206),(242,210)]:
    dd.line((x,y,x+1,y+7),fill=joint)
for x0,x1,y in [(48,76,226),(55,70,241),(58,72,256),
                 (128,172,223),(139,162,238),(135,165,253),
                 (139,164,277),(142,162,291),(241,254,239),
                 (245,253,253),(247,252,269)]:
    dd.line((x0,y,x1,y),fill=joint)
    dd.line((x0+2,y-1,x1-3,y-1),fill=mid)
    mx=(x0+x1)//2
    dd.line((mx,y,mx,y+7),fill=joint)
# 零星裂缝沿断裂受力方向延伸，而不是散点噪声。
for pts in [[(255,222),(251,228),(254,231),(250,237)],
            [(150,220),(153,224),(151,228)],
            [(57,248),(60,251),(59,256)],
            [(482,241),(479,246),(481,251)],
            [(529,245),(531,251),(528,255)]]:
    dd.line(pts,fill=joint)
# 左桥末端与右侧桥头的断面和石材横截面。
dd.polygon([(267,214),(276,216),(281,215),(278,219),(286,222),(280,223),(264,220)],fill=mid)
dd.line((271,216,274,219,279,220),fill=light)
dd.polygon([(438,232),(447,229),(451,231),(446,234),(440,236)],fill=mid)
dd.line([(454,230),(475,228),(502,230),(542,234),(554,237)],fill=mid)
for x,y in [(464,228),(486,229),(509,231),(535,233)]:
    dd.line((x,y,x,y+7),fill=joint)
for x0,x1,y in [(468,487,249),(468,486,267),(467,485,285),
                 (520,538,254),(521,539,271),(522,540,288)]:
    dd.line((x0,y,x1,y),fill=joint)
    dd.line((x0+7,y,x0+7,y+8),fill=joint)
dd.polygon([(467,241),(471,242),(470,300),(467,308),(465,305)],fill=mid)
dd.line((519,245,521,303),fill=mid)

# 柱头上承板/颈环、柱身明暗面、水平石缝和残柱断口。
for x,foot,height,broken in [(148,198,49,False),(188,201,55,False),
                            (228,206,36,True),(509,226,38,True),(546,231,52,False)]:
    top=foot-height
    dd.line((x-2,top+8,x-2,foot-8),fill=light)
    dd.line((x+3,top+8,x+3,foot-7),fill=shade)
    dd.line((x-4,top+8,x+4,top+8),fill=joint)
    dd.line((x-4,top+7,x+4,top+7),fill=light)
    dd.line((x-3,top+height//2,x+3,top+height//2),fill=joint)
    dd.line((x-6,foot-3,x+6,foot-3),fill=joint)
    dd.line((x-6,foot-1,x+7,foot-1),fill=mid)
    if broken:
        dd.polygon([(x-3,top+3),(x-1,top+4),(x+1,top+2),(x+3,top+5),(x+2,top+6),(x-3,top+5)],fill=edge)
        dd.line((x+1,top+7,x,top+12,x+1,top+15),fill=joint)
    else:
        dd.line((x-6,top+1,x+7,top+1),fill=edge)
        dd.line((x-5,top+4,x+5,top+4),fill=joint)
        dd.line((x-5,top+5,x+5,top+5),fill=mid)
# 残梁分块与底面阴影。
dd.line((140,147,157,146,174,147,193,146),fill=mid)
for x in (151,169,186):
    dd.line((x,144,x,149),fill=joint)
dd.line((539,179,555,179),fill=joint)
from PIL import ImageChops
detail.putalpha(ImageChops.multiply(detail.getchannel('A'),arch.getchannel('A')))
arch.alpha_composite(detail)
''' + source[end:]

replace("HERE/'background_only.png'", "HERE/'background_only_v2.png'")
replace("HERE/'concept.png'", "HERE/'concept_v2.png'")
replace("'背景概念示意·非实机'", "'背景概念 V2 · 非实机'")
replace('fill=(172,193,194)', 'fill=(191,216,222)')
replace('fill=(109,141,147)', 'fill=(157,191,201)')
replace("print('Saved concept.png and background_only.png; 640x360 -> NEAREST 1280x720')",
        "print('Saved concept_v2.png and background_only_v2.png; 640x360 -> NEAREST 1280x720')")
assert "save(HERE/'concept.png')" not in source
assert "save(HERE/'background_only.png')" not in source
exec(compile(source, str(HERE / 'generate_concept_v2.py'), 'exec'),
     {'__file__': str(HERE / 'generate_concept_v2.py'), '__name__': '__main__'})
for p in originals:
    assert hashlib.sha256(p.read_bytes()).hexdigest() == before[p], 'V1 changed: ' + str(p)
print('Verified: all three V1 files unchanged (SHA-256).')
