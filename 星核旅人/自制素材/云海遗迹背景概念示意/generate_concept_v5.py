"""V5 局部石面重映射；只读取旧 PNG，不执行/import 旧生成器。"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TEMP = Path(r'C:\Users\aqiqiqi\AppData\Local\Temp\opencode')
OUTPUTS = {'concept_v5.png', 'background_only_v5.png', 'generate_concept_v5.py',
           'source_v5.md', 'midground_mask_v5.png'}
hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest()
          for p in HERE.iterdir() if p.is_file() and p.name not in OUTPUTS}
old_bg = Image.open(HERE/'background_only_v4.png').convert('RGB')
old_main = Image.open(HERE/'concept_v4.png').convert('RGB')
base = old_bg.resize((640,360), Image.Resampling.NEAREST)
main = old_main.resize((640,360), Image.Resampling.NEAREST)
bg = base.copy()
mask = Image.new('L', base.size)

# 先用明确空间/形体掩膜选中桥板、厚拱、墩及柱列，后按石面身份裁切。
# 不用青色阈值选全图；天空、远院落、浮岛的颜色均不参与此映射。
architecture = Image.new('L', base.size)
d = ImageDraw.Draw(architecture)
d.polygon([(25,202),(67,198),(112,199),(151,197),(192,200),(233,204),
           (268,209),(277,213),(286,212),(283,219),(293,221),(281,227),
           (264,225),(256,222),(217,219),(178,215),(133,214),(89,215),
           (47,217),(25,218)], fill=255)
d.polygon([(42,213),(258,219),(251,303),(240,321),(226,313),(218,262),
           (204,252),(183,251),(169,267),(163,325),(148,334),(130,319),
           (127,266),(116,250),(94,248),(77,262),(72,306),(53,309)], fill=255)
for cx,cy,rx,ry in [(102,263,25,31),(222,267,24,31)]:
    pts=[(round(cx+(rx+4)*math.cos(math.pi+i*math.pi/60)),
          round(cy+(ry+4)*math.sin(math.pi+i*math.pi/60))) for i in range(61)]
    d.line(pts, fill=255, width=13)
    d.rectangle((cx-rx-9,cy,cx-rx,cy+25),fill=255)
    d.rectangle((cx+rx,cy,cx+rx+9,cy+22),fill=255)
for box in [(137,143,197,151),(205,150,214,155),
            (140,149,156,198),(180,146,196,201),(220,170,236,206),
            (252,222,259,241),(276,232,282,238),
            (501,188,517,226),(538,179,554,231),(536,177,558,180)]:
    d.rectangle(box,fill=255)
d.polygon([(554,180),(567,181),(572,184),(570,187),(554,185)],fill=255)
d.polygon([(431,231),(442,227),(452,228),(452,225),(472,223),(502,225),
           (545,229),(558,234),(557,244),(523,240),(483,237),(455,238),
           (447,236),(438,239),(439,235)],fill=255)
d.polygon([(466,237),(490,239),(487,310),(477,327),(465,313)],fill=255)
d.polygon([(517,241),(539,243),(543,324),(520,331)],fill=255)
stone_map = {
    (90,125,139):(67,94,116),       # 大面：脱离浅青雾色的冷石灰
    (78,111,126):(48,74,97),       # 背光/拱洞内缘，非黑描边
    (113,146,156):(101,128,145),   # 受光面相对保亮，扩大面差
    (102,136,148):(85,113,133),
    (82,116,131):(55,82,104),      # 既有砌缝
    (121,152,161):(112,139,153),   # 既有柱头及券石受光
    (99,133,146):(82,110,132),
}

def remap(shape, palette, strength=None):
    for y in range(130,360):
        for x in range(640):
            if not shape.getpixel((x,y)) or (330 <= x <= 390 and 130 <= y <= 175):
                continue
            old = base.getpixel((x,y))
            if old not in palette:
                continue
            t = strength(x,y) if strength else 1.0
            new = tuple(round(a+(b-a)*t) for a,b in zip(old,palette[old]))
            bg.putpixel((x,y),new)
            if new != old:
                mask.putpixel((x,y),round(255*t))

remap(architecture,stone_map)

# 各碎岩单独几何选取；保持偏斜断口及原轮廓，不形成新落脚边。
rocks = Image.new('L',base.size)
rd = ImageDraw.Draw(rocks)
for pts in [
    [(303,218),(307,208),(312,207),(315,211),(322,211),(322,214),
     (326,215),(331,219),(341,223),(334,229),(330,239),(324,245),
     (319,239),(310,236),(307,226)],
    [(264,247),(270,243),(282,245),(287,249),(281,253),(277,261),(270,257),(269,251)],
    [(287,259),(291,257),(294,260),(291,264),(289,263)],
    [(379,239),(383,235),(387,238),(385,245),(381,243)],
    [(204,177),(210,175),(221,179),(221,184),(217,188),(209,184)],
    [(397,195),(404,191),(415,194),(422,198),(417,202),(413,209),(408,212),(406,204),(401,204)],
]:
    rd.polygon(pts,fill=255)
remap(rocks,{
    (95,134,146):(70,100,121),(83,123,137):(51,79,102),
    (105,143,153):(98,126,143),
    (103,142,153):(87,119,138),(96,135,148):(72,105,127),
    (109,147,157):(104,134,150),
})

# 云中冠部另设形体选区，向下减弱；薄云颜色不映射，下半继续遮蔽。
cloud_shapes = Image.new('L',base.size)
cd = ImageDraw.Draw(cloud_shapes)
for pts in [
    [(231,319),(236,306),(241,302),(245,289),(250,293),(252,304),(260,314),(263,324),(246,331)],
    [(278,299),(281,284),(287,277),(296,273),(305,274),(313,279),(316,286),
     (322,288),(326,300),(318,304),(309,283),(302,280),(294,280),(288,286),(287,299)],
    [(392,293),(397,279),(405,274),(415,276),(419,284),(431,287),(440,304),(429,313),(402,308)],
    [(347,289),(353,285),(358,288),(356,295),(351,298)],
]:
    cd.polygon(pts,fill=255)
def cloud_strength(x,y):
    top,bottom = (289,324) if x < 270 else (273,302)
    return max(0.0, min(0.85, 0.85*(bottom-y)/(bottom-top-7)))
remap(cloud_shapes,{
    (116,153,162):(86,118,139),(129,166,172):(118,148,161),
    (108,146,157):(65,98,122),(118,154,163):(94,125,143),
}, cloud_strength)

# 扁平主图和背景的原始差异逐像素保护，避免重新合成损坏半透明边缘。
fg = ImageChops.difference(base,main)
fg_mask = Image.new('L',base.size)
fg_mask.putdata([255 if p != (0,0,0) else 0 for p in fg.getdata()])
protected=fg_mask.copy()
pd=ImageDraw.Draw(protected)
pd.rectangle((0,0,639,129),fill=255)
pd.rectangle((330,130,390,175),fill=255)
main.paste(bg,(0,0),ImageChops.invert(protected))
title=(10,9,140,22)
main.paste(base.crop(title),title[:2])
font=ImageFont.truetype(str(ROOT/'基础场景原型/assets/fonts/tutorial_zh.ttf'),10)
ImageDraw.Draw(main).text((10,9),'背景概念 V5 · 非实机',font=font,fill=(191,216,222))
new_bg=bg.resize((1280,720),Image.Resampling.NEAREST)
new_main=main.resize((1280,720),Image.Resampling.NEAREST)
new_bg.save(HERE/'background_only_v5.png')
new_main.save(HERE/'concept_v5.png')
mask.resize((1280,720),Image.Resampling.NEAREST).save(HERE/'midground_mask_v5.png')
new_main.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_concept_v5_check_720.png')
old_main.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_concept_v4_compare_720.png')

title_mask=Image.new('L',(640,360))
ImageDraw.Draw(title_mask).rectangle((10,9,139,21),fill=255)
title_mask=title_mask.resize((1280,720),Image.Resampling.NEAREST)
for label,old,new in [('background',old_bg,new_bg),('main',old_main,new_main)]:
    diff=ImageChops.difference(old,new)
    allowed=ImageChops.multiply(diff,ImageChops.invert(title_mask).convert('RGB'))
    assert allowed.crop((0,0,1280,260)).getbbox() is None
    assert diff.crop((660,260,782,352)).getbbox() is None
    assert diff.crop((0,672,1280,720)).getbbox() is None
    print(label,'changed bbox',diff.getbbox())
fg_check=fg_mask.copy()
ImageDraw.Draw(fg_check).rectangle((10,9,139,21),fill=0)
assert ImageChops.multiply(ImageChops.difference(old_main,new_main),
    fg_check.resize((1280,720),Image.Resampling.NEAREST).convert('RGB')).getbbox() is None
# 所有天空梯度、云海色、远岛与V4远院落色完全一致（背景逐像素）。
far_colors={(104,144,157),(124,161,170),(94,135,150),(100,140,153),
            (109,149,160),(111,150,161),(132,167,175),
            (105,146,158),(99,140,153),(113,152,163)}
cloud_colors={(133,173,181),(148,186,191),(142,181,187),(151,189,193),
              (164,198,201),(157,192,197),(135,174,182),(148,184,190)}
for y in range(360):
    sky=tuple(round(a+(b-a)*min(1,y/315)) for a,b in zip((45,90,112),(120,165,174)))
    for x in range(640):
        p=base.getpixel((x,y))
        if p in far_colors or p in cloud_colors or p==sky:
            assert bg.getpixel((x,y))==p,(x,y,p)
for p,digest in hashes.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,str(p)
print('Protected foreground pixels:',sum(v>0 for v in fg_check.getdata()))
print('Changed logical background pixels:',sum(v>0 for v in mask.getdata()))
print('SHA-256:',len(hashes),'old files unchanged. Sky / far ruins / sea colors exact V4.')
