"""Original Pillow concept sheet only; not production assets or game integration."""
from pathlib import Path
from math import exp
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FONT = Path('C:/Windows/Fonts/msyh.ttc')
OUT = HERE / 'concept.png'
SIZE = (26, 52)
GOLD, CYAN = '#f4cd63', '#5fe1e6'


def font(size):
    return ImageFont.truetype(str(FONT), size)


def groove_floor():
    """Keep the original 5 px ends; ease through 4 px to a short 3 px waist."""
    mask = Image.new('L', SIZE)
    d = ImageDraw.Draw(mask)
    d.polygon([(12, 9), (14, 11), (14, 41), (12, 43),
               (10, 41), (10, 11)], fill=255)
    for y in range(21, 32):
        d.line((0, y, 25, y), fill=0)
        left, right = groove_bounds(y)
        d.line((left, y, right, y), fill=255)
    return mask


def groove_bounds(y):
    if 24 <= y <= 28:
        return 11, 13
    if 21 <= y <= 31:
        return 11, 14
    return 10, 14


def mix(a, b, amount):
    return tuple(round(x + (y-x)*amount) for x, y in zip(a, b))


def stone(state='grey', band_y=26):
    im = Image.new('RGBA', SIZE)
    d = ImageDraw.Draw(im)
    # Designed chamfered crown; small loss on the right, not a jagged rock peak.
    contour = [(9, 0), (16, 0), (16, 2), (18, 2), (18, 4),
               (21, 7), (22, 11), (22, 42), (23, 44),
               (23, 46), (25, 48), (25, 51), (0, 51),
               (0, 48), (2, 46), (2, 44), (3, 42),
               (3, 23), (4, 22), (3, 20), (3, 9), (5, 5)]
    d.polygon(contour, fill='#46525e')
    # Stone volume. All bevels are grey mineral, never metal or gold trim.
    d.polygon([(9, 1), (15, 1), (17, 4), (20, 8),
               (20, 42), (18, 44), (5, 44), (5, 9)], fill='#a3aeb3')
    d.polygon([(5, 9), (9, 3), (15, 3), (18, 6), (19, 9),
               (18, 10), (15, 5), (9, 5), (6, 10),
               (6, 40), (5, 43), (4, 42), (4, 24), (5, 22)], fill='#c2c9c9')
    d.polygon([(20, 8), (21, 11), (21, 42), (22, 44),
               (20, 45), (18, 43), (19, 38), (19, 10)], fill='#778792')
    d.line([(8, 7), (10, 5), (14, 5), (17, 8)], fill='#d0d4cf')
    # Recessed side panels: restrained and ordered, two stone-carved rails.
    d.line([(7, 13), (7, 38)], fill='#7b8b94')
    d.line([(8, 14), (8, 37)], fill='#b9c2c3')
    d.line([(17, 13), (17, 38)], fill='#7b8b94')
    d.line([(18, 14), (18, 37)], fill='#b9c2c3')
    d.line([(7, 11), (8, 10)], fill='#7b8b94')
    d.line([(17, 10), (18, 11)], fill='#7b8b94')
    d.line([(7, 40), (8, 41)], fill='#7b8b94')
    d.line([(17, 41), (18, 40)], fill='#7b8b94')
    # Clustered weathering only; no fissures, branching strokes or micro-writing.
    for box, color in [((5, 16, 6, 18), '#919fa6'),
                       ((5, 19, 5, 20), '#86969f'),
                       ((18, 26, 19, 28), '#8a9ba4'),
                       ((18, 29, 18, 30), '#94a3aa'),
                       ((6, 32, 6, 34), '#c3c9c6'),
                       ((16, 6, 17, 7), '#8c9ba2')]:
        d.rectangle(box, fill=color)
    # Original end caps; the two recessed side walls follow only the small waist.
    for inset, top, bottom, color in [(2, 7, 46, '#c6cece'),
                                      (1, 8, 45, '#374651')]:
        recess = Image.new('L', SIZE)
        rd = ImageDraw.Draw(recess)
        rd.polygon([(12, top), (14+inset, 11), (14+inset, 42),
                    (12, bottom), (10-inset, 42), (10-inset, 11)], fill=255)
        for y in range(11, 42):
            left, right = groove_bounds(y)
            rd.line((0, y, 25, y), fill=0)
            rd.line((left-inset, y, right+inset, y), fill=255)
        im.paste(Image.new('RGBA', SIZE, color), (0, 0), recess)
    floor = groove_floor()
    im.paste(Image.new('RGBA', SIZE, '#596b77'), (0, 0), floor)
    # Inner wall shading and the bright stone lip make the unlit depth explicit.
    d = ImageDraw.Draw(im)
    for y in range(13, 41):
        left, right = groove_bounds(y)
        d.point((left, y), fill='#4a5b67')
        d.point((right+1, y), fill='#93a5ad')
    if state != 'grey':
        target = Image.new('RGB', (1, 1), {'gold': GOLD, 'cyan': CYAN}[state]).getpixel((0, 0))
        for y in range(9, 44):
            # Downward travel: a long soft trailing edge, shorter leading edge.
            sigma = 6.5 if y < band_y else 3.6
            strength = 0.27 + 0.73*exp(-0.5*((y-band_y)/sigma)**2)
            left, _ = groove_bounds(y)
            for x in range(26):
                if floor.getpixel((x, y)):
                    edge = 0.84 if x == left else 1.0
                    d.point((x, y), fill=mix((55, 70, 81), target, strength*edge))
    # A compact two-step foot, the same width and material as the stone.
    d.polygon([(4, 44), (20, 44), (23, 47), (2, 47)], fill='#a6b0b2')
    d.line([(4, 44), (20, 44)], fill='#c4cbc8')
    d.rectangle((2, 47, 23, 48), fill='#6f808b')
    d.polygon([(2, 49), (23, 49), (24, 50), (1, 50)], fill='#a2adb0')
    d.line([(1, 51), (24, 51)], fill='#53636f')
    d.rectangle((3, 49, 5, 49), fill='#bdc5c3')
    return im


