# 极性门开启提示 / 光桥消失反馈 · 呈现参考（2026-11-25）

本轮针对两个具体问题补做呈现：①极性门开启后只是变暗，远看像“坏掉”；②相性桥消失
只有碰撞层变化，没有画面/声音反馈。按项目规则，先联网打开直接相关的参考画面并逐帧
核看，再实现；本文件只记录**实际打开并看到的**内容。

## 实际打开并核看的来源

### 1. Celeste Wiki · Core Block Hot / Cold（连续帧）

- 页面：<https://celeste.ink/wiki/Core_Block>（2026-11-25 打开）
- 原图：<https://static.wikitide.net/celestewiki/e/e4/Core_Block_Hot.gif>（7 帧，160×120）、
  <https://static.wikitide.net/celestewiki/6/68/Core_Block_Cold.gif>（12 帧，160×120）
- 逐帧观察：
  - Hot：深炭黑整块，亮红/橙裂纹向中心汇聚，中心是偏白橙的亮核；核随帧轻微呼吸。
  - Cold：同一轮廓整体转深蓝，裂纹变青，中央核在 12 帧里由小菱形涨大成近白的大菱形，
    再收回；**状态转换的第一读点仍是整块色 + 中央亮核**，不是换造型。
  - 两态都保留 1 px 深边和顶部亮带；核的脉动幅度明显大于内部纹理变化。

### 2. Celeste Wiki · Dream Blocks（连续帧）

- 页面：<https://celeste.ink/wiki/Dream_Blocks>（2026-11-25 打开）
- 原图：<https://static.wikitide.net/celestewiki/3/3f/Dreamblocksquare.gif>（38 帧，200×200）
- 实际抽看 0/5/10/15/21/26/31/37 帧（8 帧拼图）：
  - 可穿行状态是**黑色空心块 + 白色 1 px 轮廓**，内部彩色星点是静态装饰；
  - 角色在块内时，块内出现只被块边缘裁剪的蓝色折射/星云动效，效果不会溢出块外；
  - 角色离开后，块内部恢复空心，轮廓仍在——空心 + 内部动效承担“可通过”的读点，
    不需要把整块画得更亮。
  - 页面文字同时确认：可穿行/不可穿行是同一实体的两种状态，不是两套造型。

### 3. 本项目既有截图（基准，不是第三方）

- `dlc/trial_chambers/tests/out/gate_gold_closed.png`（旧版关闭态）
- 观察：关闭态是实心金场 + 中央亮核；旧开启态只把 alpha 降到 0.26，轮廓仍像“断电线”。

## 可借鉴 / 不照搬

可借鉴：
- 状态先于细节：关闭态保持实体亮场；开启态保留同一 8×88 轮廓与中央亮核，只用
  **内部单向运动**（缓慢上浮的 1 px 亮虚线 + 小箭头）表示“可通过”，运动不越出门带；
- 消失反馈只在实体本体内做短命碎片/余辉（参考 Dream Block 把洞里的动效裁在块内），
  不新增大贴图、不改变碰撞轮廓；
- 中央核可轻微脉动，作为“还活着”的第二读点（Core Block 的核呼吸）。

不照搬：
- 不使用 Celeste 的方块像素、裂纹贴图、Hot/Cold 具体造型、Dream Block 星点/折射素材；
- 不复制其调色板数值、字体、音效；本项目仍用金 `#f4cd63`、青 `#5fe1e6`、近黑底；
- 不做“站上去弹飞/下沉/冲刺穿块”的玩法；本项目的门仍是同相可穿、异相阻挡。

## 本轮实现对应的具体决定

- `dlc/trial_chambers/polarity_gate.gd`：开启态在 6 px 内场里画 3 条 4×1 px 近白横线，
  每条上方 3 px 内画 1 px 箭头（共 3 px 宽），2.2 s 一轮自下而上，两端淡入淡出；
  关闭态完全保留原实体亮场与横向火花刻度；碰撞、防夹与状态 API 未改。
- `dlc/rift_workshop/rift_phase_bridge.gd`：消失时 0.18 s 内画顶边白热线 + 9 个 1×2 px
  上浮碎片 + 底沿 1 px 余辉；实化保留原 0.22 s 白闪；碰撞仍在状态切换当帧生效。
- `dlc/rift_workshop/rift_polarity_wisp.gd`：击破后 0.14 s 的白色 2×2 核心 + 四向 1 px
  爆点，随后是原有 0.34 s 六片碎屑；不新增贴图，不改推力/拉力/命中规则。

## 证据路径（本机实际查看用）

- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-passcue-core-hot-20261125.png`
- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-passcue-core-cold-20261125.png`
- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-passcue-dream-sample-20261125.png`

这些只是核看证据，不属于 DLC 运行素材，不随工程分发。

## 未核实 / 边界

- 未运行 Celeste 本体，未听其开关/脉冲音效；参考只支持“整块状态 + 内部动效 + 核脉动”
  的视觉读序，不支持任何音效结论。
- 未核 Celeste 源码或真实像素尺寸；本项目 8×88 门、64×10 桥、16×16 wisp 均为独立设计，
  不声称与原作同尺寸、同动画、同节奏。
- 本轮截图只按本项目 640×360 实机画面核看；未做真人整关可读性终审。
