"""V3 静态概念：仅替换 V2 上空云层。直接读取 PNG，不执行 V1/V2。

依赖：Pillow、同目录两个 V2 PNG、工程既有 tutorial_zh.ttf。
所有云轮廓用整数像素离散控制点；无模糊/喷枪/外部素材。
"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TEMP = Path(r'C:\Users\aqiqiqi\AppData\Local\Temp\opencode')
protected = [p for p in HERE.iterdir() if p.is_file() and not p.name.endswith('_v3.png')
             and p.name not in ('generate_concept_v3.py', 'source_v3.md')]
hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
old_bg = Image.open(HERE/'background_only_v2.png').convert('RGB')
old_main = Image.open(HERE/'concept_v2.png').convert('RGB')
assert old_bg.size == old_main.size == (1280, 720)
bg = old_bg.resize((640,360), Image.Resampling.NEAREST)
main = old_main.resize((640,360), Image.Resampling.NEAREST)
sky = Image.new('RGB', (640,360))
sd = ImageDraw.Draw(sky)
for y in range(360):
    sd.line((0,y,639,y), fill=tuple(round(a+(b-a)*min(1,y/315))
                                  for a,b in zip((45,90,112),(120,165,174))))

# 仅以 V1 的六条旧云轮廓建立移除掩膜；不重建/执行旧生成器。
removed = Image.new('1',(640,360))
rd = ImageDraw.Draw(removed)
for x,y,w in [(-25,77,210),(43,69,115),(365,45,235),(442,51,155),
              (205,118,90),(493,106,168)]:
    rd.polygon([(x,y+6),(x+16,y+6),(x+16,y+3),(x+40,y+3),(x+40,y),
                (x+w//2,y),(x+w//2,y+2),(x+w-26,y+2),(x+w-26,y+5),
                (x+w,y+5),(x+w,y+7),(x+w-40,y+7),(x+w-40,y+9),
                (x+24,y+9),(x+24,y+8),(x,y+8)], fill=1)
cloud = Image.new('RGB',(640,360))
draw = ImageDraw.Draw(cloud)
added = Image.new('1',(640,360))
md = ImageDraw.Draw(added)

def edge(points):
    """非等距、不等高控制点；一像素台阶，不抗锯齿。"""
    result=[]
    for (x0,y0),(x1,y1) in zip(points,points[1:]):
        for x in range(x0,x1):
            t=(x-x0)/(x1-x0)
            yy=round(y0+(y1-y0)*(1-math.cos(t*math.pi))/2)
            if result and yy != result[-1][1]:
                result.append((x,result[-1][1]))
            result.append((x,yy))
    return result+[points[-1]]

def shape(top,bottom,color):
    pts=edge(top)+list(reversed(edge(bottom)))
    draw.polygon(pts,fill=color)
    md.polygon(pts,fill=1)

# 左侧主云：非对称的大体积与横向舒展薄翼，底部以断续卷层退入天空。
shape([(-12,85),(5,79),(19,80),(34,67),(47,64),(57,66),(75,57),
       (87,56),(103,61),(112,61),(126,70),(142,68),(158,74),
       (183,79),(203,86),(230,88)],
      [(-12,94),(18,96),(43,100),(65,99),(85,104),(110,103),
       (135,98),(158,98),(178,94),(200,93),(230,88)],(90,132,148))
shape([(-7,85),(15,83),(35,71),(48,69),(59,71),(77,62),(88,61),
       (105,67),(114,66),(127,75),(145,74),(162,81),(187,85),(207,89)],
      [(-7,89),(20,91),(42,88),(58,91),(78,86),(98,89),(120,86),
       (143,89),(166,88),(185,91),(207,89)],(105,146,158))
shape([(25,77),(36,69),(47,66),(55,67),(62,67),(77,59),(88,58),(101,63),(110,65)],
      [(25,79),(43,73),(56,75),(75,68),(88,68),(100,70),(110,65)],(118,155,165))
shape([(112,77),(125,72),(137,72),(150,77),(160,79)],
      [(112,79),(126,78),(140,79),(151,81),(160,79)],(114,153,164))
shape([(30,92),(54,89),(72,93),(83,91),(103,93),(128,91),(145,93)],
      [(30,94),(52,95),(72,98),(87,96),(107,99),(127,96),(145,93)],(83,126,144))
shape([(69,83),(77,79),(88,77),(98,81),(105,85),(120,86)],
      [(69,85),(78,85),(90,83),(100,86),(105,88),(120,86)],(96,138,153))

# 右主云：更高、不同尺度，顶缘偏灰青而非白色贴纸；右侧向画外延伸。
shape([(376,65),(395,62),(412,53),(426,54),(439,46),(454,43),
       (468,47),(479,52),(491,51),(507,57),(523,55),(541,61),
       (558,66),(578,64),(592,69),(619,72),(648,76)],
      [(376,65),(397,73),(420,73),(444,80),(467,78),(487,84),
       (509,83),(530,87),(551,84),(576,87),(599,82),(624,83),(648,79)],(82,124,144))
shape([(389,64),(411,58),(423,58),(441,50),(454,47),(465,49),
       (480,58),(493,56),(509,63),(525,61),(542,67),(564,73),(592,73),(619,77)],
      [(389,66),(412,67),(429,65),(450,69),(468,66),(489,72),
       (510,70),(530,75),(548,74),(568,79),(593,78),(619,77)],(99,139,154))
shape([(414,57),(426,56),(441,48),(454,45),(465,48),(477,55)],
      [(414,60),(429,59),(444,55),(455,54),(467,55),(477,55)],(111,149,162))
shape([(480,59),(491,54),(502,57),(509,61),(520,59),(531,63)],
      [(480,61),(491,60),(502,62),(511,65),(523,64),(531,63)],(107,146,160))
shape([(428,72),(447,70),(462,73),(477,72),(490,77),(510,77),(529,81),(551,80)],
      [(428,74),(447,76),(460,78),(481,77),(491,81),(509,81),(529,84),(551,80)],(76,118,139))
shape([(552,72),(571,69),(585,71),(601,76),(629,78),(646,77)],
      [(552,74),(570,75),(586,77),(604,80),(630,81),(646,79)],(94,134,151))

# 中央轻薄联系：不连成一堵云墙，中央下方继续留给金符石。
shape([(251,81),(265,78),(278,79),(289,73),(299,74),(310,79),(326,80),(344,85),(365,87)],
      [(251,82),(268,84),(287,82),(303,85),(323,83),(342,88),(365,87)],(87,129,148))
shape([(275,79),(289,75),(299,76),(311,81),(326,81)],
      [(275,80),(290,79),(303,82),(315,83),(326,81)],(99,140,155))
shape([(329,60),(340,57),(347,58),(352,61),(364,63)],
      [(329,61),(342,62),(353,63),(364,63)],(79,121,141))
shape([(206,107),(218,103),(226,104),(234,108),(253,110)],
      [(206,109),(222,110),(237,112),(253,110)],(101,143,157))
shape([(474,113),(489,109),(502,110),(516,116),(533,115),(549,119),(570,120)],
      [(474,115),(491,117),(509,118),(531,120),(550,122),(570,120)],(109,151,163))
shape([(99,118),(115,114),(130,116),(142,120),(164,123)],
      [(99,119),(117,120),(137,122),(152,124),(164,123)],(100,142,156))

# 只在旧/新云掩膜内替换，未画云的 V2 天空像素不动。
bg.paste(sky,(0,0),removed)
bg.paste(cloud,(0,0),added)
main.paste(sky,(0,0),removed)
main.paste(cloud,(0,0),added)
title = (10,9,140,22)
main.paste(bg.crop(title),title[:2])
font = ImageFont.truetype(str(ROOT/'基础场景原型/assets/fonts/tutorial_zh.ttf'),10)
ImageDraw.Draw(main).text((10,9),'背景概念 V3 · 非实机',font=font,fill=(191,216,222))

new_bg = bg.resize((1280,720),Image.Resampling.NEAREST)
new_main = main.resize((1280,720),Image.Resampling.NEAREST)
new_bg.save(HERE/'background_only_v3.png')
new_main.save(HERE/'concept_v3.png')
new_main.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_concept_v3_check_720.png')

# 逐像素约束：整个 y>=130 不变；新云均在 y43..124，旧云移除最深y127。
allowed = ImageChops.lighter(removed.convert('L'),added.convert('L'))
allowed_main = allowed.copy()
ImageDraw.Draw(allowed_main).rectangle((10,9,139,21),fill=255)
for label,old,new,mask in [('background',old_bg,new_bg,allowed),('main',old_main,new_main,allowed_main)]:
    diff=ImageChops.difference(old,new)
    large_mask=mask.resize((1280,720),Image.Resampling.NEAREST)
    assert ImageChops.multiply(diff,ImageChops.invert(large_mask).convert('RGB')).getbbox() is None
    assert diff.crop((0,260,1280,720)).getbbox() is None
    assert diff.crop((660,260,780,344)).getbbox() is None
    print(label, 'changed bbox:',diff.getbbox(), '; outside mask/y>=130/rune region: exact V2')
assert allowed.getbbox()[1]>=35 and allowed.getbbox()[3]<=130
for p,digest in hashes.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest, 'Protected input changed: '+str(p)
print('Verified SHA-256:',len(hashes),'existing files unchanged. Sky endpoints/rounding identical to V2.')
print('Mask area (logical pixels):',sum(1 for v in allowed.getdata() if v))
