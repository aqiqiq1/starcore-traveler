# 协调关键复核与最终边界

## 已核结果

- 协调独立运行`test_flow_hurt_20261116.tscn`：159 PASS / 0 FAIL，退出0，无ScriptError；日志`tests/level03/test_flow_hurt_coordinator.log`。包括真实键鼠二关→三关、移动、红/远离击退/保护、二击后恢复，及已修“第二击暂停可取消失败”的漏洞。是状态setup+引擎输入测试，非人工整关。
- 已看二关三按钮完成页、主角命中帧/150ms恢复帧和恢复点实机图；正常受击材质透明/颜色还须下述像素对照，不能因159项全绿跳过。
- 1371保护仍FAIL：5授权脚本及新增shader/专项外，工程越范围执行旧suite，覆盖了5个旧`tests/logs/`产物；无运行源码/资产额外变化、0缺失，但旧日志原文不可恢复。保留原before哈希和现新日志，不改checker/不重新基线抹掉失败。旧导航测试仍按二关旧主按钮含义，需后续最小兼容；不以此故障去回滚用户要求的新按钮，也不称全项目回归通过。

## 已修：正常状态被材质重复采样（保留发现过程）

`l3_player_hurt.gdshader`当前`base=COLOR`、再`texture(TEXTURE,UV)`，最后`vec4(rgb,tex.a)*base`。

协调本轮实际打开Godot官方文档`https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html`：fragment输入COLOR已经是vertex颜色×默认TEXTURE，不能再乘一次texture。现在amount=0会把纹理颜色乘两遍，半透明alpha也可能平方，违背正常原人物不变。此为代码层明确缺陷，尚待引擎同帧对照确证范围。

单套定向修：用vertex传入的varying颜色与一次texture采样混色，或等效处理，保留CanvasItem modulate/self_modulate语义，不除以黑像素。无受击时与无材质同帧画面逐像素一致；受击时确红且alpha/轮廓不变；结束/R/重置/完成无残色。补专项实机对照并修源，不用原159检查冒称已验材质基线。只授权原L3 shader/新test_flow_hurt_*或capture_flow_hurt_*及报告，不能改原贴图。

## 音频与提案边界

- 研究清单`previews/audio_audit_20261116/AUDIT.md`已独立核主要scene坐标/函数；纠正升门声起点应为insert_started/嵌核成功，door_opened进度0.62是可通行而非全开；浮地发声位置随phase，不是休眠y348；二关进度由实际入仓而非禁用monitoring的checkpoint标记触发。
- 工程正在只改音频试听目录补失败/恢复两条至12候选、纠正重组/电影石响误标；runtime音频不接。所有技术检查不冒充听审。
- 重生变暗→暗场内恢复→淡入+轮廓提示仅建议，用户尚未明确选定，未实现、不改现恢复点/等待。后续正式制作仍须先核相关连续参考。

## 工程补记：shader 材质修复后（仅追加，未改上节协调结论）

- 已按“必修”修 `l3_player_hurt.gdshader`：varying 保存 vertex `COLOR`，fragment 只采样一次 `TEXTURE`，再混红；不除黑像素。
- 正常材质同帧实渲：协调 probe 修复前 `pixels=404`/exit1（图保留在 `neutral_coordinator/`）；修复后 `pixels=0`、tint=0.00、exit0（`neutral_coordinator_after_20261116/`），PIL 独立复核 changed=0、max_abs=0。
- 修复后受击实机图/GIF 在 `screenshots/flow_hurt_audio_20261116_after_shader/`（`c` 前缀）；旧 `b/h` 已标“修 shader 前”，未覆盖。
- 专项 `test_flow_hurt_20261116` 复跑 159/159；47 沿用已过日志；旧广测未跑。1371 仍仅 5 个旧日志产物 FAIL，未重基线/未改 checker。

## 协调最终核验与交付

- 独立实渲修后probe：`NEUTRAL_SHADER_RENDER_DIFF pixels=0 tint=0.00`、退出0；新图`neutral_coordinator_verified/`、日志`tests/level03/test_flow_hurt_neutral_after_coordinator.log`。修前404像素差的原图/日志保留。正常人物逐像素恢复原样；已看修后c受击序列，明红/淡回与向外位移可见。
- 159项为协调独立复跑的功能结果（其后只修shader采样，工程再跑159通过）；47/194/21为审工程日志，不冒称协调独立又全跑。没有真人整关/长时间OS按键重复测试，不做全项目通过结论。
- 音频最终12候选，新增failure/respawn，与现有6条副本分组；旧10候选/旧串烧/旧6副本保留。协调独立读12WAV：44.1kHz单声道，无削波，最大峰值0.70792；6副本SHA与runtime6文件全部相同，manifest JSON有效。
- 协调实际打开试听页，用选择器设A=failure/B=respawn并点击A→B，页面走到“播放结束”；只证明文件加载/解码与播放流程，不冒充人耳听审。已留浏览器页`http://127.0.0.1:8776/audio_review_20261116/audition.html`；本地长久入口为`previews/audio_review_20261116/audition.html`，不依赖本地HTTP也可双击。
- 音频事件盘点与来源：`previews/audio_audit_20261116/AUDIT.md`、`sources.md`；已校准浮地移动y、L2实际入仓推进恢复点、升门起点与0.62可通行阈值，避免错接。新增音频全部候选未批准/未接入，脚步/环境/音乐仍后续可选。
- 5个历史日志覆盖的原/新SHA记录为`docs/FLOW_HURT_AUDIO_LOG_OVERWRITE_20261116.txt`。保护整体FAIL如实保留，未改原before/未重基线。后续修旧导航测试仅限按钮语义与setup兼容，不扩大为全关重测。
- 推荐下一步：创作者试玩二关完成→三关与受击，试听后选声；另确认“短变暗→暗场恢复→淡入/轮廓提示”的复活提案。该过场未实现，不更改既定恢复点/两击失败。工程/研究均停手，未提交推送。
