# 第一关开始菜单运行资源

这些 PNG 是 `scenes/level_01.tscn` 集成开始菜单的**纯 UI 静态纹理**，不含背景、地形、人物或 HUD。运行尺寸固定 640×360 逻辑像素，Nearest，整数窗口缩放后仍是像素硬边。

| 文件 | 内容 / 用途 |
| --- | --- |
| `main_menu_ui_640.png` | V1 主菜单：临时字标“星核旅人”、短分隔线、“开始游戏”石牌、“设置”入口（音量符号+文字）。 |
| `main_menu_focus_start_640.png` | “开始游戏”焦点/悬停：左侧 2×7 像素光标 + 更亮的金内线。 |
| `main_menu_focus_settings_640.png` | “设置”焦点/悬停：左侧光标 + 底部 1px 冷青线 + 更亮的文字/音量符号。 |
| `settings_panel_640.png` | 设置模态：全屏轻遮罩、加高的石质面板、“设置”“主音量”“显示模式”“窗口分辨率”“返回”静态字/石牌。动态百分比、滑条、模式/分辨率选项、应用按钮、提示与确认倒计时由运行时绘制，不在此图。 |
| `settings_return_focus_640.png` | “返回”按钮焦点/悬停：1px 冷青外环 + 更亮的文字；位置随加高面板下移到 (324,262) 的 144×24 槽内。 |
| `main_menu_quit_640.png` | 新增“退出游戏”第三入口：640×360 全透明图层，12px Fusion Pixel 青灰字，居中叠在“设置”下方 (284,212) 的 72×20 热区内。 |
| `main_menu_focus_quit_640.png` | “退出游戏”焦点/悬停：更亮的浅象牙字 + 左侧 2×7 光标 + 1px 冷青下划线，全部落在同一 72×20 热区内。 |

## 来源与修改

- 源：`星核旅人/自制素材/主界面概念预览_V1/main_menu_overlay_1280.png`（SHA256 `37deaa6aeaef3d6f14dff8de5b937b1ce7018d607d153afcae6887a31ba057f4`）。
- 生成工具：`基础场景原型/tools/build_main_menu_ui.py`；只读源 overlay + 工程字体，**不修改**原 V1 目录。原 `make_preview.py` 未被覆盖。
- 主菜单基础图是原 overlay 的精确 2× NEAREST 降采样；脚本断言 1280 是 640 的精确 2×，且基础 640 UI 在已批准四行之外完全透明。退出图层是另加的第五行，不写进基础图。
- 字体：`assets/fonts/tutorial_zh.ttf`，Fusion Pixel 12px Prop zh-Hans / TakWolf / OFL-1.1（SHA256 `58a0ac8784bfb0ed70b788a9cf815d00fcad9daa9e0517b8d1c244b4f912e3d6`）。标题/开始/设置/退出均由 12px 栅格 1×/2×/3× NEAREST 放大，不使用系统字体 fallback。
- 设置面板、焦点图和返回按钮由同一工具以 V1 色值/像素折角规则绘制；没有新增 Logo、继续、操作说明、存档或选关。主菜单后来新增了第三项“退出游戏”，用单独的 `tools/build_main_menu_quit.py` 生成两张附加图层，不重画 V1 标题/开始/设置/背景。
- 设置面板为容纳“窗口/全屏、640×360/1280×720/1920×1080/2560×1440、应用”加高到 (150,26)–(490,334)；选项是面板内真实像素控件，不使用会遮挡其他行的弹出菜单。只显示当前屏幕可容纳的尺寸为可选，超出工作区的项禁用并写明原因。
- 运行时由 `scripts/start_menu.gd` 显示，真实 `Button`/`PixelVolumeSlider`/`PixelMenuButton` 热区叠在上面；不烘焙背景，不把静态预览当活菜单。内部逻辑画布始终 640×360。

## 输出哈希（本次生成）

| 文件 | SHA256 |
| --- | --- |
| `main_menu_ui_640.png` | `7c85d1f5bdfd3bb268cb653496ca1c6482b5bf278250095923c0dc3af5e0262b` |
| `main_menu_focus_start_640.png` | `f8493fb05ce3525c95181d744c6228ff209c41c3125c575df5b5184befed66a4` |
| `main_menu_focus_settings_640.png` | `36d3ec59b8ab4061d1d7a61d8e752254c0f8879c0a37214fde5f2dc54a6d36f3` |
| `settings_panel_640.png` | `6d4518f8f55b773f5c4ecf1a8c753b94cf2d4e03b162d1eb428198acaafa196d` |
| `settings_return_focus_640.png` | `0e349cae40a2bfd05955c55c2d4956ac620e0b1950df5b282bc2e70a29329739` |
| `main_menu_quit_640.png` | `a711bf97ba072502ed0099d364a9f9333e421282692c230b4ce0988233e23017` |
| `main_menu_focus_quit_640.png` | `a3cb107696d9bd456f81ac144cbc6af4e94ad3aaa549c4409352a23207b7543b` |

`tools/build_main_menu_ui.py` 会校验三张受保护主菜单图（标题/开始/设置入口）的 SHA256；重跑只重建设置面板。`main_menu_ui_640.png`、`main_menu_focus_start_640.png`、`main_menu_focus_settings_640.png` 的字节未变。新增的退出图层由 `tools/build_main_menu_quit.py` 单独生成，该工具同样校验这三张图的哈希，只写 `main_menu_quit_640.png` 与 `main_menu_focus_quit_640.png`。

## 复现

```powershell
cd "D:\godot game\星核旅人\基础场景原型"
& "D:\minic\envs\2024212971\python.exe" tools\build_main_menu_ui.py
& "D:\minic\envs\2024212971\python.exe" tools\build_main_menu_quit.py
```

`build_main_menu_ui.py` 会重新写出原 5 张 PNG，不读取/覆盖任何截图或 V1 预览；`build_main_menu_quit.py` 只写新增的 2 张退出图层。若字体或 V1 overlay 改变，先由协调者确认；不要直接手改这些运行 PNG。许可与来源也记录在 `ASSET_CREDITS.md`。
