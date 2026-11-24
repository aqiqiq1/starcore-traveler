# 石地脚步与重组试装规格；切相暂缓

## 参考核看与边界

- 协调实际联网打开`https://archive.org/details/youtube-8Ff-I6x2KSA`，核GameSpot、Outland Gameplay Demo、2011-03-11及上游YouTube身份；已看研究逐0.25s连续帧`previews/audio_movement_refs_20261117/refs/frames/outland_switch_window_2055_2130_025.jpg`，207.00蓝/207.25红、211.00白闪/211.25蓝。可参考的是**瞬时改变自身状态**，不是拾取奖励；不能由画面推断它用了什么音色/尾音/音量。
- 原音未被协调或研究实际听辨，解说遮盖情况不明。音轨存在不是听审。因此**Q音色参考门槛尚未满足，本轮暂不制作/替换Q**，也不另加白闪或改玩法。把205.5–213.0s参考窗口加入本地试听页，待创作者实听反馈，不复制音轨进runtime。Teslagrad无合格片段、不造时间码；不继续无限泛搜。
- 已看`evidence/screenshots/oga_fantozzi_footsteps_page.jpg`：Fantozzi（qubodup代传）、6个Stone单步、CC0、硬地适用说明。OGA文本抓取403，不将失败算成功；来源截图可读。协调又实际打开上游`https://freesound.org/people/Fantozzi/packs/10338/`和样本`https://freesound.org/people/Fantozzi/sounds/166300/`，核作者/WalksForGames/CC0及“HANDMADE、not field recordings、dry”说明；没有逐一追溯六条切片来自哪个上游长录音，不虚构该对应。
- 协调实时浏览器打开`https://opengameart.org/content/stone-rock-or-wood-moved-sound`，核pauliuw、CC0、文件stone_rock_or_wood_moved.mp3；复用已下载源，未购买/接受协议。源manifest见`previews/audio_movement_refs_20261117/manifest.json`。旧重碎裂源CC0及派生证据沿用`assets/audio_demo_v2_20261116/NEW3_DERIVATION.json`，旧文件不覆。
- **纠正研究推断边界**：质心612Hz不能独自证明“石块而非金属”；该素材是否合适仍须实听。0.558s解码长度不直接否定旧0.456s（可能裁点/解码口径不同），记录两值及本轮口径。倒放段不能照搬“取0.52–1.12”的建议：其中静尾会变前置静音，须按实际有效采样选段。

## 脚步：一套6变体，三关正式接入

1. 从`source/footsteps/Fantozzi-footsteps/flac/`的Stone L1–3/R1–3无损文件派生，44.1k PCM16 mono，保留短起音和摩擦尾，首尾约2–8ms淡化；不使用Sand，不拼长循环。合并声道若抵消先检查/选单声道。
2. 每条峰值上限-9dBFS（只减不把本来很弱的样本硬放大），不加长混响。走/跑共用6条；跑播放pitch约1.05，走1.0；初试播放器walk -18dB、run -15dB，音量均受Master控制。最终响度/鞋底质感待听审。
3. 使用技术阶段观察节点的实际落脚事件；顺序轮换六变体、避免立即重复，不新增材质系统或落地音。落脚须同时在地面/有行进意图/真实水平位移/允许操作，读L3受击状态排除滑行。开始/换向/走跑切换最小防抖，不为赶帧补播一串。
4. 独立小声部（建议2个以内）随Player/关卡释放，不占DemoAudio关键世界池；暂停冻结/菜单完成复活静音/切场释放。各关启用条件通过本地回调传入，不改共享player、状态机或地图。

## 重组A/B：两种各自完整，不叠播

- 两款均0.60s，重组信号0s起声；末尾收敛并在约0.52–0.60s轻落定。峰值≤-6dBFS，首尾0/无削波，不改变REASSEMBLE_TIME。
- **A倒放汇聚（本轮默认试装）**：从现重石裂有效碎块段选约0.40–0.50s倒序，与很短低中频石落定衔接到0.60s；不整段1.12s倍速，不带倒放前置静尾，不把原首下砸反成末端大爆炸。落定层可沿用已核Kenney impactMining_000的小段，记录源/裁点/增益。
- **B独立滑移（仅试听备选）**：pauliuw源0.558s可不变速铺入0.60s，首尾淡化并轻落定；不加A的倒放主层，保持两方案可辨。不因质心低宣称主观效果更好。
- 默认A的依据是设计语义：让玩家把碎裂与同一石体的逆向汇聚关联，**不是已听出A比B好**。用户可从页面选择B再局部换流；运行时只A。
- 仅改`l3_audio.gd`的重组路径/必要音量，保留其余charge/slam/float；只`reassembly_started`一次，教学等待/末次死亡不播，暂停冻结、重试和切场不残留。

## 最小交付与验证

- 唯一工程续同会话完成派生/三关脚步绑定/重组A试装/B留试听；assets新目录随运行文件保存license/作者链接/源SHA/裁点/新SHA/证据，credits只追加。研究、旧音乐、旧音与before只读。
- `previews/audio_movement_20261117/audition.html`本地双击：Outland参考视频定位205.5s并在213s停（明确未听辨/可能解说/仅本地参考）、当前Q“不满意/暂未替换”、石地单步及按实际节拍生成的走跑短串、重组旧/A/B。全部无autoplay、一次一条、低默认音量，不依赖常驻服务。参考视频用相对本地路径，不重复复制70MB，不抽音作素材。
- 专项只验证三关实际走跑/顶墙空中/锁定受击复活/暂停Master0/切场、重组一次与末次不响；真实正常路径与setup分标。不再跑旧214/全项目或追旧Dummy74对象。
- 本轮完成状态须分开写：脚步和重组技术已接/音色未验；Q因声音参考未听辨仍待核，不把页面可播放说成切相制作完成；BGM明确未接。不自动提交推送。
