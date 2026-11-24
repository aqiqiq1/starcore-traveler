"""纯背景结构重整：只读取 V5 PNG；不执行旧生成器、不生成含人物主图。"""
from pathlib import Path
import hashlib
import math
from PIL import Image, ImageDraw, ImageChops

HERE = Path(__file__).resolve().parent
TEMP = Path(r'C:\Users\aqiqiqi\AppData\Local\Temp\opencode')
OWN = {'background_only_v6.png', 'generate_background_v6.py', 'source_v6.md'}
hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest()
          for p in HERE.iterdir() if p.is_file() and p.name not in OWN}
original = Image.open(HERE/'background_only_v5.png').convert('RGB')
base = original.resize((640,360), Image.Resampling.NEAREST)
im = base.copy()
STONE=(67,94,116); SHADE=(48,74,97); LIGHT=(101,128,145)
MID=(82,110,132); JOINT=(55,82,104); EDGE=(112,139,153)
old_stone={STONE,SHADE,LIGHT,MID,JOINT,EDGE,(85,113,133),
           (90,125,139),(78,111,126),(113,146,156),(102,136,148),
           (82,116,131),(121,152,161),(99,133,146)}
clouds={(133,173,181),(148,186,191),(142,181,187),(151,189,193),
        (164,198,201),(157,192,197),(135,174,182),(148,184,190)}

# 仅移除原桥体色与柱列，不动远院落、漂浮石群及云雾。
# 被旧桥遮住的天空按 V5 原梯度补回；没有全图重绘/调色。
for x0,y0,x1,y1 in [(25,143,292,283),(431,177,572,282)]:
    for y in range(y0,y1+1):
        sky=tuple(round(a+(b-a)*min(1,y/315))
                  for a,b in zip((45,90,112),(120,165,174)))
        for x in range(x0,x1+1):
            if base.getpixel((x,y)) in old_stone:
                im.putpixel((x,y),sky)

layer=Image.new('RGBA',(640,360))
d=ImageDraw.Draw(layer)
def rect(box,c=STONE): d.rectangle(box,fill=c)
def poly(pts,c=STONE): d.polygon(pts,fill=c)
def line(pts,c=JOINT,width=1): d.line(pts,fill=c,width=width)

# 桥面统一 y205，檐口 y208、下沿 y218：完整段始终平行。
# 先造完整桥，再只在面对中部缺口的一端切断。
left=Image.new('L',(640,360)); ld=ImageDraw.Draw(left)
ld.polygon([(25,205),(259,205),(259,207),(270,207),(267,211),
            (280,212),(275,216),(284,219),(269,221),(259,218),
            (260,231),(254,239),(261,246),(254,254),(254,299),
            (46,299),(46,218),(25,218)],fill=255)
right=Image.new('L',(640,360)); rd=ImageDraw.Draw(right)
rd.polygon([(438,210),(448,207),(448,205),(558,205),(558,218),
            (552,218),(552,299),(465,299),(465,218),(447,218),
            (443,220),(443,216),(434,215)],fill=255)
solid=ImageChops.lighter(left,right)

arches=[(106,267,30,34),(230,267,30,34),(510,267,27,34)]
sd=ImageDraw.Draw(solid)
for cx,cy,rx,ry in arches:
    opening=[(cx-rx,359),(cx-rx,cy)]
    opening += [(round(cx+rx*math.cos(math.pi+i*math.pi/80)),
                 round(cy+ry*math.sin(math.pi+i*math.pi/80))) for i in range(81)]
    opening += [(cx+rx,359)]
    sd.polygon(opening,fill=0)
layer.paste(STONE,(0,0,640,360),solid)

