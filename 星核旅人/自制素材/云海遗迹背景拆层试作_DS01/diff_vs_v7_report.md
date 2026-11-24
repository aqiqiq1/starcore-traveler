# 原位逐像素差异报告（DS01）

- 合成：`reassembled.png`，640×360，叠放 0→7，全部初始 offset（天空云为 −12，其余见 manifest）。
- 基准：`基础场景原型/assets/backgrounds/cloud_ruins_v7.png`（与概念图 1280×720 NEAREST 还原的 640×360 一致）。
- 比较像素：230,400。
- 不同像素：**0**。
- 最大单通道差：**0**。
- 差异包围盒：无。
- `diff_vs_v7.png`：全黑（黑色=零差异，未放大）。
- 附加：`reassembled.png` 与工程运行图 `cloud_ruins_v7.png` 的 SHA-256 都是 `0c81488d...f9092`，文件字节也一致。
- 结论：静态原位合成逐像素一致。

**边界说明**：零差异只说明“层在初始 offset 时能无损还原 V7”，不证明移走对象后的补绘质量。补绘只进入原位被遮、层覆盖的区域；其中天空云下 14,136 px、云海下 54,289 px、浮石下 1,607 px、低浮石下补云 522 px，以及云海 8px 夹边、天空云左右 12px 画外延续（延续列复制自 V7 边缘列，画内 640 列未改）。移开后的效果请看 `checks/extreme_displacement_check.png`、`checks/sky_edge_fixed_check.png`、`checks/stress_detail_4x.png` 和 GIF 抽帧。

保护文件：基线 31 条 SHA-256 全部匹配；详情 `checks/protected_hashes_check.json`。基线 JSON 的内嵌路径为乱码，核对按 basename + hash 完成。
