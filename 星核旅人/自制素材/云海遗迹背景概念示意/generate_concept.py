"""审核用静态合成；不写入工程。唯一依赖 Pillow；所有绘制在640×360整数网格。"""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
A = ROOT / '基础场景原型/assets'
W, H = 640, 360
random.seed(17)
im = Image.new('RGB', (W, H))
d = ImageDraw.Draw(im)
# 天光保持冷青，不使用模糊或泛光；顶部深、地平线略亮。
for y in range(H):
    t = min(1, y / 315)
    d.line((0,y,639,y), fill=tuple(round(a+(b-a)*t) for a,b in zip((13,34,43),(53,83,87))))

def poly(p, c):
    d.polygon(p, fill=c)

def band(x,y,w,c):
    poly([(x,y+6),(x+16,y+6),(x+16,y+3),(x+40,y+3),(x+40,y),
          (x+w//2,y),(x+w//2,y+2),(x+w-26,y+2),(x+w-26,y+5),
          (x+w,y+5),(x+w,y+7),(x+w-40,y+7),(x+w-40,y+9),
          (x+24,y+9),(x+24,y+8),(x,y+8)],c)

band(-25,77,210,(31,55,63))
band(43,69,115,(32,56,64))
band(365,45,235,(27,48,57))
band(442,51,155,(29,51,59))
band(205,118,90,(35,62,68))
band(493,106,168,(37,63,69))

# 极远：一座小浮岛、断塔基座；不铺满城市。
far=(51,78,83); far_hi=(62,88,92); far_sh=(44,70,77)
poly([(444,167),(455,164),(464,163),(467,158),(480,157),(487,159),
      (502,159),(506,163),(524,164),(534,170),(525,174),(519,182),
      (510,184),(506,191),(499,186),(489,188),(482,183),(469,180),
      (463,175),(450,174)],far)
poly([(464,171),(478,174),(488,183),(491,179),(501,188),(506,183),
      (517,180),(523,172),(510,176),(493,173)],far_sh)
d.rectangle((477,143,488,158), fill=far)
poly([(475,143),(475,140),(484,140),(484,138),(489,141),(491,143)],far_hi)
d.rectangle((479,146,481,155), fill=far_hi)
d.rectangle((500,151,504,161), fill=far)
d.rectangle((498,150,506,152), fill=far_hi)
d.line((455,165,478,162,500,163,520,166), fill=far_hi)

# 中景建筑独立绘制：倾斜断桥、厚拱券、桥墩与残缺庭院柱列。
arch = Image.new('RGBA',(W,H))
ad = ImageDraw.Draw(arch)
stone=(56,80,86,255); shade=(44,68,76,255); light=(68,92,97,255)
def ap(p,c=stone): ad.polygon(p,fill=c)
def rect(box,c=stone): ad.rectangle(box,fill=c)

# 左侧古桥厚桥板；破口错层，不能读成横贯屏幕的行走路线。
ap([(25,203),(67,199),(112,200),(151,198),(192,201),(233,205),
    (267,210),(276,214),(285,213),(282,219),(292,221),(281,226),
    (264,224),(256,221),(217,218),(178,214),(133,213),(89,214),(47,216),(25,217)])
ad.line([(25,203),(67,199),(112,200),(151,198),(192,201),(233,205),(267,210)],fill=light,width=2)
ad.line([(26,215),(84,212),(140,211),(195,213),(258,220)],fill=shade,width=2)
# 桥墩主体，拱洞挖空，厚拱弧再以石块分缝。
ap([(42,213),(258,219),(251,303),(240,321),(226,313),(218,262),
    (204,252),(183,251),(169,267),(163,325),(148,334),(130,319),
    (127,266),(116,250),(94,248),(77,262),(72,306),(53,309)],stone)
for cx,cy,rx,ry,bottom in [(102,263,25,31,340),(222,267,24,31,343)]:
    # 拱洞的尖端以上半椭圆绘制，底部开放至云层。
    points=[(cx-rx,bottom),(cx-rx,cy)]
    points += [(round(cx+rx*math.cos(t)),round(cy+ry*math.sin(t))) for t in [math.pi+i*math.pi/24 for i in range(25)]]
    points += [(cx+rx,bottom)]
    ad.polygon(points,fill=(0,0,0,0))
    arcpts=[(round(cx+(rx+5)*math.cos(t)),round(cy+(ry+5)*math.sin(t))) for t in [math.pi+i*math.pi/35 for i in range(36)]]
    ad.line(arcpts,fill=light,width=3)
    for deg in (202,226,252,276,302,326,345):
        t=math.radians(deg)
        ad.line((round(cx+(rx+1)*math.cos(t)),round(cy+(ry+1)*math.sin(t)),
                 round(cx+(rx+8)*math.cos(t)),round(cy+(ry+8)*math.sin(t))),fill=shade)
for x,y in [(54,239),(138,238),(145,271),(230,252),(61,284)]:
    ad.line((x,y,x+14,y),fill=shade)
    ad.line((x+7,y,x+7,y+7),fill=shade)
ap([(252,222),(259,223),(257,241),(251,237)],light)
ap([(276,232),(282,233),(280,238),(277,237)],stone)

# 非前景柱贴图放大：背景柱按透视尺度新绘，有柱头/槽/断面，但低对比。
def column(x,foot,height,broken=False):
    top=foot-height
    rect((x-7,foot-4,x+8,foot),stone)
    rect((x-6,foot-5,x+6,foot-4),light)
    rect((x-4,top+6,x+4,foot-5),stone)
    ad.line((x-3,top+7,x-3,foot-7),fill=light)
    ad.line((x+2,top+8,x+2,foot-7),fill=shade)
    ad.line((x,top+10,x,foot-10),fill=(62,85,91,255))
    if not broken:
        ap([(x-7,top),(x+8,top),(x+8,top+3),(x+5,top+5),(x-4,top+5),(x-7,top+3)],light)
        rect((x-6,top+4,x+6,top+6),stone)
    else:
        ap([(x-4,top+6),(x-4,top+1),(x-2,top+3),(x+1,top),(x+4,top+4),(x+4,top+7)],light)

column(148,198,49)
column(188,201,55)
column(228,206,36,True)
ap([(137,144),(157,143),(174,144),(197,143),(197,148),(190,151),
    (167,150),(151,151),(139,150)],stone)
ad.line((138,144,159,144,175,145,195,144),fill=light)
ad.line((147,153,147,159),fill=shade)
ap([(205,150),(213,151),(214,155),(209,154)],stone)

# 右边只留一截坍塌桥头和桥墩，不组成第二条完整道路。
ap([(431,231),(442,227),(452,228),(452,225),(472,224),(502,226),
    (545,230),(558,234),(557,244),(523,240),(483,237),(455,238),
    (447,236),(438,239),(439,235)],stone)
ad.line((451,226,472,224,502,226,545,230),fill=light,width=2)
ap([(466,237),(490,239),(487,310),(477,327),(465,313)],stone)
ap([(517,241),(539,243),(543,324),(520,331)],shade)
ad.line((468,242,466,300),fill=light)
ad.line((477,259,486,259,484,268),fill=shade)
column(509,226,38,True)
column(546,231,52)
rect((536,177,558,180),light)
ap([(554,180),(567,181),(572,184),(570,187),(554,185)],stone)
# 石材稀疏、定向小细节；按alpha裁切，不撒满噪点。
mask=arch.getchannel('A')
for _ in range(160):
    x=random.randrange(35,560); y=random.randrange(148,300)
    if mask.getpixel((x,y)) and mask.getpixel((x+3,y)):
        ad.line((x,y,x+random.choice([1,2,3]),y), fill=random.choice([light,shade]))
im.paste(arch,(0,0),arch)
d=ImageDraw.Draw(im)

# 云海：宽阔错层的整数像素轮廓，遮住桥墩底部但永不覆盖前景。
# 控制点之间用离散余弦过渡，避免直角巨台阶或等距小波浪。
def sea(points,col):
    pts=[]
    for (x0,y0),(x1,y1) in zip(points,points[1:]):
        for x in range(x0,x1,2):
            t=(x-x0)/max(1,x1-x0)
            y=round((y0+(y1-y0)*(1-math.cos(t*math.pi))/2)/2)*2
            if pts:
                pts.append((x,pts[-1][1]))
            pts.append((x,y))
    pts.append(points[-1])
    poly(pts+[(640,360),(0,360)],col)
sea([(0,281),(33,274),(68,275),(103,263),(132,264),(179,276),
     (236,282),(279,276),(323,264),(363,260),(393,264),(425,267),
     (479,280),(522,281),(573,269),(603,270),(640,277)],(61,86,91))
sea([(0,308),(55,301),(93,294),(130,299),(171,300),(219,312),
     (253,315),(291,308),(324,305),(360,310),(394,316),(435,313),
     (478,304),(513,299),(552,296),(596,303),(640,301)],(73,98,101))
band(226,290,188,(68,94,97))
band(297,296,93,(72,98,100))
sea([(0,341),(45,337),(90,329),(128,333),(172,340),(213,347),
     (248,344),(286,339),(330,331),(370,329),(405,337),(445,340),
     (480,345),(518,338),(567,333),(608,336),(640,341)],(87,110,112))
band(318,323,107,(79,103,105))
background=im.copy()
background.resize((1280,720),Image.Resampling.NEAREST).save(HERE/'background_only.png')

# 真实关卡切片 world_x1000..1640。贴图不改色、不缩放、不重绘。
im=im.convert('RGBA')
atlas=Image.open(A/'map/ruin_platform_tiles.png').convert('RGBA')
def terrain(wx,wy,width):
    for row in range((360-wy+15)//16):
        for c in range(width//16):
            if row==0:
                ac=0 if c==0 else 11 if c==width//16-1 else 1+(c-1)%10
            else:
                ac=0 if c==0 else 11 if c==width//16-1 else 1+(c+row*3)%10
            tile=atlas.crop((ac*16,(0 if row==0 else 1)*16,ac*16+16,(1 if row==0 else 2)*16))
            im.alpha_composite(tile,(wx-1000+c*16,wy+row*16))
terrain(864,220,336)
terrain(1456,300,496)
def anchor_asset(path,x,y,anchor):
    sprite=Image.open(path).convert('RGBA')
    im.alpha_composite(sprite,(x-anchor[0],y-anchor[1]))
cols=ROOT/'自制素材/庭院石柱'
anchor_asset(cols/'doric_column_tall.png',600,300,(26,108))
anchor_asset(cols/'doric_column_broken.png',650,300,(26,82))
anchor_asset(cols/'doric_column_fallen.png',682,300,(28,25))
sheet=Image.open(A/'characters/male_hero-idle.png').convert('RGBA')
hero=sheet.crop((0,0,sheet.width//10,sheet.height))
im.alpha_composite(hero,(110-59,220-79))
anchor_asset(A/'talisman/talisman_gold.png',113,202,(0,0))
anchor_asset(A/'rune_stone/rune_stone_gold.png',360,150,(16,16))

# 审核标注也在逻辑画面绘制；唯一使用项目OFL中文字体。
d=ImageDraw.Draw(im)
font=ImageFont.truetype(str(A/'fonts/tutorial_zh.ttf'),10)
d.text((10,9),'背景概念示意·非实机',font=font,fill=(172,193,194))
d.text((10,24),'云海上的废弃庭院 / 破碎遗迹',font=font,fill=(109,141,147))
im.convert('RGB').resize((1280,720),Image.Resampling.NEAREST).save(HERE/'concept.png')
print('Saved concept.png and background_only.png; 640x360 -> NEAREST 1280x720')
print('Hero source/frame/bbox:',sheet.size,hero.size,hero.getbbox())
