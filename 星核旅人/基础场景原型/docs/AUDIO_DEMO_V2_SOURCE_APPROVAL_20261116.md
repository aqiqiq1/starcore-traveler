# 音频新源核看与单套试装决定

这是`AUDIO_DEMO_V2_BRIEF_20261116.md`的新源补充，不扩大玩法或BGM授权。协调已实际查看研究保存的作者页截图、manifest与源文件记录；HTTP工具访问OGA四页403，改用真实浏览器打开Various Sound Effects成功，snapshot核到Spring Spring/Julie Damsgaard、`break_stone.wav`、License(s) CC0。失败请求不作成功证据。

## 实际已看的来源证据

目录`previews/audio_sources_v2_20261116/`，原链接/文件URL/SHA/许可/下载与解码实测见`manifest.json`，不改原文件。

- `evidence/screenshots/05_bell_dings_page.jpg`：PWL，Bell dings/chimes，页面说明Somewhat thin and short chime，Releasing as public domain，CC0，bell_ding1..4文件清楚。原页`https://opengameart.org/content/bell-dingschimes`。
- `01_swishes_sound_pack_page.jpg`：artisticdude，13个swish，4轻/9重，CC0，包名swishes.zip，源用于FOSS RPG Summoning Wars。原页`https://opengameart.org/content/swishes-sound-pack`。
- `06_various_sfx_spring_spring_page.jpg`与协调实时浏览器snapshot：Spring Spring、Produced by Julie Damsgaard、break_stone.wav、CC0。原页`https://opengameart.org/content/various-sound-effects-0`。
- `02_cathedral_in_the_forest_page.jpg`：congusbongus，Seamless ambient loop for space or dark games / Pads and bells，CC0，forest_2.ogg。原页`https://opengameart.org/content/cathedral-in-the-forest-ambient-loop`。研究认为首尾电平接近，但**电平接近不证明无缝**，相位/旋律衔接仍需人耳；不能写已验无缝。
- Q轻闪层`gem-gather-stereo.wav`源为Bobjt、Gem collect SFX，证据`04_gem_collect_sfx_page.jpg`及原页存档；最终使用前工程同样核原许可记录。其他均以CC0上传者声明为依据，不作法务确定性承诺。
- 全部未做人耳听审；作者说明+下载/解码/峰值数据支持试装与技术判断，不支持“用户必定满意”的结论。不能复制Terraria或其他商业游戏声音。

## 统一试装，不再把常规选择丢回用户

1. **Q**：用`source/bell_ding1.wav`首个清楚起音裁成约0.45–0.55s（保留自然衰减，尾35–60ms淡出）；小量叠`source/gem-gather-stereo.wav`在起音后约30–50ms，闪层相对主铃低约12dB。若单声道合并抵消改取较好单声道而非硬加增益。不要旧反向滑音。峰值≤-6dBFS，运行时再克制衰减。保留旧Q可A/B，仅新Q接入。
2. **J**：选`source/swishes/swishes/swish-9.wav`，保留约0.197s原空挥，首尾小淡化/单声道，峰值≤-6dBFS；不加金属碰撞。不改变J动画/命中窗口。旧swing保留对照。
3. **大型石壳碎裂**：`source/break_stone.wav`主体重采样44.1/48k、保留约1.0–1.15s有效首段并软收尾，叠本地旧Kenney源`impactMining_000`的短低中频起击（原包CC0已核，具体路径/哈希记录）。不加长爆炸/长混响，保留后段碎块层次，不只提响；避免源满刻度样本继续触顶，派生峰值≤-3dBFS并降低混合总线增益。原三格/普通碎不扣格/第三散一次都不变。
4. 这三个为本轮用户新方向的**试装版**，与其余9个一起在runtime可玩；最终音色仍交创作者听审。来源许可文本/作者链接/派生参数/哈希必须复制到runtime新目录（previews被Git忽略，不能作为唯一证据）。
5. **BGM仅试听**：首选`forest_2.ogg`(2:16.97)、备选`Contemplation.mp3`(2:00.06)。试听页分别给完整曲（相对路径副本）+可选12s摘要，默认音量低(约0.25)、一次一条不自动播。推荐首选来自作者pads/bells/循环描述与时长，不声称已听过或保证无人声/无缝。备选MP3开头近静音不要现在多做循环加工，未选择不进runtime。**不接自动BGM，不新音乐状态机。**

## 边界

- 对审计中“SA传染”等用语不采作通用法律结论；本轮仅选CC0以简化许可。源片能否适合仍需听审。
- 9原候选＋3新版runtime、旧6已接声保持、BGM两首只预览。Github步骤已准备`AUDIO_DEMO_V2_GITHUB_STEPS_20261116.md`，不执行Git写操作。