def main():
    source = ROOT / '基础场景原型/assets/characters/male_hero-idle.png'
    frame = Image.open(source).convert('RGBA').crop((0, 0, 128, 128))
    hero = frame.crop(frame.getbbox())
    assert hero.size == (32, 37), hero.size
    states = [stone(s) for s in ('grey', 'gold', 'cyan')]
    assert len({s.getchannel('A').tobytes() for s in states}) == 1
    mask = groove_floor()
    for y in range(12, 42):
        expected = 3 if 24 <= y <= 28 else 4 if 21 <= y <= 31 else 5
        assert sum(mask.getpixel((x, y)) > 0 for x in range(26)) == expected
    # State changes are strictly inside the identical floor, never on the stone.
    for lit in states[1:]:
        for y in range(52):
            for x in range(26):
                if lit.getpixel((x, y)) != states[0].getpixel((x, y)):
                    assert mask.getpixel((x, y))
        assert lit.getpixel((12, 26))[:3] != lit.getpixel((12, 13))[:3]
        assert lit.getpixel((12, 26))[:3] != lit.getpixel((12, 39))[:3]
    assert all(max(states[0].getpixel((x, y))[:3])
               - min(states[0].getpixel((x, y))[:3]) < 45
               for y in range(52) for x in range(26))

    canvas = Image.new('RGB', (1080, 1098), '#171f29')
    d = ImageDraw.Draw(canvas)
    ink, muted = '#e7eceb', '#a4b3be'

    def text(x, y, content, size=16, color=ink):
        d.text((x, y), content, font=font(size), fill=color)

    def center(x, y, content, size=16, color=ink):
        d.text((x, y), content, font=font(size), fill=color, anchor='mt')

    def paste(im, x, y, scale=1):
        if scale != 1:
            im = im.resize((im.width*scale, im.height*scale), Image.Resampling.NEAREST)
        canvas.paste(im, (x, y), im)

    text(28, 21, '提示石碑 / 古文明智慧集合', 29)
    text(29, 66, '概念示意 · 待确认 · 非游戏截图', 16, '#c4cfcf')
    labels = [('远处 · 灰态', '未发光也能读出石槽深度', muted),
               ('靠近 · 金态', '柔和底光＋中段亮带', GOLD),
               ('靠近 · 青态', '同槽同形，仅槽内换色', CYAN)]
    for i, (im, (title, caption, color)) in enumerate(zip(states, labels)):
        x = 28 + i*344
        d.rounded_rectangle((x, 108, x+336, 526), radius=10, fill='#222e3a')
        center(x+168, 123, title, 21, color)
        paste(im, x+90, 166, 6)
        center(x+168, 491, caption, 15, muted)

    center(540, 540, '6× 最近邻放大  /  26 × 52 px  /  上下槽宽仍为 5 px，中段渐收至 4 → 3 px', 16)
    center(540, 569, '沿用收顶、边框与座脚 · 无新增裂纹 · 槽壁随中段轻收，保持凹陷深度', 15, muted)

    d.rounded_rectangle((28, 609, 1052, 770), radius=10, fill='#222e3a')
    text(47, 623, '槽部关键帧｜流光向下经过收腰', 19)
    text(47, 662, '仅示意亮带位置：上 → 中 → 下', 14, muted)
    text(47, 690, '柔尾在上、前缘在下；边缘渐变衔接', 14, muted)
    text(47, 718, '金 / 青缓慢交替独立于亮带位移；不频闪', 13, muted)
    for i, (position, name) in enumerate([(16, '经过上段'), (26, '经过收腰'), (36, '经过下段')]):
        x = 512+i*178
        paste(stone('gold', position).crop((8, 7, 17, 46)), x, 659, 2)
        text(x+30, 674, name, 14)
        text(x+30, 701, '↓', 25, GOLD)
        if i < 2:
            text(x+133, 686, '→', 22, muted)

    d.rounded_rectangle((28, 786, 458, 1043), radius=10, fill='#222e3a')
    text(47, 801, '原生 1×｜同地面比例检查', 19)
    text(47, 833, '三态未缩放；角色帧 0 已裁透明留白', 13, muted)
    baseline = 946
    for im, x, label in zip(states, (93, 179, 265), ('灰', '金', '青')):
        paste(im, x, baseline-52)
        center(x+13, 956, label, 13, muted)
    paste(hero, 356, baseline-37)
    center(372, 956, '角色', 13, muted)
    d.line((64, baseline, 414, baseline), fill='#596978')
    text(47, 993, '石碑 52px / 角色 37px ≈ 1.41 倍', 14)
    text(47, 1018, '本图尺寸为概念设计值，尚未工程适配', 12, muted)

    d.rounded_rectangle((476, 786, 1052, 1043), radius=10, fill='#222e3a')
    text(494, 801, '上方操作提示｜仅示意位置', 19)
    d.rounded_rectangle((514, 839, 1013, 932), radius=6,
                        fill='#141f2b', outline='#607380')
    text(532, 850, '护符能改变你的极性。', 17)
    text(532, 879, '按 Q 切换，试着接近符石。', 17)
    text(930, 906, 'F 继续', 14)
    d.polygon([(750, 932), (762, 942), (774, 932)], fill='#607380')
    d.polygon([(753, 931), (762, 938), (771, 931)], fill='#141f2b')
    paste(states[1], 749, 953)
    paste(hero, 827, 968)
    d.line((715, 1005, 898, 1005), fill='#596978')
    center(764, 1016, '靠近后：槽内金 ↔ 青缓慢交替；亮带柔和流过', 13, muted)

    text(29, 1060, '原创程序像素概念；待用户确认，非正式素材。中文为系统字体示意，未导入游戏。', 13, muted)
    canvas.save(OUT)
    print(f'Created: {OUT}')
    print(f'Frame 0 cropped: {hero.size}; stone: {SIZE}; groove floor: 5 / 4 / 3 / 4 / 5 px.')
    print('Verified: identical silhouette, grey unlit, light confined to floor, localized bright band.')
    print('Only concept.png written. No game implementation or original character changes.')


if __name__ == '__main__':
    main()
