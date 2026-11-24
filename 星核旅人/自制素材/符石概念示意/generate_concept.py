"""原创 Pillow 程序绘制；只输出概念示意，不生成游戏资源。"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

OUT = Path(__file__).resolve().parent
S = 96
OUTLINE = [(45,8),(57,9),(64,13),(71,15),(77,22),(81,23),(84,31),
           (84,37),(87,43),(85,52),(85,61),(81,68),(74,74),(72,79),
           (63,83),(53,86),(44,85),(39,87),(29,83),(24,79),(18,76),
           (16,69),(11,63),(12,55),(9,49),(11,39),(12,30),(17,25),
           (20,19),(29,15),(35,11)]
# 分叉交汇网络；不是贴砖网格，也不是贯穿球面的单道裂口。
CRACKS = [
    [(20,19),(25,27),(29,27),(34,33),(46,30),(56,27),(64,28),(71,26),(77,22)],
    [(34,33),(32,38),(29,43),(20,44),(15,47),(9,49)],
    [(56,27),(56,36),(60,41),(63,48),(68,53),(76,50),(85,52)],
    [(29,43),(36,48),(42,53),(53,51),(63,48)],
    [(42,53),(40,61),(35,71),(28,68),(21,71),(18,76)],
    [(68,53),(70,61),(64,70),(56,72),(53,79),(53,86)],
    [(35,71),(39,77),(39,87)],
    [(64,70),(71,73),(74,74)],
]

def poly_mask(points):
    m=Image.new('L',(S,S)); ImageDraw.Draw(m).polygon(points,fill=255); return m

SHELL=poly_mask(OUTLINE)
GAPS=Image.new('L',(S,S)); gd=ImageDraw.Draw(GAPS)
for p in CRACKS:
    # 主缝由 2 px 撑到 3 px，通往外缘的末段收窄；不挪动壳片。
    for a,b in zip(p,p[1:]):
        outer = a in OUTLINE or b in OUTLINE
        gd.line([a,b], fill=255,width=2 if outer else 3)
# 少数交点风化剥落，露芯；大部分外壳仍然闭合。
for p in [[(31,30),(35,30),(37,34),(34,38),(30,39),(29,36)],
          [(59,43),(63,43),(68,49),(67,54),(62,53),(59,49)],
          [(39,50),(44,50),(45,54),(42,59),(39,61),(37,58)],
          [(61,67),(65,66),(69,71),(65,75),(60,74),(59,71)]]:
    gd.polygon(p, fill=255)
GAPS=ImageChops.multiply(GAPS,SHELL)
# 同一几何用于休眠/金/青；外侧两级窄反光不改变实际裂口。
RIM=ImageChops.subtract(GAPS.filter(ImageFilter.MaxFilter(3)),GAPS)
HALO=ImageChops.subtract(GAPS.filter(ImageFilter.MaxFilter(5)),
                         GAPS.filter(ImageFilter.MaxFilter(3)))
LIGHT_POOLS=[(33,34,10),(62,48,11),(41,54,10),(63,71,7),(51,29,7)]

def pool_strength(x,y):
    return max(max(0,1-math.hypot(x-cx,y-cy)/r) for cx,cy,r in LIGHT_POOLS)

def sprite(state):
    im=Image.new('RGBA',(S,S))
    px=im.load()
    # 统一球面受光，使用少量离散石色而非光滑塑料渐变。
    palette=['#444f59','#556470','#6c7e89','#8999a1','#aab6ba','#cad0cb','#dfe0d4']
    colors=[tuple(bytes.fromhex(c[1:])) for c in palette]
    for y in range(S):
        for x in range(S):
            if not SHELL.getpixel((x,y)): continue
            nx=(x-48)/40; ny=(y-47)/40
            nz=math.sqrt(max(0,1-min(1,nx*nx+ny*ny)))
            light=(-nx*.45-ny*.62+nz*.54)
            k=max(0,min(6,int((light+.24)*5.3)))
            px[x,y]=(*colors[k],255)
    # 大块面顺着原球壳转折；无随机噪点。
    facets=[
      ([(20,19),(35,11),(45,8),(57,9),(64,13),(43,15),(29,23)],'#e0e1d5'),
      ([(20,19),(25,27),(29,27),(31,32),(20,35),(13,39),(12,30)],'#bdc8c6'),
      ([(35,35),(46,32),(54,30),(54,36),(59,42),(48,39),(36,41)],'#c5ceca'),
      ([(31,43),(36,41),(48,39),(59,42),(61,46),(52,49),(42,51)],'#acbabd'),
      ([(58,30),(66,31),(72,28),(78,26),(81,32),(75,34),(65,40),(59,38)],'#9caaaf'),
      ([(68,39),(75,34),(83,35),(85,43),(80,47),(71,48),(65,45)],'#84969e'),
      ([(13,51),(21,47),(28,46),(34,50),(38,54),(35,61),(25,58),(14,61)],'#a3b1b4'),
      ([(41,62),(44,56),(55,54),(61,52),(66,55),(67,61),(61,67),(51,67)],'#899da5'),
      ([(42,65),(51,67),(61,67),(56,70),(52,76),(44,81),(40,77),(38,71)],'#70858f'),
      ([(73,55),(78,53),(83,55),(82,62),(78,67),(70,68),(72,61)],'#617580'),
      ([(22,73),(28,71),(33,74),(36,81),(30,81),(25,77)],'#87989d'),
      ([(69,74),(74,76),(70,79),(62,82),(56,83),(56,80),(61,76)],'#536772'),
    ]
    for pts,c in facets:
        layer=Image.new('RGBA',(S,S),c)
        im.paste(layer,(0,0),ImageChops.multiply(poly_mask(pts),SHELL))
    # 石壳厚度：缝隙的下沿暗边、上沿磨白斜面。
    d=ImageDraw.Draw(im)
    for p in CRACKS:
        d.line([(x+1,y+1) for x,y in p], fill='#475861',width=4)
        d.line([(x,y-2) for x,y in p], fill='#b1bdbb',width=1)
    # 内核是封在壳内的暗球面；仅在缝隙口显示，不在壳外另放宝石。
    core=Image.new('RGBA',(S,S))
    cp=core.load()
    base=(244,205,99) if state=='gold' else (95,225,230)
    for y in range(S):
        for x in range(S):
            r=math.sqrt(((x-46)/38)**2+((y-44)/38)**2)
            if state=='sleep':
                c=(24,35,43) if r>.65 else (36,50,58)
                if r<.46: c=(44,58,64)
            else:
                # 内芯亮面在开口深处；一像素厚内壁有方向性遮挡/反射。
                f=.43 if r>.92 else .70 if r>.70 else .90 if r>.42 else 1.0
                pool=pool_strength(x,y)
                c=tuple(int(v*f) for v in base)
                upper=not GAPS.getpixel((x,max(0,y-1)))
                lower=not GAPS.getpixel((x,min(S-1,y+1)))
                left=not GAPS.getpixel((max(0,x-1),y))
                if upper or left:
                    c=tuple(int(v*(.43+.20*pool)) for v in base)
                elif lower:
                    c=tuple(int(v*(.66+.22*pool)) for v in base)
                elif pool>.38:
                    # 局部核心高亮，不沿每条裂纹画等宽亮线。
                    hot=(255,245,205) if state=='gold' else (204,255,251)
                    t=min(.70,(pool-.38)*1.2)
                    c=tuple(round(a*(1-t)+b*t) for a,b in zip(c,hot))
            cp[x,y]=(*c,255)
    im.paste(core,(0,0),GAPS)
    # 亮芯照到裂口内壁及紧邻壳缘，局部 1–2 px，保留大片冷灰石面。
    if state!='sleep':
        reflected=Image.new('RGBA',(S,S)); rp=reflected.load()
        for y in range(S):
            for x in range(S):
                strength=pool_strength(x,y)
                if strength<=.08 or not SHELL.getpixel((x,y)): continue
                # 下侧断面受光更强；上侧仍留冷暗边，避免霓虹包边。
                facing=1.0 if GAPS.getpixel((x,max(0,y-1))) else .45
                alpha=int(148*strength*facing) if RIM.getpixel((x,y)) else (
                    int(35*strength) if HALO.getpixel((x,y)) else 0)
                rp[x,y]=(*base,alpha)
        im.alpha_composite(reflected)
    # 裂纹走到外缘的阴影不得生出轮廓外飞片。
    im.putalpha(SHELL)
    # 少量面内自然缺角/磨损，避开符文、正负号和人为雕花。
    d=ImageDraw.Draw(im)
    for pts,c in [([(28,20),(32,18),(34,18),(34,20),(29,22)],'#b7c1bd'),
                  ([(44,21),(50,20),(53,21),(49,23),(44,23)],'#c9d1cb'),
                  ([(19,54),(21,54),(22,57),(19,57)],'#bfcbc7'),
                  ([(48,61),(52,60),(54,61),(51,63),(48,63)],'#a1b1b5'),
                  ([(28,76),(30,76),(31,79),(28,78)],'#a4b2b2')]:
        d.polygon(pts,fill=c)
    return im

def font(n,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc' if bold else 'C:/Windows/Fonts/msyh.ttc',n)

def build():
    W,H=1600,1000
    page=Image.new('RGB',(W,H),'#141d24'); d=ImageDraw.Draw(page)
    fg='#e5e8e2'; secondary='#a9bbc1'; dim='#70878f'
    d.text((64,36),'星核 · 风化封壳',font=font(42,True),fill=fg)
    d.text((66,103),'概念示意，非最终游戏像素资源',font=font(25),fill='#e8cd8d')
    d.line((64,153,1536,153),fill='#34434c',width=2)
    # 放大轮廓优先，不使用额外底座、光环或装饰。
    main=sprite('gold').resize((672,672),Image.Resampling.NEAREST)
    page.paste(main,(60,177),main)
    d.text((100,863),'主体放大 · 激活金态 / 裂口溢光',font=font(26,True),fill=fg)
    d.text((100,906),'主缝适度撑宽，交汇露芯；保留内壁与石壳主体。',font=font(20),fill=secondary)
    d.line((778,190,778,932),fill='#34434c',width=2)
    d.text((826,200),'同一设计 · 三态对照',font=font(30,True),fill=fg)
    d.text((826,251),'三态共用加宽裂口，只改变内芯与反光。',font=font(22),fill=secondary)
    specs=[('sleep','休眠','#93a9b3','无光 · 暗芯'),
           ('gold','链接 · 金','#f4cd63','#F4CD63'),
           ('cyan','链接 · 青','#5fe1e6','#5FE1E6')]
    for i,(s,label,c,sub) in enumerate(specs):
        x=826+i*240
        d.rounded_rectangle((x,319,x+218,617),radius=10,fill='#1d2932')
        sp=sprite(s).resize((192,192),Image.Resampling.NEAREST)
        page.paste(sp,(x+13,347),sp)
        d.text((x+14,551),label,font=font(24,True),fill=c)
        d.text((x+14,587),sub,font=font(17),fill=secondary)
    d.text((826,681),'形态确认重点',font=font(25,True),fill=fg)
    lines=['灰白 / 灰蓝石面，保留弧面与壳层厚度。',
           '大小不等的壳片仍拼合，不向外散开。',
           '裂缝分叉交汇，不是单道闪电或整齐砖格。',
           '星核封在内部，不增加符号、金属环或底座。']
    for i,t in enumerate(lines):
        d.text((826,730+i*38),t,font=font(21),fill=secondary)
    d.text((826,919),'96 px 概念画布整数放大 · 不承诺 32 px 落地细节',font=font(17),fill=dim)
    page.save(OUT/'concept.png')

if __name__=='__main__':
    build()