# 垂直墩面明暗与水平砌缝；始终以实体遮罩裁切。
detail=Image.new('RGBA',(640,360)); q=ImageDraw.Draw(detail)
for x0,x1 in [(46,68),(144,192),(268,276),(465,482),(538,551)]:
    q.rectangle((x0,220,x0+3,299),fill=MID)
    q.rectangle((x1-4,220,x1,299),fill=SHADE)
    for n,y in enumerate(range(233,300,12)):
        q.line((x0+3,y,x1-2,y),fill=JOINT)
        joint=x0+7+(n%2)*max(2,(x1-x0)//3)
        q.line((joint,y,joint,y+6),fill=JOINT)

# 三个拱洞共用起拱线、矢高、8px厚度；每条券缝都是径向。
for cx,cy,rx,ry in arches:
    for k in range(13):
        a=math.pi+k*math.pi/13
        b=math.pi+(k+1)*math.pi/13
        pts=[]
        for rxx,ryy,angles in [(rx+8,ry+8,[a+(b-a)*i/5 for i in range(6)]),
                              (rx,ry,[b-(b-a)*i/5 for i in range(6)])]:
            pts += [(round(cx+rxx*math.cos(t)),round(cy+ryy*math.sin(t))) for t in angles]
        q.polygon(pts,fill=[MID,LIGHT,MID,LIGHT,EDGE,LIGHT,MID][k%7])
        q.line((round(cx+rx*math.cos(a)),round(cy+ry*math.sin(a)),
                round(cx+(rx+8)*math.cos(a)),round(cy+(ry+8)*math.sin(a))),fill=JOINT)
    arc=[(round(cx+rx*math.cos(math.pi+i*math.pi/80)),
          round(cy+ry*math.sin(math.pi+i*math.pi/80))) for i in range(81)]
    q.line(arc,fill=SHADE,width=1)
    for side in (-1,1):
        xx=cx+side*(rx+4)
        q.rectangle((xx-3,cy,xx+3,299),fill=MID if side<0 else STONE)
        for y in (267,279,291):
            q.line((xx-3,y,xx+3,y),fill=JOINT)

# 桥面、檐口与梁下沿各为严格水平线，竖缝没有坡度。
for x0,x1 in [(25,258),(449,558)]:
    q.line((x0,205,x1,205),fill=LIGHT,width=2)
    q.line((x0,208,x1,208),fill=MID)
    q.line((x0,216,x1,216),fill=SHADE)
    q.line((x0,218,x1,218),fill=MID)
    for x in range(x0+17,x1,32):
        q.line((x,209,x,215),fill=JOINT)
q.polygon([(259,207),(270,207),(267,211),(280,212),(275,216),
           (266,216),(260,213)],fill=MID)
q.line([(256,219),(253,225),(257,229),(254,234)],fill=JOINT)
q.line([(448,208),(442,212),(449,214)],fill=LIGHT)
detail.putalpha(ImageChops.multiply(detail.getchannel('A'),solid))
layer.alpha_composite(detail)
d=ImageDraw.Draw(layer)

def column(x,broken=False):
    # 所有柱脚 y205；完整柱头 y150，恰好承托 y144..150 横梁。
    rect((x-8,201,x+8,204))
    line((x-7,201,x+7,201),LIGHT)
    line((x-6,203,x+6,203),MID)
    top=178 if broken else 150
    rect((x-4,top+5,x+4,200))
    line((x-3,top+6,x-3,199),LIGHT)
    line((x-1,top+6,x-1,198),MID)
    line((x+3,top+6,x+3,199),SHADE)
    line((x-4,190,x+4,190),JOINT)
    if broken:
        poly([(x-4,183),(x-4,179),(x-1,181),(x+1,177),(x+4,180),(x+4,183)],LIGHT)
        line([(x,183),(x-1,187),(x+1,191)],JOINT)
    else:
        rect((x-7,150,x+7,152),LIGHT)
        rect((x-5,153,x+5,155),STONE)
        line((x-5,155,x+5,155),JOINT)

# 左侧两完整柱的共同墩台 x144..192 明确受力；第三柱只剩断口。
for x,broken in [(148,False),(188,False),(228,True),
                 (478,True),(546,False)]:
    column(x,broken)
for x0,x1 in [(137,198),(536,563)]:
    rect((x0,144,x1,150))
    line((x0,144,x1,144),LIGHT)
    line((x0,147,x1,147),MID)
    line((x0,150,x1,150),SHADE)
    for x in range(x0+14,x1,18): line((x,145,x,149),JOINT)
# 右横梁端部断裂，但完整残梁仍水平，不将倾斜扩散到承重段。
poly([(564,144),(568,145),(566,147),(570,149),(564,150)],MID)

im.paste(layer,(0,0),layer)
# V5 云海作为原有遮挡层；墩脚不可盖住它，其他云中遗迹不改。
for y in range(130,360):
    for x in range(640):
        if base.getpixel((x,y)) in clouds:
            im.putpixel((x,y),base.getpixel((x,y)))

assert ImageChops.difference(base,im).crop((0,0,640,130)).getbbox() is None
assert ImageChops.difference(base,im).crop((330,130,391,176)).getbbox() is None
assert ImageChops.difference(base,im).crop((0,336,640,360)).getbbox() is None
out=im.resize((1280,720),Image.Resampling.NEAREST)
out.save(HERE/'background_only_v6.png')
out.resize((720,405),Image.Resampling.NEAREST).save(TEMP/'xinghe_background_v6_check_720.png')
for p,digest in hashes.items():
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest, str(p)
print('V6 background only; protected sky / blank / cloud colors; old files unchanged:',len(hashes))
