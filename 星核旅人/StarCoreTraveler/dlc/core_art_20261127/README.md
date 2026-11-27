# core_art_20261127

星核 / 星核仓像素资产升级的可复现资料。参考记录与设计说明见
`../ASSET_UPGRADE_CORE_20261127.md`。

> 同日第二次修正：自由星核去掉固定的 1 px 金外环（只留切面/内芯/碎屑），
> 仓体金环保留；详见 `../core_badge_20261127/`。本目录的 `verify_core_art`
> 已加“外环带 < 60 px”断言。

## 文件

- `gen_core_assets.py`：确定性生成 16×16 / 192×16 星核三态、32×32 星核仓
  base/glass/empty。只读 `original/` 作为旧图备份与 glass 旧轮廓依据，
  不读第三方图片。
- `original/`：升级前的同名 PNG（`.gdignore`，不参与导入）。
- `references/`：CrossCode / HLD 研究图与旧资产 8× 对照（`.gdignore`）。
- `capture_core_art.gd/tscn`：L1 电影 18.40/18.85 s + L3 两个仓状态的
  640×360 实景截图。
- `verify_core_art.gd/tscn`：12 帧播放/回绕、尺寸、空满仓、Loom 仓断言。
- `make_evidence.py`：4× 最近邻接触表与 DLC3 截图拷贝。

## 复现命令

```powershell
D:/minic/envs/2024212971/python.exe dlc/core_art_20261127/gen_core_assets.py
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://dlc/core_art_20261127/verify_core_art.tscn --quit-after 300
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 res://dlc/core_art_20261127/capture_core_art.tscn
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 res://dlc/star_loom/tests/capture_mechanics.tscn
D:/minic/envs/2024212971/python.exe dlc/core_art_20261127/make_evidence.py
```

DLC3 的 `01/03` 截图由既有 `capture_mechanics.tscn` 采集后拷贝到
`screenshots/core_art_20261127/`；4× 拼版只做最近邻裁剪，不做游戏内缩放。

## 边界

不改玩法、碰撞、数值、状态机或场景坐标；共享仓只增加空仓 base 的
`modulate`。第三方参考未进入运行时，也未核实再分发许可。
