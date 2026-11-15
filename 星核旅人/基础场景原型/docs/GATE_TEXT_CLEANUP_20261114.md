# L2 文字精简与统一出口特效（2026-11-14）

## 状态

用户已授权直接优化正式版：删除第二关不必要世界文字，第一关及今后所有可交互/可通关出口统一显示已批准 v2 门内 FX。未实施 L3、音效或新美术；根 progress/TODO/计划未改。

## 改动

- `scenes/level_02.tscn`
  - 删除六个世界文字：`StartBayLabel`、`RelayBayLabel`、`LinkedBayLabel`、`FinalBayLabel`、`CorridorLabel`、`ExitStatus`；没有保留隐形占位。
  - 门仍由 `LevelExit` 默认 v2 FX 驱动，场景不再单独配置 FX 资源。
- `scripts/level_02.gd`
  - 删除 `_exit_status` onready/更新块，避免删 Label 后每 tick 空引用。
  - 保留 CompactHeader/相性；任务行只显示短目标；星核行只显示“起始/中继/联动/最终仓/运输中/未知”，不再常驻“记录/符石”长技术串（内部 `_record_label_zh`/`_field_label_zh` 保留，供状态/API 使用）。
  - 中央提示只在真实动作可用时显示：`E 存入/释放`、`开罩中/合罩中`；无动作时不显示“把人和核带到空仓/借符石上台”等重复目标句。
  - 删除底部常驻恢复提示调用；恢复/失败/R 仍使用短事件 toast。
- `scripts/level_02_hud.gd`
  - 不再创建底部恢复 Label；`set_recovery_hint` 保留为兼容数据入口，不再绘制。
  - 中央 prompt 初始为空/隐藏；`set_status` 继续兼容，但由 Level02 只传入真实动作。
  - 完成页按钮、暂停状态、toast、错误/失败理由保留。
- `scripts/level_exit.gd`
  - 默认具备 `DEFAULT_GATE_FX_SHEET = gate_portal_fx_v2_8f.png`，默认 `gate_portal_fx_enabled=true`；不再要求每个实例单独配 PNG。
  - 仍由 `set_gate_available()` 决定可见；closed/completed/离开隐藏、暂停冻结、完成原图保留。
- `scripts/level_01.gd`
  - 增加 `_refresh_exit_gate_available()`：菜单/开场托管/完成/离场/下一关时不显示 FX；正常可控游玩显示。
  - 菜单关闭时开场先关；intro 完成交还操作后亮；R 重开先进入开场隐藏，交还后恢复；暂停冻结，不新增通关条件/E/F。
- 未改：已批准 6 张 PNG、L1 scene、DS03、player、共享力常数、rune 逻辑、正式 HUD 布局/标题图标、project.godot。

## 未来出口接法

`LevelExit` 默认拥有 v2 资源/8 帧/8fps/锚 38,99/Nearest/正常 alpha。关卡只负责真实状态：

```gdscript
_exit.set_gate_available(real_condition and not completed)
```

无附加锁的门（L1）在 normal interactive gameplay 传 true；有仓/记录条件的门（L2）传真实 `is_exit_gate_ready()`。不要直接改 Sprite2D 可见性或复制动画脚本。未来新出口无需另配 PNG。暂停由 LevelExit `_process` 检查 `get_tree().paused` 冻结；完成由 `set_completed(true)` 隐藏并显示原完成图。

## 验证（实际日志）

- `tests/test_gate_text_cleanup_20261114.tscn`：**53 PASS / 0 FAIL**。
  - L2 6 个世界 Label 均不存在；HUD 短目标/短星核行；无记录/符石长串；无底部恢复 Label；无 idle 中央提示；真实 E 动作时 prompt 出现/离开隐藏；F GuideEcho/4 页、失败 toast、暂停 R 控制、完成按钮保留。
  - L1 默认 LevelExit 资源就绪；菜单/开场 FX 隐藏；intro 交还后正常显示；真实 Esc 暂停冻结/恢复；真实 R 先关再交还亮；真实出口完成隐藏；独立菜单实例隐藏。
  - L2 真实未锁门不亮；锁核/记录后共享 FX 亮；E 取核/R 关。
- L1/L2 headless 载入退出码均 0；`--headless --editor --import --quit` 退出码 0；class cache 39 类/0 重复/0 归档引用。
- 保护：`tests/logs/gate_text_cleanup_protection_20261114.json`；219 项基线 **214 same / 5 authorized changed / 0 unauthorized / 0 missing**。5 项为 `level_02.tscn`、`level_01.gd`、`level_02.gd`、`level_02_hud.gd`、`level_exit.gd`。
- 6 张已批准 PNG 哈希、原残响 `2acaa0e5…e233`、L1 scene、player、DS03、project.godot 不变；10 份源备份 **10/10**。
- 正式截图（2 张 640×360，已打开）：`screenshots/gate_text_cleanup_20261114/01_l2_clean_scene.png`（L2 无世界文字/短 HUD/门开 setup）、`02_l1_gate_fx.png`（L1 intro 后正常可通关门 FX）；`manifest.json` 固定 setup、非通关、无 preview overlay。

## 未验/风险

- 截图是固定 setup，不是人工连续试玩/完整通关；L1 截图已交还操作但未走完整路线，L2 为 gate-open setup。
- 旧 131/183/24/全量 suite 未运行；旧测试中如有对已删 Label/旧 HUD 文案的断言，不代表当前行为。
- 用户 GUI 若仍打开旧场景未保存版本，请重新加载磁盘版；未杀 GUI、未动未保存场景。
- 未提交/推送，未删缓存/UID/归档。

## 协调者复核

- 打开两张正式实机图，审阅共享门组件/L1生命周期/精简提示与53项PASS日志；修改仅注释中残留的旧“其他门不启用”说明，未改门行为。
- 独立核对219项before基线：5项授权改动、0未授权、0缺失；其余批准PNG、L1场景/player/DS03/project.godot原样，10份源备份hash一致。独立两关正式入口各载入12帧退出0，6个旧世界标签不存在。
- 未重复工程53项或人工连续通关。音效与第三关布局建议见`AUDIO_L3_NEXT_STEP_ADVICE_20261114.md`，均未据此自动开工。
