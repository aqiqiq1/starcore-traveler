from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

OUT = Path(__file__).resolve().parent
# Stone tones are sampled from the shipped Doric column palette in
# 基础场景原型/assets/doric_columns/doric_column_tall.png. The old green-grey
# roles map one-to-one by material role, in ascending value order:
#   out -> EDGE (66,55,62)      dark -> DARK (89,74,81)
#   groove -> recess (103,87,93) shade -> SHADE (113,96,100)
#   stone -> MID (143,128,126)  mid -> lip (160,145,138)
#   light -> lit (174,161,151)  glint -> TOP (181,169,158)
# Only these eight stone entries changed; moss/leaf/cyan/ice/gold and the
# hard-coded inactive glow remain untouched. No tint is applied at runtime.
P = dict(out='#42373e', dark='#594a51', shade='#716064', stone='#8f807e', mid='#a0918a', light='#aea197', glint='#b5a99e', moss='#697e6b', leaf='#8a9a79', groove='#67575d', cyan='#86c8c4', ice='#c2e2d8', gold='#d6be7d')

def checkpoint(active):
    im = Image.new('RGBA', (40,36)); d=ImageDraw.Draw(im)
    # A broad, solid, low plinth: no upright slab, receptacle or collectible.
    d.polygon([(3,28),(8,25),(31,25),(37,29),(37,34),(3,34)], fill=P['out'])
    d.polygon([(4,28),(9,25),(30,25),(36,28),(31,30),(9,30)], fill=P['mid'])
    d.polygon([(4,29),(9,31),(31,31),(36,29),(36,33),(4,33)], fill=P['shade'])
    d.line([(5,33),(34,33)], fill=P['stone'])
    d.polygon([(8,19),(13,16),(27,16),(32,20),(32,27),(27,29),(12,29),(8,26)],fill=P['dark'])
    d.polygon([(9,21),(14,23),(27,23),(31,21),(31,26),(27,28),(13,28),(9,26)],fill=P['stone'])
    d.polygon([(9,19),(14,16),(26,16),(31,19),(27,23),(13,23)],fill=P['light'])
    d.line([(10,19),(14,17),(25,17)], fill=P['glint'])
    # Perspective-carved nested channels, not a bowl.
    d.line([(13,19),(18,17),(25,19),(21,22),(13,19)],fill=P['groove'])
    d.line([(15,20),(21,21),(24,19)],fill=P['mid'])
    c=P['cyan'] if active else '#819591'
    d.line([(16,19),(20,18),(23,19),(20,20),(16,19)],fill=c)
    d.line([(15,25),(24,25)],fill=P['groove'])
    d.line([(17,25),(22,25)],fill=c)
    d.point((12,24),fill=P['glint']);d.line([(28,24),(27,26),(28,27)],fill=P['dark'])
    d.line([(6,29),(10,30)],fill=P['light']);d.point((32,32),fill=P['out'])
    d.line([(5,31),(7,31)],fill=P['moss']); d.point((8,30),fill=P['leaf'])
    # Three small linear resonance strokes, never a spherical star-core.
    if active:
        d.line([(16,8),(20,7),(24,8)],fill=P['cyan'])
        d.line([(18,11),(20,10),(22,11)],fill=P['ice'])
        d.point((20,5),fill=P['gold'])
    else:
        d.line([(18,11),(20,10),(22,11)],fill='#7f9694')
    return im

