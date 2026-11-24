"""V4 静态概念：只增加中远景遗迹、悬浮碎岩与云中残构。不执行旧生成器。"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TEMP = Path(r'C:\Users\aqiqiqi\AppData\Local\Temp\opencode')
OUTPUTS = {'concept_v4.png', 'background_only_v4.png', 'generate_concept_v4.py', 'source_v4.md'}
hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest()
          for p in HERE.iterdir() if p.is_file() and p.name not in OUTPUTS}
old_bg = Image.open(HERE/'background_only_v3.png').convert('RGB')
old_main = Image.open(HERE/'concept_v3.png').convert('RGB')
bg = old_bg.resize((640,360), Image.Resampling.NEAREST)
main = old_main.resize((640,360), Image.Resampling.NEAREST)
foreground = ImageChops.difference(bg, main).convert('RGB')
fg_mask = Image.new('L', bg.size)
fg_mask.putdata([255 if p != (0,0,0) else 0 for p in foreground.getdata()])
layer = Image.new('RGBA', bg.size)
d = ImageDraw.Draw(layer)

def poly(points, color):
    d.polygon(points, fill=color)

def rect(box, color):
    d.rectangle(box, fill=color)

def line(points, color, width=1):
    d.line(points, fill=color, width=width)

# 极远的两片旧院落：只保留断墙、洞口、体积转折，不形成连续城市天际线。
far = (105,146,158)
far_sh = (99,140,153)
far_hi = (113,152,163)
poly([(232,209),(244,204),(256,205),(267,201),(291,204),(307,209),
      (319,212),(310,217),(279,218),(256,215),(239,215)], far_sh)
poly([(245,203),(245,177),(251,177),(251,174),(258,176),(259,185),
      (268,185),(268,191),(264,192),(264,204)], far)
poly([(245,177),(251,177),(251,174),(258,176),(257,179),(247,180)], far_hi)
rect((248,183,251,199), far_hi)
rect((256,188,259,203), far_sh)
# 厚门洞留出天空，不做满墙。
poly([(270,205),(270,189),(272,184),(276,181),(284,180),(291,184),
      (293,190),(293,208),(288,207),(288,190),(285,186),(280,185),
      (276,188),(275,192),(275,206)], far)
line([(270,189),(272,184),(276,181),(284,180),(289,183)], far_hi)
line([(288,191),(288,205)], far_sh, 2)
poly([(295,208),(297,194),(297,190),(301,191),(302,196),(308,198),
      (308,211)], far)
line([(299,196),(305,198)], far_hi)
line([(242,208),(260,207),(275,210),(299,212)], far_hi)

# 左后方不完整的厅堂残片：不等高立柱和局部坍塌斜墙。
poly([(31,193),(43,188),(61,190),(73,187),(88,191),(100,197),
      (95,201),(62,198),(39,199)], far_sh)
poly([(44,190),(44,171),(48,170),(49,174),(49,190)], far)
rect((42,168,51,170), far_hi)
rect((65,177,69,190), far)
poly([(61,176),(61,173),(70,172),(73,175),(71,178)], far_hi)
poly([(79,192),(79,180),(84,179),(85,183),(91,185),(93,195)], far)
line([(80,181),(84,181)], far_hi)
line([(35,193),(56,194),(72,192),(91,196)], far_hi)

# 右远处的独立断塔薄影，保留它与既有浮岛/桥柱之间的天空。
poly([(560,243),(565,237),(570,236),(571,213),(575,210),(578,213),
      (578,220),(583,221),(583,239),(593,244),(584,247),(569,247)], far)
line([(571,214),(574,214),(574,234)], far_hi)
line([(579,224),(581,225),(581,239)], far_sh)

# 本层只画到原本无云/无建筑的天空像素，原断桥与浮岛仍在前面。
sky_mask = Image.new('L', bg.size)
for y in range(130,360):
    c = tuple(round(a+(b-a)*min(1,y/315))
              for a,b in zip((45,90,112),(120,165,174)))
    for x in range(640):
        if bg.getpixel((x,y)) == c:
            sky_mask.putpixel((x,y),255)
bg.paste(layer, (0,0), ImageChops.multiply(layer.getchannel('A'), sky_mask))

# 中景浮石：斜断面、偏心下垂体积、不连续分布，不画明亮水平落脚边。
layer = Image.new('RGBA', bg.size)
d = ImageDraw.Draw(layer)
rock = (95,134,146)
rsh = (83,123,137)
rhi = (105,143,153)

def rock_piece(points, facets, seams=()):
    poly(points, rock)
    for pts, col in facets:
        poly(pts,col)
    for pts in seams:
        line(pts, rsh)

# 中央较深的悬浮桥基：石砌断面只占一角，底部是未经雕琢的岩芯。
rock_piece([(303,218),(313,213),(326,215),(331,219),(341,223),(334,229),
            (330,239),(324,245),(319,239),(310,236),(307,226)],
           [([(303,218),(313,213),(326,215),(324,220),(313,222)],rhi),
            ([(324,220),(341,223),(334,229),(330,239),(324,245),(322,231)],rsh)],
           [[(308,219),(315,218),(320,220)],[(314,223),(315,228),(320,229)]])
poly([(307,216),(308,208),(312,207),(315,211),(322,211),(322,216),
      (316,216),(313,218)],rock)
line([(309,211),(313,213),(320,213)],rhi)
line([(316,214),(316,217)],rsh)

# 上右偏后的窄碎岩，比主桥基小、也更淡；不接近金符石保护区。
poly([(397,195),(404,191),(415,194),(422,198),(417,202),(413,209),
      (408,212),(406,204),(401,204)], (103,142,153))
poly([(408,198),(422,198),(417,202),(413,209),(408,212)], (96,135,148))
line([(399,195),(404,194),(411,196)], (109,147,157))
# 下左孤立残材偏斜，避免等距踏脚链。
rock_piece([(264,247),(270,243),(282,245),(287,249),(281,253),(277,261),
            (270,257),(269,251)],
           [([(276,247),(287,249),(281,253),(277,261)],rsh),
            ([(264,247),(270,243),(282,245),(278,248)],rhi)])
poly([(287,259),(291,257),(294,260),(291,264),(289,263)],rock)
poly([(379,239),(383,235),(387,238),(385,245),(381,243)],rsh)
# 左中桥柱间的一截坠离梁材；与原柱不连通。
poly([(204,177),(210,175),(221,179),(221,184),(217,188),(209,184)],rock)
poly([(213,179),(221,179),(221,184),(217,188),(215,183)],rsh)
line([(205,177),(210,177),(217,180)],rhi)
bg.paste(layer,(0,0),ImageChops.multiply(layer.getchannel('A'),sky_mask))

# 云海上：宽的塌陷拱冠与倾斜墙腹，不用一排竖直墓碑。
layer = Image.new('RGBA', bg.size)
d = ImageDraw.Draw(layer)
cs = (116,153,162)
ch = (129,166,172)
cd = (108,146,157)
# 左下云间岩峰，跨越两层云；其尖部不平、无可站顶缘。
poly([(231,319),(236,306),(241,302),(245,289),(250,293),(252,304),
      (260,314),(263,324),(246,331)],cs)
poly([(245,289),(250,293),(252,304),(260,314),(263,324),(247,326),
      (244,313)],cd)
line([(241,304),(244,298),(244,310),(238,317)],ch)
# 一座大拱坍塌后仅冠部出云：破口、厚券、内部暗面，底部大幅遮挡。
poly([(278,299),(281,284),(287,277),(296,273),(305,274),(313,279),
      (316,286),(313,287),(309,283),(302,280),(294,280),(288,286),
      (287,299)],cs)
line([(280,291),(283,284),(288,279),(296,276),(304,277),(309,280)],ch,2)
line([(288,288),(292,283),(299,282),(305,284)],cd,2)
line([(289,278),(291,282)],cd)
line([(299,275),(299,280)],cd)
poly([(313,291),(316,286),(322,288),(326,300),(318,304)],cd)
# 右下倾斜巨大桥座：嵌套凹面与旧横向砌缝；大半埋入云海。
poly([(392,293),(397,279),(405,274),(415,276),(419,284),(431,287),
      (440,304),(429,313),(402,308)],cs)
poly([(413,277),(419,284),(431,287),(440,304),(429,313),(419,300)],cd)
poly([(399,281),(405,277),(414,279),(414,282),(406,281),(401,285)],ch)
poly([(402,286),(408,284),(413,287),(416,301),(409,302),(407,292),
      (401,291)],cd)
line([(418,290),(429,294),(432,299)],(118,154,163))
line([(396,296),(402,296)],ch)
# 分离碎片在云后消失，不把每个物件都放在同一基线上。
poly([(347,289),(353,285),(358,288),(356,295),(351,298)],cs)
poly([(352,289),(358,288),(356,295),(351,298)],cd)
poly([(371,311),(375,307),(380,311),(378,318),(373,316)],(128,165,172))

# 局部薄云绕流：只覆盖新增云中物件附近，不重新绘制整片云海。
def veil(top, bottom, color):
    def edge(pts):
        out=[]
        for (x0,y0),(x1,y1) in zip(pts,pts[1:]):
            for x in range(x0,x1):
                t=(x-x0)/(x1-x0)
                y=round(y0+(y1-y0)*(1-math.cos(t*math.pi))/2)
                if out and y != out[-1][1]:
                    out.append((x,out[-1][1]))
                out.append((x,y))
        return out+[pts[-1]]
    poly(edge(top)+list(reversed(edge(bottom))),color)

veil([(269,298),(279,294),(288,295),(294,298),(303,299),(313,296),(330,299)],
     [(269,298),(281,302),(298,303),(316,302),(330,299)],(135,174,182))
veil([(229,324),(238,320),(249,321),(263,319),(272,322)],
     [(229,324),(245,329),(259,327),(272,322)],(148,184,190))
veil([(382,306),(396,301),(406,304),(418,303),(430,299),(449,302)],
     [(382,306),(398,310),(415,311),(435,307),(449,302)],(135,174,182))
veil([(341,298),(349,294),(356,295),(365,297)],
     [(341,298),(351,301),(361,299),(365,297)],(135,174,182))
veil([(365,318),(373,315),(383,317),(390,320)],
     [(365,318),(375,322),(385,322),(390,320)],(148,184,190))
bg.paste(layer,(0,0),layer.getchannel('A'))

# 用 V3 原主图中每一个与纯背景不同的像素保护已有前景/边缘/标注。
# 另保护完整符石留白，以及上部全部像素。禁止通过重新合成资产改变边缘。
protected = fg_mask.copy()
pd = ImageDraw.Draw(protected)
pd.rectangle((0,0,639,129),fill=255)
pd.rectangle((330,130,390,175),fill=255)
main.paste(bg,(0,0),ImageChops.invert(protected))
font = ImageFont.truetype(str(ROOT/'基础场景原型/assets/fonts/tutorial_zh.ttf'),10)
title = (10,9,140,22)
main.paste(bg.crop(title),title[:2])
ImageDraw.Draw(main).text((10,9),'背景概念 V4 · 非实机',font=font,fill=(191,216,222))

new_bg = bg.resize((1280,720),Image.Resampling.NEAREST)
new_main = main.resize((1280,720),Image.Resampling.NEAREST)
new_bg.save(HERE/'background_only_v4.png')
new_main.save(HERE/'concept_v4.png')
new_main.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_concept_v4_check_720.png')

# 逐像素检查。标题仅允许在上述逻辑矩形中更新。
title_mask=Image.new('L',(640,360))
ImageDraw.Draw(title_mask).rectangle((10,9,139,21),fill=255)
title_mask=title_mask.resize((1280,720),Image.Resampling.NEAREST)
for label,old,new in [('background',old_bg,new_bg),('main',old_main,new_main)]:
    diff=ImageChops.difference(old,new)
    top=ImageChops.multiply(diff,ImageChops.invert(title_mask).convert('RGB'))
    assert top.crop((0,0,1280,260)).getbbox() is None
    assert diff.crop((660,260,782,352)).getbbox() is None
    assert diff.crop((0,672,1280,720)).getbbox() is None
    print(label,'changed bbox:',diff.getbbox(),'; y<130 except title / rune / bottom y>=336 exact V3')
fg_check=fg_mask.copy()
ImageDraw.Draw(fg_check).rectangle((10,9,139,21),fill=0)
assert ImageChops.multiply(ImageChops.difference(old_main,new_main),
    fg_check.resize((1280,720),Image.Resampling.NEAREST).convert('RGB')).getbbox() is None
print('All V3 foreground difference-mask pixels exactly preserved:',sum(v>0 for v in fg_check.getdata()))
for p,digest in hashes.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest, str(p)
print('SHA-256:',len(hashes),'old files unchanged; no previous generator imported.')
