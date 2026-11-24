# 三关 Demo 初步收尾记录

- [场景逐项分类](scenes_inventory.csv)：按第一关入口、两项 autoload、三关流转、子场景、动态路径及全局脚本类型建立运行闭包。Godot 可扫描的 171 个场景保留 23、归档 148（含旧 `main.tscn`、独立实验、测试与拍摄工具）。示例场景归档不等于删除正式关共享的基类。
- [资产旧新映射](asset_rename_map.csv)／[命名审计](asset_naming_audit.csv)：规范化 21 个文件，覆盖角色、门、音效、第二台紫晶；资源字节不变。已有规范名及有追溯用途的批次目录保留。保留重组 B 供试听，不把它算成运行时默认音效。
- [逐文件归档与恢复](archive_manifest_20261119.csv)：共 2289 个文件，含场景、配套脚本与证据。恢复旧测试时，应使用单独的工程副本，按 `restore_to` 成组恢复，不覆盖正式文件；若脚本仍引用旧资产名，按[旧名残留清单](archive_stale_asset_refs.json)和资产映射在副本中对照处理。证据原件不改，恢复也不保证过时测试按现版规则通过。
- 既有工程内 `.gdignore` 下的五份改版前场景是回滚副本，不计入上述可扫描场景；为保留原恢复与核验工具链而原位保留，不参与 Godot 扫描。DS03 的历史截图清单仍使用旧 `res://tests/logs/`；对应日志在[工程外历史测试目录](../../非运行资料/历史测试与证据/tests/logs/)。
- [文档分流](DOCUMENTS.md)／[Skill 盘点](SKILL_REVIEW.md)。
- **回收后又被写回的场景**：`polarity_record_test_room.tscn`、`polarity_record_test_room_standalone.tscn`、`star_core_interaction_standalone.tscn` 在 13:26 重新出现在 `scenes/`，与归档件哈希不同（回写的是旧格式，只差 UID 元数据）。迹象指向仍打开的 Godot 编辑器把已归档场景写回，`.godot/editor/*editstate*` 同分钟更新。已两份都不删地移入 `非运行资料/历史测试与证据/_restored_stale_20261119/scenes/`；移动后重新导入 0 错误、三关 90 帧 0 诊断。若编辑器仍开着这三个标签，请**不保存关闭**，否则可能再次出现。

Godot 4.7.2 重新导入与三关各 90 帧无界面载入均退出 0，无错误或警告。工程探针另核 21 个改名文件加载与 28 条动态资源组合。未实导 Windows 包、未做完整真人路线或重跑历史大套；未改导出预设、提交或推送。