def gate(done):
    im=Image.new('RGBA',(76,100));d=ImageDraw.Draw(im)
    # Full-depth open arch: opening remains transparent in both states.
    # Right-hand intrados is visible behind the front face.
    d.polygon([(54,37),(60,37),(60,95),(54,95)],fill=P['dark'])
    d.line([(54,42),(54,94)],fill=P['shade'])
    for x in (9,55):
        d.rectangle((x,37,x+11,94),fill=P['out'])
        for i,(y,h) in enumerate(((38,16),(55,17),(73,18))):
            d.rectangle((x+1,y,x+10,y+h-1),fill=P['stone'] if x==9 else P['shade'])
            d.line([(x+1,y),(x+9,y)],fill=P['light'])
            d.line([(x+1,y+1),(x+1,y+h-2)],fill=P['mid'])
            d.line([(x+10,y+2),(x+10,y+h-1)],fill=P['dark'])
        # Restrained Doric fluting, interrupted at masonry joints.
        for y1,y2 in ((43,51),(59,69),(77,88)):
            d.line([(x+4,y1),(x+4,y2)],fill=P['dark'])
            d.line([(x+5,y1),(x+5,y2-1)],fill=P['mid'])
            d.line([(x+8,y1),(x+8,y2)],fill=P['shade'] if x==9 else P['dark'])
        d.rectangle((x-2,35,x+13,38),fill=P['dark'])
        d.rectangle((x-3,33,x+13,35),fill=P['mid'])
        d.line([(x-2,33),(x+12,33)],fill=P['light'])
        d.rectangle((x-3,92,x+13,96),fill=P['dark'])
        d.rectangle((x-2,91,x+12,93),fill=P['mid'])
        d.line([(x-2,91),(x+11,91)],fill=P['light'])
    # Real voussoirs, each an individually shaded radial stone.
    cx,cy=38,38
    def pt(r,a): return (round(cx+math.cos(a)*r),round(cy-math.sin(a)*r))
    for i in range(9):
        a=i*math.pi/9+.012;b=(i+1)*math.pi/9-.012
        poly=[pt(30,a),pt(30,b),pt(18,b),pt(18,a)]
        d.polygon(poly,fill=P['out'])
        poly=[pt(29,a+.012),pt(29,b-.012),pt(19,b-.012),pt(19,a+.012)]
        d.polygon(poly,fill=P['stone'] if i<3 else P['mid'])
        d.line([pt(29,a+.02),pt(29,b-.02)],fill=P['light'])
        d.line([pt(19,a+.02),pt(19,b-.02)],fill=P['dark'])
        if i in (1,6):
            p=pt(25,(a+b)/2);d.line([p,(p[0]+1,p[1]+2),(p[0],p[1]+4)],fill=P['shade'])
    # Crown is stone, not a socket. Its shallow mark signals arrival only.
    d.polygon([(34,7),(41,7),(42,17),(38,21),(34,17)],fill=P['dark'])
    d.polygon([(35,7),(40,7),(41,16),(38,19),(35,16)],fill=P['light'])
    d.line([(36,9),(39,9)],fill=P['glint'])
    signal=P['gold'] if done else P['cyan']
    d.line([(37,12),(38,13),(39,12)],fill=P['groove'])
    d.line([(37,15),(38,16),(39,15)],fill=signal)
    for x in (13,59):
        d.line([(x,39),(x,41),(x+3,41)],fill=P['groove'])
        d.point((x+2,40),fill=signal)
    # Local chipped edges / fine cracks; no blanket random noise.
    for points in [[(11,57),(13,59),(12,62)],[(63,77),(61,79),(62,81)],[(24,15),(25,18),(24,20)]]:
        d.line(points,fill=P['dark'])
    d.point((9,65),fill=(0,0,0,0));d.point((10,66),fill=P['out'])
    d.line([(7,94),(12,94)],fill=P['moss']);d.point((11,93),fill=P['leaf'])
    d.line([(13,24),(14,22),(16,22)],fill=P['moss']);d.point((15,23),fill=P['leaf'])
    d.line([(64,89),(64,87)],fill=P['moss'])
    # Thin traversable threshold, no barrier or glowing plane across opening.
    d.polygon([(6,96),(10,94),(65,94),(70,96),(70,98),(4,98),(4,96)],fill=P['dark'])
    d.line([(7,95),(65,95)],fill=P['mid']);d.line([(5,96),(68,96)],fill=P['light'])
    d.line([(27,96),(29,97),(32,97)],fill=P['shade'])
    if done:
        for x,y in ((32,4),(44,3),(49,13)):
            d.point((x,y),fill=P['cyan'])
        d.line([(33,97),(42,97)],fill=P['gold'])
    return im

def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)

def main():
    assets={'checkpoint_inactive':checkpoint(False),'checkpoint_active':checkpoint(True),'exit_open':gate(False),'exit_completed':gate(True)}
    for name,im in assets.items():im.save(OUT/(name+'.png'))
    canvas=Image.new('RGB',(1440,840),'#272b30');d=ImageDraw.Draw(canvas)
    def text(x,y,s,size=20,c='#c3c8c8'):d.text((x,y),s,font=font(size),fill=c)
    text(48,30,'恢复点  /  遗迹出口',34,'#e0e4df')
    text(49,83,'像素美术概念 · 非实机 · 原像素绘制后 NEAREST ×4 · 未接入工程',18,'#96a3a5')
    d.line((48,126,1392,126),fill='#424a50')
    text(48,150,'01  矮石质共鸣座',25,'#d4dad4')
    text(730,150,'02  风化石券出口',25,'#d4dad4')
    text(48,195,'宽矮实体 + 浅槽嵌光，区别于竖直教程碑',17,'#97a4a5')
    text(730,195,'券石接缝 / 内侧厚度 / 柱身浅槽 / 开放门洞',17,'#97a4a5')
    text(117,249,'未激活',20); text(421,249,'已激活',20,'#a4d2cd')
    text(804,249,'可通行',20); text(1132,249,'通关反馈',20,'#d5c18d')
    text(80,358,'短线式共鸣标记',18,'#96aaa9')
    text(80,388,'不是悬浮星核，也不是收纳槽',17,'#96aaa9')
    text(80,430,'石身约 34 × 19 px',18)
    text(80,460,'含反馈最大约 34 × 30 px',18)
    base=680
    placements=[('checkpoint_inactive',99),('checkpoint_active',403),('exit_open',740),('exit_completed',1068)]
    for name,x in placements:
        im=assets[name]; up=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST)
        y=base-im.height*4
        # Quiet neutral ground strip; not a scene composite.
        d.rectangle((x-12,base-4,x+up.width+12,base+3),fill='#4e5357')
        d.line((x-12,base-4,x+up.width+12,base-4),fill='#777d7b',width=1)
        canvas.paste(up,(x,y),up)
    text(70,711,'触碰激活 · 落坑返回 · R 清除恢复点',18,'#b0bbba')
    text(730,711,'始终开放 · 走到出口即通关 · 不新增解锁条件',18,'#b0bbba')
    d.line((48,756,1392,756),fill='#424a50')
    text(48,777,'金 / 青仅为物件状态反馈，不改变玩家极性；概念源文件均为透明原尺寸 PNG。',18,'#96a3a5')
    canvas.save(OUT/'checkpoint_exit_preview.png')

if __name__=='__main__':main()
