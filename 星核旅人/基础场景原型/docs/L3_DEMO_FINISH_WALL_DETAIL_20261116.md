# 断电续作与城墙细化补充

用户最新授权：继续完成未完的Demo收尾，并丰富城墙细节。本文件补充原`L3_DEMO_FINISH_BRIEF_20261116.md`，不替换玩法与验收限制。

## 断电后实际状态

- 协调重查原1343项保护：UNCHANGED 1343 / CHANGED 0 / ADDED 5 / MISSING 0，OVERALL OK。新增为原brief及audit/probe脚本场景；核心修复尚未落盘，报告不存在，不能称完成。
- 已看` screenshots/level03_demo_finish_20261116/probe/a03_wall_bottom_full.png`和`b01_decor_with.png`（路径开头空格仅排版，不是文件名）：高墙上半仍是等宽竖条+低对比格网；门右脚边确有亮像素。探针采用状态setup与隐藏对照，不是自然通关证据。右端残件的实际节点仍需audit/A-B定位。
- 没有运行中的Godot进程。保留已存探针、旧before、门2380/完成2460/墙2292..2612及所有未提交用户工作，不回滚。

## 本轮联网参考：已经打开画面后才制定规格

搜索词：Castlevania Symphony of the Night castle entrance exterior stone wall screenshot。

1. Revned的《恶魔城：月下夜想曲》截图拼接地图页：`https://revned77.github.io/games/SymphonyOfTheNight.html`。
   - 原入口图：`https://revned77.github.io/maps/Castlevania%20-%20Symphony%20of%20the%20Night/Entrance.png`。
   - 原外壁图：`https://revned77.github.io/maps/Castlevania%20-%20Symphony%20of%20the%20Night/Outer%20Wall%20%28Clear%29.png`。
   - 本地原图与裁片：`previews/l3_wall_detail_20261116/refs/sotn_entrance_map.png`、`sotn_outerwall_map.png`；`sotn_entrance_stone_crop.png`为原图(0,512)-(640,1200)，`sotn_outerwall_stone_crop.png`为(1280,512)-(1824,1280)，无重画。
   - 实际观察：入口塔体石块有错缝、局部石面明暗与缺角，转角/腰线比砌缝清楚；外壁以连贯横向腰带切分大竖面，窄拱窗/凹槽在同一立面节奏排列，边框明面和内槽暗面分离。不是满墙随机噪点。
   - 可借：结构明暗优先、重复开间、局部石块磨损；不能照搬：紫夜/红砖/圆塔/室内楼梯/窗户像素、第三方logo、地图黑底。拼接图只证明静态组织，不证明运动和遮挡。
2. 本轮重开archive条目与60秒帧：`https://archive.org/metadata/CastlevaniaSotN_Richter_714`，帧下载`https://archive.org/download/CastlevaniaSotN_Richter_714/CastlevaniaSotN_Richter_714.thumbs/CastlevaniaSotN_Richter_714_000060.jpg`，本地`refs/sotn_entrance_60s.jpg`。实际看见室内分仓/基座；只作次要结构参考，低分辨率不支持像素细节判断。
3. RPGamer页面`https://archive.rpgamer.com/games/castlevania/sotn/sotnss.html`打开成功；其outerwall.jpg返回404，不作证据；outerarea.jpg已下载实看为Castle Keep户外战斗/石台，**不作为本轮大墙主要依据**。FantasyAnime两个页429，已换上面可访问来源，不把失败算核看。
4. 连续门/人物层次沿用并重新查看此前PoP帧序列：`previews/l3_gate_classic_research_20261116/refs/01_pop_rise_contact.png`、`03_pop_pass_contact.png`及同目录GIF。只门板上收、门洞人物可读；详细来源与连续时间见该目录`reference_review.md`。本轮不改变升门运动或既定穿门路线，遮挡仍须本工程实机重新检查，不能由参考代证。

## 单套细化规格（不新增玩法）

1. 保持暖灰紫石造配色、门楼144×160与高墙高出画面、原退台/檐口/基座。门仍嵌在墙内；不要移动墙轮廓/门洞/相机，不另加第二门、阳台、旗帜、城内关卡或新交互。
2. 上半墙现有96px左右开间里加入**窄盲拱龛/凹槽**，只装饰不透天空/不碰撞：每开间一处，约12–18px宽、28–40px高，底落在世界y150..170，顶部简化阶梯拱；1px亮侧/2px暗侧，内填比墙稍暗的石面，不画成纯黑门洞，不发光抢星核。避免在门洞上画第二个大拱。
3. 将上半大竖条分成有柱头/短柱脚的壁柱：横向细腰带选世界y104附近，厚3–4px，与已有y196檐线区别；柱头略外挑2px、下沿阴影，明暗方向一致。视口顶部不强行补墙顶/垛口（墙顶原本出画）。
4. 保留16px课程的错缝，按固定世界坐标加入少量石块面色差、1px缺角和2–5px短裂纹；只覆盖约十分之一石块，差值低于结构线，禁止全格明暗棋盘或随机闪变。门周更克制、原门楼PNG不改。
5. 下部与右侧基座材质接地：解决实际动画alpha低于320的漏像素，并同步背景/前景副本使用同一绘制与世界网格，防右前景出现图案接缝/透明缝。不得给人物改visible/alpha/z/脚位置伪修；不要靠巨大黑条覆盖。

## 交付与验收补充

- 原完成页真实鼠标/Enter/Space/Tab/R→重玩可移动、真实回level01主菜单要求不减。守卫仍只读，录真实J两段现效果，待用户明确意见。
- 对城墙补正常640×360实机同构图前后图、门前人物可见与过门连续遮挡序列/接地近照；功能、静态细化、连续遮挡分别记实测。只跑相关关键测试，不全项目漫测。
- 在`L3_DEMO_FINISH_REPORT_20261116.md`同时报告收尾和新增细化；未验或主观观感待用户必须明确，不把程序生成完成当审美验收。
