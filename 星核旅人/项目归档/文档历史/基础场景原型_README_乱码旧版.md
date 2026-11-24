# 鏄熸牳鏃呬汉 路 鍩虹鍦烘櫙鍘熷瀷锛圙odot 4.7.2锛?
鏈伐绋嬫槸涓€涓?**鍗曞睆鍩虹鍦烘櫙 + 鍗曢敋鐐瑰€熷姏鎴?* 鐨勫彲鐩存帴杩愯鍘熷瀷锛屼娇鐢ㄧ幇鏈?`individual_sheets` 瑙掕壊绱犳潗銆佺幇鏈夎嚜鍒舵姢绗︾壒鏁堝拰 Szadi 鍙ら仐杩瑰浘鍧楋紝楠岃瘉锛?
- A/D 鎴栨柟鍚戦敭榛樿 **walk**锛涙寜浣忓乏 Shift 鎴?0.25 s 鍐呭悓鏂瑰悜鍙屽嚮杩涘叆 **run**锛涚┖鏍艰烦璺冦€佹甯搁噸鍔?鍔犲噺閫熴€?.1 s 璺宠穬瀹归敊锛?- idle / walk / run / jump / fall / fall_loop 鐨勭姸鎬佸垏鎹笌鑴氬簳绋冲畾锛?- 鎶ょ鎸?**姣忎釜鍔ㄤ綔鐨勬瘡涓€甯?* 鍖归厤鑳稿彛锛屽乏鍙宠浆鍚戞椂瑙掕壊/鍏夋檿/鎶ょ/鎵╂暎鐜竴璧烽暅鍍忥紝澶撮《鏍囧織鍜?HUD 涓嶉暅鍍忥紱
- Q 閲?闈掓瀬鎬у垏鎹€? 甯ц剦鍔ㄥ厜鏅曘€?.2 s 鍗曟鎵╂暎鐜€侀暱鎸変笉杩炲彂銆佸揩閫熷垏鎹笉绱Н鑺傜偣锛?- 骞冲彴/鐭樁纰版挒銆佽惤鍧戦噸缃€丷 閲嶇疆銆丒sc 鏆傚仠銆佽竟鐣岄檺鍒躲€佸彸涓嬭鍔ㄤ綔鐘舵€佷笌 F3 璋冭瘯锛?- **F2 杩涘叆/閫€鍑哄崟閿氱偣鍊熷姏鎴?*锛氬浐瀹氭鏋佺鏂囩煶銆佸紓鍙峰惛寮?鍚屽彿鎺掓枼銆佹湁闄愯寖鍥淬€佸疄浣撻伄鎸°€佽繎璺濆钩婊戙€侀€熷害涓婇檺銆佹殏鍋滃喕缁撳拰鎴块棿閲嶇疆锛?- 鍊熷姏鎴跨殑瀹為檯璺嚎鍜屽け璐ユ仮澶嶏細鏅€氳窇璺宠法涓嶈繃 224 px 鏂ˉ锛決鈫扖YAN 鍚稿紩銆佽秺杩囩鏂囩煶鍚?Q鈫扜OLD 寮瑰皠鍒板彸渚у钀界偣锛涘け璐ヨ惤鍧戣嚜鍔ㄩ噸鐢燂紝R 闅忔椂閲嶈瘯銆?
**鏄庣‘涓嶅湪鏈師鍨嬪唴**锛氭槦鏍搞€佹帹鎷?杩愯緭銆佺煶搴с€侀棬銆佷笁鍏炽€佽彍鍗?缁撶畻銆佹垬鏂椼€佽儗鍖呫€佸瓨妗ｃ€侀煶棰戙€傚€熷姏鎴挎槸鐙珛鍙帺鐨勫崟閿氱偣璇曢獙锛屼笉鏄畬鏁翠笁鍏筹紱閿氱偣鍙槸搴曞骇锛屼笉鍖呭惈鍙Щ鍔ㄦ牳蹇冦€?
**Q 鍦ㄥ熀纭€鍦烘櫙浠嶅彧鏀瑰彉鎶ょ/HUD 澶栬锛涜繘鍏ュ€熷姏鎴垮悗锛孮 鎵嶉┍鍔ㄧ湡瀹炵殑鍚稿紩/鎺掓枼鍔涘満銆?*

---

## 1. 鍚姩

Godot 鐗堟湰锛?*4.7.2 stable**锛堟湰鏈?`D:\Godot\Godot_v4.7.2-stable_win64_console.exe` / GUI 鍚屽悕鏃?`_console`锛夈€?
鐩存帴鐢?GUI 鍚姩锛?
```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷"
```

鎴栧湪 Godot 4.7.2 涓墦寮€ `鍩虹鍦烘櫙鍘熷瀷/project.godot`锛屾寜 F5銆備富鍦烘櫙涓?`res://scenes/main.tscn`銆?
> 璇存槑锛氬湴褰?`TileMapLayer`銆佽儗鏅垎灞傚拰 HUD 閮藉湪杩愯鏃剁敱鑴氭湰鏋勫缓锛涘湪缂栬緫鍣ㄩ噷闈欐€佹墦寮€ `main.tscn` 鏃跺彲鑳藉彧鐪嬪埌绌鸿妭鐐?鍗犱綅鑺傜偣锛岃繖鏄甯哥殑銆傛寜 F5 杩愯鍗冲彲鐪嬪埌瀹屾暣鍦烘櫙銆傛埅鍥句笌娴嬭瘯鍧囬拡瀵硅繍琛屽悗鐨勫満鏅€?
鏄剧ず璁剧疆锛?*閫昏緫 640脳360銆佸垵濮嬬獥鍙?1280脳720銆乣viewport` 鎷変几銆丯earest銆?D 鍍忕礌鍚搁檮**銆傝繖浜涜缃湪 `project.godot` 涓紝骞剁敱娴嬭瘯鏂█銆?
鏃?exe 瀵煎嚭锛氭湰鏈?`C:\Users\aqiqiqi\AppData\Roaming\Godot\export_templates` 涓虹┖锛屾病鏈?`windows_release_x86_64.exe` 鎴栧尮閰嶇殑 4.7.2 export templates銆傚洜姝?*鏈鍑?Windows exe**锛屼篃娌℃湁涓嬭浇/瀹夎妯℃澘銆傝濂藉尮閰嶆ā鏉垮悗鍙湪 Godot 涓坊鍔?Windows 瀵煎嚭棰勮锛涙湰杞氦浠樼殑鏄彲杩愯婧愬伐绋嬨€?
---

## 2. 鎿嶄綔

| 閿?| 鍔熻兘 |
|---|---|
| A / D 鎴?鈫?/ 鈫?| 榛樿 **walk**锛堢害 100 px/s锛夛紱鏈夊湴闈?绌轰腑鍔犲噺閫?|
| 宸?Shift + 鏂瑰悜 | **run**锛堢害 160 px/s锛夛紱鍙湪绉诲姩閫斾腑鎸変笅锛屾澗寮€绔嬪嵆鍥?walk锛堥櫎闈炲弻鍑婚攣瀛橈級 |
| 0.25 s 鍐呭弻鍑诲悓涓€鏂瑰悜 + 绗簩娆℃寜浣?| **run** 閿佸瓨锛涙澗寮€鏂瑰悜鎴栨崲鍚戝彇娑?|
| 鍙?Shift | **涓嶈Е鍙?run**锛堝彧璁ゅ乏 Shift 鐨?`KEY_LOCATION_LEFT`锛?|
| Space | 璺宠穬锛涚害 0.1 s coyote time + 绾?0.1 s jump buffer |
| Q | 鍒囨崲 GOLD (+) / CYAN (鈭?锛涙寜涓嬭Е鍙戯紝闀挎寜涓嶈繛鍙戯紱鍦ㄥ€熷姏鎴垮唴鐪熷疄鏀瑰彉鍚稿紩/鎺掓枼鏂瑰悜 |
| R | 閲嶇疆鍒板綋鍓嶆埧闂村嚭鐢熺偣锛涙仮澶?GOLD銆乮dle銆侀€熷害 0銆佺幆闅愯棌銆佽緭鍏ラ攣瀛樻竻鐞嗐€佸€熷姏鎴挎垚鍔熺姸鎬佹竻闄?|
| Esc | 鏆傚仠/缁х画锛涙殏鍋滆鐩栧眰鏄剧ず `PAUSED / ESC RESUME`锛涢敋鐐瑰姏鍦哄拰 HUD 鐘舵€佷竴璧峰喕缁?|
| F3 | 寮€鍏宠皟璇曪細鍩虹鎴挎樉绀鸿兏鍙ｉ敋鐐瑰崄瀛椼€?2脳30 纰版挒妗嗐€丠UD 閿氱偣琛岋紱鍊熷姏鎴块澶栨樉绀?160 px 鑼冨洿鍦堛€佷腑蹇冭繛绾裤€佸姏鏂瑰悜绠ご |
| F2 | 杩涘叆/閫€鍑哄崟閿氱偣鍊熷姏鎴匡紱鍐嶆鎸夎繑鍥炲熀纭€鍦烘櫙锛屼袱涓埧闂村悇鑷仮澶嶅嚭鐢熺偣鍜岀鎾?|

鍙屽嚮/Shift 缁嗗垯锛?
- 鍙湪 **0.25 s** 鍐呫€?*鍚屼竴鏂瑰悜** 鐨勪袱娆″畬鏁存寜涓嬩箣闂磋Е鍙戯紱绗簩娆″繀椤荤户缁寜浣忋€?- A 涓?鈫?褰掍负宸︼紝D 涓?鈫?褰掍负鍙筹紱**鍚屾椂鎸変綇绛変环閿?* 涓嶇畻绗簩娆℃寜涓嬶紝蹇呴』涓€娆″畬鍏ㄩ噴鏀惧悗鍐嶆寜涓嬨€?- 閿洏闀挎寜浜х敓鐨?`echo` 浜嬩欢鍏ㄩ儴蹇界暐锛屼笉浼氬綋绗簩鍑汇€?- 鏉惧紑鏂瑰悜鎴栨崲鍚戠珛鍗冲彇娑堝弻鍑?run锛涘弻鍑婚攣瀛樺悗鏉惧紑宸?Shift 浠嶄繚鎸?run锛堣繖鏄€滈潪鍙屽嚮妯″紡鎵嶅洖 walk鈥濈殑渚嬪锛夈€?- 鏆傚仠銆丷/钀藉潙閲嶇疆銆佺獥鍙ｅけ鐒﹂兘浼氭竻闄ゅ弻鍑诲巻鍙插拰 Shift/濂旇窇閿佸瓨锛涘鏋滄柟鍚戦敭浠嶆寜鐫€锛屾仮澶嶅悗鍙蛋 walk锛屼笉浼氳璺戙€?- 杈撳叆閫氳繃 `Main._input()` 杞彂鐪熷疄 `InputEventKey`锛屾鏌?`location` 涓?`echo`锛涙病鏈変娇鐢ㄤ笉鍖哄垎宸﹀彸 Shift 鐨勯€氱敤 `KEY_SHIFT` action锛涜嚜鍔ㄦ祴璇曠洿鎺ユ瀯閫犲甫 location/echo 鐨?`InputEventKey`銆?
鎺夊嚭娴嬭瘯鍖猴紙y > 400锛変細鑷姩閲嶇疆鍒板嚭鐢熺偣锛孒UD 鏄剧ず `FELL - RESPAWNED`銆?HUD 鏁呮剰浣跨敤娓呮櫚 ASCII 鑻辨枃锛岄伩鍏嶇郴缁熺己灏戜腑鏂囧瓧褰紱涓枃璇存槑鍦ㄦ湰 README 鍜屾枃妗ｄ腑銆?
---

## 3. 鍦烘櫙涓庢瘮渚?
閫昏緫鐢婚潰 640脳360锛屽崟灞忓浐瀹氶暅澶淬€傚湴褰㈣瑙夋潵鑷?Szadi `main_lev_buildA.png` 鐨勪竴涓?12脳2銆?6 px 鐨勬淳鐢熷浘鍧楁潯锛岀鎾炵敱 `main.gd` 鏄惧紡鐭╁舰鎻愪緵锛?*涓嶆槸鎶婁綔鑰呯ず渚嬫暣鍥惧綋纰版挒鍦板浘**銆?
| 鍖哄煙 | 椤堕儴 y | x 鑼冨洿 | 璇存槑 |
|---|---:|---|---|
| 宸︿晶鍦伴潰 | 288 | 0..416 | 鍑虹敓鐐瑰湪 (80,288) |
| 涓棿钀藉潙 | 鈥?| 416..496 | 80 px 瀹芥棤鍦伴潰锛涘彲娴嬭瘯鎺夊嚭閲嶇疆 |
| 鍙充晶鍦伴潰 | 288 | 496..640 | 浠?B 骞冲彴鎴栧潙璺冲埌鍙充晶 |
| 鐭樁 | 272 | 144..208 | 16 px 楂橈紝鍙烦涓?|
| 娴彴 A | 224 | 240..336 | 96脳16锛涗粠鐭樁璺充笂 |
| 娴彴 B | 192 | 368..464 | 96脳16锛涗粠 A 璺充笂锛屾偓鍦ㄥ潙涓婃柟 |

- 纰版挒鍏?5 涓?`StaticBody2D` + `RectangleShape2D`锛岄《閮ㄤ笌鍥惧潡椤惰竟瀵归綈锛涘叏閮ㄧ敱 headless 娴嬭瘯楠岃瘉绔欑珛楂樺害銆?- 瑙掕壊纰版挒浣?**12脳30**锛屾牴鑺傜偣鍦ㄨ剼搴曪紱128脳128 鍘熷抚鐢诲竷涓嶅弬涓庣鎾炪€傝鑹插彲瑙佽韩浣撶害 **33鈥?8 px** 楂橈紙idle/walk/run 甯х殑 alpha bbox 楂樺害锛夛紝涓?16 px 鍦板舰姣斾緥鍗忚皟銆?- 鍦烘櫙杈圭晫 clamp 鍒?x=6..634锛岄槻姝㈣窇鍑烘埧闂达紱鎺夊嚭涓嬫柟鍒欑敱 y>400 閲嶇疆銆?- 鑳屾櫙鏄綆瀵规瘮缁勫悎锛氫唬鐮佺敓鎴愬ぉ绌烘笎鍙?闆?浜戝甫 + Szadi `background2/4` 鏌撹壊鍓奖銆傚畠浠彧鏄儗鏅眰锛屾病鏈夌鎾炪€傛病鏈夋壘鍒颁笓闂ㄧ殑浜戞捣鑳屾櫙锛屾寜浠诲姟鍏佽閲囩敤绠€娲佷綆瀵规瘮缁勫悎锛屾病鏈夎姳鏃堕棿閲嶇敾銆?- 瑙掕壊/鍦板舰/鑳屾櫙鎴浘瑙?`screenshots/`锛涙敞鎰?01鈥?0 鏄姞鍏?walk 涔嬪墠鐨勬棫鐗堟埅鍥撅紝21鈥?2 鏄柊鐗?walk 鎴浘銆?
---

## 4. 绉诲姩銆佸姩鐢讳笌鐗╃悊

鍥哄畾鐗╃悊姝?**60 Hz**锛屽弬鏁伴泦涓湪 `scripts/player.gd`锛?
- 閲嶅姏 `1100 px/s虏`锛屾渶澶т笅钀?`850 px/s`锛泈alk `100 px/s`銆乺un `160 px/s`锛涘湴闈㈠姞閫?鍑忛€?`900/1250`锛涚┖涓?`650/180`銆?- 璺宠穬鍒濋€?`-375 px/s`锛屾棤浜屾璺筹紱`floor_snap_length=4`銆?- `coyote=0.10 s`銆乣jump_buffer=0.10 s`锛涗袱鑰呭潎瀹為檯娴嬭瘯銆?- 绌轰腑閫熷害鎸夊綋鍓?walk/run 鎰忓浘鍙栫洰鏍囧€硷紱绌轰腑涓嶅垏 walk/run 鍔ㄧ敾锛屼粛鏄?jump/fall/fall_loop銆?- 鐘舵€佺敱鐗╃悊/杈撳叆鎰忓浘鍐冲畾锛屼笉鐢卞姩鐢诲畬鎴愪簨浠跺喅瀹氾細
  - 鍦伴潰鏈夋柟鍚戣緭鍏ワ細run 鎰忓浘 鈫?`run`锛屽惁鍒?`walk`锛?  - 鍦伴潰鏃犺緭鍏ヤ絾浠嶅湪鍑忛€燂細鐭椂 `walk`锛屽仠涓嬪悗 `idle`锛?  - 绂诲湴涓婂崌 鈫?`jump`锛?  - 涓嬮檷 鈫?`fall` 鎾竴娆★紝瓒呰繃 fall 鏃堕暱鍚?鈫?`fall_loop` 寰幆锛?  - 钀藉湴绔嬪嵆 `idle/walk/run`锛屼笉浼氭畫鐣?`fall`銆?- 鍔ㄧ敾鍙湪鐘舵€佹敼鍙樻椂鍒囨崲/閲嶇疆锛涘悓涓€鐘舵€佸唴涓嶄細姣忎釜鐗╃悊甯ч噸鎾€俙_anim_restart_count` 娴嬭瘯瑕嗙洊銆?- 甯ф暟锛歩dle 10銆亀alk 10銆乺un 10銆乯ump 6銆乫all 4銆乫all_loop 3锛泈alk 绾?9 FPS銆?- 鑴氬簳锛歩dle/walk 10 甯х殑婧愬抚 alpha 搴曡竟閮藉湪 y=79锛?-based锛夛紝杩愯鏃朵互 `PIVOT_X=59, FRAME_BOTTOM=79` 瀵归綈鑴氬簳锛沨eadless 娴嬭瘯纭绔欑珛 1 s 涓嶆紓绉汇€?- 閲嶇疆锛氫綅缃€侀€熷害 0銆丟OLD銆乮dle 绗?0 甯с€佺幆闅愯棌銆佸厜鏅曠浉浣嶉噸缃€佹湞鍚戝彸銆丼hift/鍙屽嚮閿佸瓨娓呯悊銆?- 鏆傚仠锛歚get_tree().paused=true`锛涚帺瀹?涓栫晫 PAUSABLE锛孒UD/鏆傚仠灞?ALWAYS锛涚幆/鍏夋檿鍦ㄦ殏鍋滄椂鍐荤粨锛岀户缁悗瀹屾垚鍓╀綑鏃堕暱銆?- 澶辩劍锛歚Window.focus_exited` 鈫?娓呯悊鍙屽嚮鍘嗗彶鍜?Shift 閿佸瓨锛涙柟鍚戦敭鑻ヤ粛鎸変綇锛屾仮澶嶄负 walk銆?
### 4.1 鍗曢敋鐐瑰€熷姏鎴匡紙F2锛?
鎸?F2 鍦ㄥ熀纭€鎴垮拰鍊熷姏鎴夸箣闂村垏鎹紱涓ゆ埧鍏辩敤鍚屼竴涓?Player/HUD锛屼絾鍚勮嚜鏈夌嫭绔嬪嚭鐢熺偣銆佸湴褰㈢鎾炲拰 Force 鐘舵€併€傚熀纭€鎴跨殑 100/160 琛岃蛋/濂旇窇銆佽烦璺冨€笺€佸姩鐢汇€佹姢绗﹀拰鍘?200 鏉℃柇瑷€淇濇寔鏈夋晥锛涘€熷姏鎴垮彧澧炲姞涓€鏉＄嫭绔嬬殑鍔涘満閫氶亾锛堝師 InputMap 鏂█浠呰ˉ鍏?F2 缁戝畾锛夈€?
鎴块棿鏁版嵁锛坄scripts/anchor_room.gd`锛夛細

| 椤?| 鍊?|
|---|---|
| 閫昏緫鐢婚潰 | 640脳360 |
| 璧峰鍙?| x 0..176锛岄《 y=288 |
| 鏂ˉ | x 176..400锛屽 224 px锛涗笅鏂?y>400 鑷姩閲嶇敓 |
| 瀹借惤鐐?| x 400..640锛岄《 y=336锛屽 240 px |
| 绗︽枃鐭?| 灞呬腑 (320, 200)锛岀▼搴忕粯鍒?28脳28 鐭冲潡 + 閲戣壊鍔犲彿锛屾棤瀹炰綋纰版挒 |
| 浣滅敤鑼冨洿 | 160 px锛堜粠韬綋涓績鍒扮煶蹇冿級 |
| 鍔涜“鍑?| 16 px 鍐呭钩婊戝埌 0锛?6..52 px 娓愬己锛涘鍥?40 px 娓愬急鍒?0 |
| 鍔涘ぇ灏?| 婊″己搴?2400 px/s虏锛涢噸鍔涗粛涓?1100 px/s虏 |
| 閫熷害涓婇檺 | 鍊熷姏姘村钩 320 px/s锛涘€熷姏鍚戜笂 500 px/s锛涗笅钀戒粛灏侀《 850 |
| 鏋佹€?| 鍥哄畾姝ｆ瀬锛涚帺瀹?GOLD 鍚屽彿鈫扲EPEL锛孋YAN 寮傚彿鈫扐TTRACT |
| 閬尅 | 韬綋涓績鍒扮煶蹇冪殑鐗╃悊灏勭嚎锛屽懡涓?layer 1 瀹炰綋鍒?BLOCKED銆佸姏涓?0 |
| 璋冭瘯 | F3 鐢昏寖鍥村湀銆佷腑蹇冭繛绾裤€佸姏鏂瑰悜绠ご锛汬UD 甯告樉鐪熷疄 ATTRACT/REPEL/OUT OF RANGE/BLOCKED锛屾垚鍔熸í骞呯嫭绔嬫樉绀?|

瑙勫垯涓庤竟鐣岋細

- 鍔涙槸**姣忕墿鐞嗗抚涓€娆?*鐨勫姞閫熷害锛岀敱 `AnchorRoom` 鍦?`process_priority=-10` 鍏堢畻锛孭layer 鍦ㄦ湰甯?`move_and_slide` 鍓嶆秷璐癸紱涓嶆槸鏂扮Щ鍔ㄧ姸鎬併€佷笉鏄紶閫併€佷笉鏄嚜鍔ㄥ垏鎹€?- 鍔涘彲浠ュ厠鏈嶉噸鍔涳紙婊″己搴?2400 > 1100锛夛紱姘村钩杈撳叆涓嶈兘鎶婂€熸潵鐨勯珮閫熸姽鍥?160/100锛氭湁澶栧姏涓斿凡鏈夐€熷害瓒呰繃 walk 鏃讹紝鍙厑璁稿悓鍚戝姞閫燂紝涓嶆墽琛屽弽鍚?鍑忛€燂紱绂诲紑鍔涘満鍚庢仮澶嶆櫘閫氱┖涓帶鍒躲€傛祴璇曞悓鏃堕獙璇佲€滄湁澶栧姏淇濇寔 300 px/s鈥濆拰鈥滄棤澶栧姏 8 甯у悗浠嶄細鍑忓埌 240 浠ヤ笅鈥濄€?- 闆惰窛鍜?16 px 鍐呭畨鍏細鏂瑰悜涓嶅綊涓€鍖栧埌 NaN锛屽姏娓愰浂锛屼笉浼氬湪鐭冲績鎶栧姩銆?- 鏆傚仠鍐荤粨 Player銆丄nchorRoom 鍜?HUD 鐨勫満鐘舵€侊紱R 鎭㈠ GOLD銆佸嚭鐢熺偣銆乮dle銆侀€熷害 0銆佹垚鍔熺姸鎬佸拰 HUD锛涜惤鍧戝悓鏍峰畬鏁存仮澶嶏紝鏃犵敓鍛芥鏁?鍊掕鏃躲€?- 绗︽枃鐭冲彧鏄浐瀹氶敋鐐癸紝涓嶆斁澶ф姢绗︺€佷笉浜х敓瀹炰綋纰版挒锛涗复鏃剁編鏈紝鏈€缁堝瑙傚欢鍚庛€?
瀹為檯璺嚎鍜岄獙璇侊紙鍏ㄩ儴涓哄浐瀹?60 Hz 鐗╃悊锛屼笉鏄彧绠楀叕寮忥級锛?
1. 鎸?F2 杩涘叆鍊熷姏鎴匡紝鍑虹敓 GOLD锛圤UT OF RANGE锛夈€?2. 鎸?Q 鍙?CYAN锛堝惛寮曪級锛涙寜 D+宸?Shift 璧疯烦鍚戞柇妗ワ紝淇濇寔鍚戝彸銆?3. 瓒婅繃绗︽枃鐭冲悗鎸?Q 鍥?GOLD锛堟帓鏂ワ級锛岃惤鍒?x鈮?00..640 鐨勫钀界偣锛涙垚鍔熸í骞呭嚭鐜帮紝浣?HUD 浠嶆樉绀虹湡瀹?REPEL/ATTRACT/OUT OF RANGE/BLOCKED锛屽姏鍦轰笉閿佸畾銆?4. 澶辫触钀藉潙鑷姩閲嶇敓锛屾垨闅忔椂 R 閲嶈瘯銆?
鑷姩鍖栧浐瀹氳捣鐐规祴璇曪紙璧疯烦鍓嶄綅缃?x=160銆乿x=160锛夌殑 Q 浜屾鍒囨崲绐楀彛涓?**36..54 甯э紙19 甯э紝0.32 s锛?*锛涗粠鍑虹敓鐐硅繛缁窇璺崇殑娴嬭瘯鍦ㄨ捣璺冲悗绗?40 甯ф寜 Q锛岃惤鐐?x鈮?12.7銆亂鈮?35.9銆傛櫘閫氳窇璺虫渶澶?x鈮?43.6锛岀函鍚稿紩锛堝彧鎸夌涓€娆?Q銆佷笉鍐嶅垏鍥?GOLD锛夋渶澶?x鈮?71.1锛屽潎鍒颁笉浜?x=400 鐨勮惤鐐癸紱鍥犳褰撳墠甯冨眬纭疄闇€瑕佲€滃惛寮曗啋鎺掓枼鈥濈殑绗簩娆″垏鎹紝涓嶆槸鍙潬鍚稿紩銆傜獥鍙ｅ疄闄呰惤鍦ㄨ秺杩囩煶蹇冨悗鐨勪竴灏忔鏃堕棿鍐咃紱HUD 鐨?鈥淐ROSS THE STONE, THEN Q TO REPEL鈥?鍜屼笘鐣屽唴璺嚎鏍囩鏄粰浜虹殑鏃舵満鎻愮ず銆?
鎴愬姛鍚庣殑杩旂▼锛堟湰杞慨澶嶏級锛氭垚鍔熷彧璁板綍妯箙锛?*涓嶅仠鍔涖€佷笉閿?COMPLETE**锛涙垚鍔熷悗鎸?Q 绔嬪嵆鍒囨崲 CYAN 浼氭樉绀虹湡瀹炵殑 ATTRACT 骞舵柦鍔犲姏銆傚疄闄呮垚鍔熻惤鐐圭害 x=401銆乿x鈮?20锛屾畫浣欏彸閫熷害浼氭妸浜虹墿甯﹀埌鍙充晶鏇磋繙澶勶紙绾?x=466锛孒UD 浼氭樉绀?OUT OF RANGE锛夛紱鍥犳鍙鐜扮殑瀹屾暣杩旂▼鏄細

1. 鎴愬姛鍚庢澗寮€鏂瑰悜/Shift锛岃鍙抽€熷害鍦ㄥ鍙颁笂鍋滅ǔ锛堟鏃跺彲鑳藉凡鍦ㄨ寖鍥村锛夈€?2. 鎸変綇 A + 宸?Shift 璧板洖鍙充晶鍙拌竟锛堝疄娴?x鈮?02锛孒UD REPEL锛夈€?3. 鎸?Q 鍒?CYAN锛圓TTRACT锛夛紝鎸変綇 A + 宸?Shift 璧疯烦銆?4. 瓒婅繃绗︾煶鍚庢寜 Q 鍒?GOLD锛涘疄娴嬭捣璺冲悗绗?**10..31 甯?*锛?2 甯?0.37 s锛夊彲钀藉洖宸︿晶鍙帮紝鎶芥牱 10/21/31 鐨勮惤鐐?x鈮?9.6/28.7/161.7銆亂鈮?87.9锛屽潎鏃犻噸缃紱绗?5 甯у拰绗?36 甯уけ璐ワ紙钀藉潙閲嶇疆锛夈€?
杩旂▼鍏ㄧ▼鏈敼閿氱偣浣嶇疆銆?60 px 鑼冨洿銆?400 鍔涖€佸钩鍙伴珮搴︽垨绉诲姩鍙傛暟銆傛垚鍔熷悗鐨勫嵆鎸?Q 浼氱湡瀹炲惛寮曪紝浣嗕汉鐗╀粛鍙楄惤鍙版畫浣欏彸閫熷害褰卞搷锛涜瀹屾垚杩旂▼闇€鍏堣蛋鍥炲彴杈瑰啀璧疯烦銆傛垚鍔熸í骞呭湪杩旂▼涓繚鐣欍€?
鍊熷姏鎴垮綋鍓嶆病鏈夎璁℃案涔呴伄鎸＄墿锛汢LOCKED 瑙勫垯鐢ㄦ祴璇曚复鏃跺姞鍏ョ殑瀹炰綋鍧楅獙璇侊紙鐪熷疄鐗╃悊灏勭嚎銆佺湡瀹為浂鍔?HUD 鍙嶉锛夈€侳3 鑼冨洿鍦堝拰鍔涚澶磋 `screenshots/anchor_02_field_debug.png`銆?
---

## 5. 閫愬抚鎶ょ涓庢瀬鎬?
### 5.1 閿氱偣

`scripts/player.gd` 涓殑鏄惧紡鏁扮粍锛?
- `IDLE_ANCHORS`锛?0锛?- `WALK_ANCHORS`锛?0锛?- `RUN_ANCHORS`锛?0锛?- `JUMP_ANCHORS`锛?锛?- `FALL_ANCHORS`锛?锛?- `FALL_LOOP_ANCHORS`锛?锛?
鍏?**43 甯?*锛屽抚鍙?0-based锛涘畬鏁村潗鏍囪〃瑙?`docs/ANCHOR_TABLE.md`銆傚畾浣嶆柟娉曪細

1. 瀹為檯瑁佸垏骞舵斁澶ф鏌ユ瘡涓?128脳128 甯х殑鑳哥敳娴呰摑鐧藉儚绱狅紱
2. 鍙栬兏鐢蹭腑蹇冧负閿氱偣锛屼笉閲囩敤鏁磋韩 bbox 涓績鎴?idle 鍥哄畾浣嶇疆锛?3. 鐢?`docs/anchor_audit.png`锛堟簮甯?+ 瀹為檯鎶ょ/鍏夋檿鍙犲姞锛屾槑纭爣娉ㄤ笉鏄紩鎿庢埅鍥撅級閫愬抚瑙嗚澶嶆牳锛?4. headless 娴嬭瘯鎵弿姣忓抚閿氱偣鍍忕礌锛?*43/43** 鏄笉閫忔槑鑳哥敳鑹诧紝0 涓惤鍦ㄥ洿宸炬磱绾?鐨偆锛沬dle/walk 鑴氬簳鍩虹嚎涓€鑷达紱idle/walk/run 鍙楂樺害 33鈥?8 px锛泈alk 閿氱偣涓?run 閿氱偣涓嶅悓銆?
### 5.2 鍙犳斁涓庨暅鍍?
浠ラ敋鐐?`(x,y)` 涓哄抚鍐呭潗鏍囥€乣centered=false` 鐨勬暣鏁?top-left锛?
| 灞?| 甯у昂瀵?| top-left | z锛圴isualRoot 鍐咃級 |
|---|---|---|---|
| Glow 鍏夋檿 | 11脳11 脳4 甯?| `(x-5, y-5)` | -1锛堣鑹插悗锛?|
| Talisman 鎶ょ | 5脳5 | `(x-2, y-2)` | 1锛堣鑹插墠锛?|
| SwitchRing 鎵╂暎鐜?| 24脳24 脳4 甯?| `(x-12, y-12)` | 2锛堢煭鏃讹級 |
| CharacterSprite | 128脳128 | 甯х敾甯冭剼搴曞榻?| 0 |
| 澶撮《 +/鈭?| 浠ｇ爜缁樺埗 | Player 鏍逛笅 | 6锛圥layer 涓嬶紝涓嶅湪 VisualRoot锛?|

- `VisualRoot.scale.x` 闅忔湞鍚?卤1锛涜鑹层€佸厜鏅曘€佹姢绗︺€佺幆閮藉湪鍏朵笅锛屾墍浠ヤ綅缃?绾圭悊涓€璧烽暅鍍忋€倃alk/run 鐨勬姢绗︺€佸厜鏅曘€佺幆 X 闀滃儚閮借娴嬭瘯銆?- 澶撮《 +/鈭?鏍囧織鍜?HUD 涓嶅湪 VisualRoot 涓嬶紝涓嶉暅鍍忥紱鍙充笅 HUD 鏄?CanvasLayer銆?- 鍏夋檿鍦ㄨ鑹插悗闈紝涓嶄細鎶婅劯銆佸洿宸炬垨鑳哥敳澶ч潰绉煋鑹诧紱鎶ょ浠?5脳5 鍙犲湪鑳哥敳涓婏紱鎵╂暎鐜槸 24脳24 鐨勭粏绾匡紝鎸佺画绾?0.2 s锛屼笉鏄叏灞?澶ч潰绉壊鍧椼€?- 宸查獙璇?idle/walk/run/jump/fall/fall_loop锛涙湭浣跨敤 combo/design 鎴栨敾鍑诲姩浣溿€?
### 5.3 鍏夋檿涓庢墿鏁ｇ幆

- 鍏夋檿锛? 甯с€? FPS銆佸惊鐜紱绾圭悊 44脳11 = 4脳11脳11锛涢噾/闈掍袱寮犵汗鐞嗗垏鎹€?- 鎵╂暎鐜細4 甯с€?0 FPS銆?*鍗曟 0.20 s**锛?6脳24 = 4脳24脳24锛涙挱瀹岄殣钘忋€?- 鍙湁涓€涓?`SwitchRing` 鑺傜偣锛涜繛缁揩閫熸寜 Q 浼氫粠澶撮噸鎾綋鍓嶆瀬鎬х殑鐜紝涓嶆柊澧炶妭鐐癸紱闀挎寜 2 s 鍙垏鎹竴娆★紙娴嬭瘯楠岃瘉锛夈€傚熀纭€鎴挎病鏈夐敋鐐规椂锛孮 浠嶅彧鏀瑰彉瑙嗚涓?HUD锛涜繘鍏ュ€熷姏鎴垮悗锛孮 鍚屾椂椹卞姩鐪熷疄鐨勫惛寮?鎺掓枼鍔涘満锛堣 4.1锛夈€?
---

## 6. HUD銆佹殏鍋溿€侀噸缃?
- 椤堕儴锛氭爣棰樸€佷袱琛屾搷浣滄彁绀猴紙`WALK / L-SHIFT: RUN / DOUBLE-TAP: RUN / SPACE: JUMP` 绛夛級銆乣POLARITY` 闈㈡澘锛圙OLD + 閲戣壊 / CYAN 鈭?闈掕壊锛夛紱鍩虹鎴挎彁绀?`F2: ANCHOR ROOM`锛屽€熷姏鎴挎彁绀?`F2: BASE ROOM`銆?- 鍩虹鎴垮彸涓嬶細`STATE ... FRAME n/total`銆丗LOOR/VX/VY锛汧3 鎵撳紑鍚庢樉绀哄綋鍓嶈兏鍙ｉ敋鐐瑰拰 12脳30 纰版挒銆傞潰鏉垮湪瑙掕壊鑴氬簳浠ヤ笅锛屼笉閬鑹层€?- 鍊熷姏鎴匡細鍙充笅鐘舵€侀潰鏉块殣钘忥紝搴曢儴宸︿晶鏄剧ず `ANCHOR TRIAL` 鍦虹姸鎬侊紙鐪熷疄 ATTRACT/REPEL/OUT OF RANGE/BLOCKED銆佽窛绂汇€佸姏鍒嗛噺锛夊拰璺嚎鎻愮ず锛涙垚鍔熸椂椤堕儴鏄剧ず `DESTINATION REACHED - R: RETRY / F2: BASE` 妯箙锛屽満鐘舵€佷笉琚?COMPLETE 閬洊銆?- 鏆傚仠锛欵sc 璁剧疆 `get_tree().paused`锛屾樉绀哄眳涓鐩栧眰锛涚墿鐞?鍔ㄧ敾/鎶ょ/鐜?閿氱偣鍦哄拰鍦虹姸鎬佸喕缁擄紱Esc 鍐嶆寜缁х画銆?- 閲嶇疆锛歊 鎴栬惤鍧戯紱鎭㈠褰撳墠鎴块棿鍑虹敓鐐广€侀€熷害銆佹瀬鎬с€乮dle銆佺幆闅愯棌銆佸厜鏅曠浉浣嶃€佹湞鍚戙€佽緭鍏ラ攣瀛樻竻鐞嗭紱鍊熷姏鎴垮悓鏃舵竻闄ゆ垚鍔熺姸鎬佸拰妯箙銆?- 鎺夊潙娴嬭瘯鍖猴細鍩虹鎴夸腑澶?80 px 缂哄彛锛寉>400 鑷姩閲嶇疆锛汬UD 鐭殏鏄剧ず `FELL - RESPAWNED`銆傚€熷姏鎴挎柇妗ヤ笅鏂瑰悓鏍?y>400 閲嶇敓銆?- 甯у彿锛欻UD 鐢?1-based 渚夸簬闃呰锛涗唬鐮?娴嬭瘯/鎴浘鏍囩/閿氱偣琛ㄧ敤 0-based銆傛埅鍥?README 宸茶鏄庛€?
---

## 7. 娴嬭瘯涓庡疄娴嬬粨鏋?
### 7.1 涓€閿鐜?
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷\tests\run_tests.ps1"
```

鐩存帴杩愯锛堜笌鑴氭湰绛変环锛夛細

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit --path "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷"
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷" res://tests/test_runner.tscn
```

### 7.2 鏈瀹為檯缁撴灉

- Godot锛歚4.7.2.stable.official.ed1daf0bf`
- Headless 瀵煎叆锛氶€€鍑虹爜 0锛屾棩蹇?`tests/logs/headless_import.log`
- 娴嬭瘯锛?*314 PASS / 0 FAIL**锛岄€€鍑虹爜 **0**锛堝師鍩虹鍦烘櫙 200 鏉?+ 鍊熷姏鎴?114 鏉★級
- 娴嬭瘯鏃ュ織锛歚tests/logs/headless_test.log`銆乣tests/logs/last_run.log`
- 鏇剧粡鍦ㄦ殏鍋滆緭鍏ユ祴璇曞け璐ユ椂瀹為檯杩斿洖杩囬€€鍑虹爜 **1**锛屼慨姝ｅ悗褰撳墠涓?0锛涙祴璇曞叆鍙ｄ笉鏄€滃彧鎵撳嵃 PASS鈥濄€?- 娴嬭瘯浣跨敤鐪熷疄鍦烘櫙 + 鐪熷疄 `InputEventKey`锛堝惈宸﹀彸 Shift `location`銆乣echo`锛? 鐗╃悊甯ф杩涳紱鍘?200 鏉¤鐩栵細
  - 640脳360 / 1280脳720 / viewport stretch / Nearest / 60 Hz锛汚/D銆佹柟鍚戙€丼pace銆丵銆丷銆丒sc銆丗3銆丗2 鐨?InputMap 鐗╃悊閿紱
  - 鍑虹敓銆?2脳30 纰版挒銆乮dle 鑴氬簳 1 s 绋冲畾锛?  - 6 涓?sheet 甯ф暟銆? 涓敋鐐规暟缁勯暱搴︺€?3/43 閿氱偣鍍忕礌銆乮dle/walk 鑴氬簳鍩虹嚎銆乮dle/walk/run 鍙楂樺害銆亀alk 涓?run 閿氱偣涓嶅悓锛?  - 榛樿鍙抽敭/宸﹂敭 walk銆亀alk 100 鐩爣閫熷害銆亀alk 涓嶉€愬抚閲嶆挱銆佸姞鍑忛€熷洖 idle锛?  - 宸?Shift 绉诲姩閫斾腑鎸変笅銆佹澗寮€绔嬪嵆鍥?walk锛汼hift 鍏堟寜涔熺敓鏁堬紱鍙?Shift 浣嶇疆涓嶈Е鍙戯紱run 160 鐩爣閫熷害锛?  - 鍚屾柟鍚戝弻鍑?0.25 s 閿佸瓨 run锛涜秴鏃躲€佸乏鍙充氦鏇裤€佺瓑浠烽敭鍚屾椂鎸夈€乪cho銆佹澗寮€鏂瑰悜銆佹崲鍚戝彇娑堬紱
  - 鍙屽嚮閿佸瓨鍚庢澗寮€宸?Shift 浠?run锛?  - 鏆傚仠/閲嶇疆/澶辩劍娓呯悊鍙屽嚮鍘嗗彶鍜?Shift 閿佸瓨锛屾仮澶嶅悗鏂瑰悜浠嶆寜浣忎篃鍙?walk锛?  - 绌轰腑 walk/run 鎰忓浘 target speed锛岀┖涓粛 jump/fall锛屼笉鍒?walk/run锛?  - jump/fall/fall_loop銆侀暱涓嬭惤銆佽惤鍦扮珛鍗?idle銆佹棤 fall 娈嬬暀锛?  - 鐭樁/骞冲彴 A/B/鍙充晶鍦伴潰椤堕儴纰版挒銆佸钩鍙扮珯绔嬶紱
  - 鎺夊潙閲嶇疆锛堜綅缃?閫熷害/鏋佹€?鐜?鍔ㄧ敾锛夛紱
  - Q 鍒囨崲閲?闈掔汗鐞嗐€丠UD銆? 甯у厜鏅曟帹杩涖€佺幆 0.2 s 闅愯棌銆侀暱鎸夊彧 1 娆°€佸揩閫?5 娆′笉绱Н鑺傜偣锛決 涓嶉噸缃Щ鍔ㄧ姸鎬侊紱
  - R 閲嶇疆鍏ㄩ儴鐘舵€侊紱coyote + jump buffer 瀹為檯璧疯烦锛?  - 杈圭晫 clamp锛汦sc 鏆傚仠/缁х画銆佹殏鍋滄椂鐗╃悊鍜岀幆鍐荤粨銆丗3 璋冭瘯锛?  - 灞傜骇椤哄簭 glow < body < talisman < ring < badge銆?- 鍊熷姏鎴挎柊澧?114 鏉¤鐩栵細
  - F2 杩涘叆/閫€鍑恒€佷袱鎴跨鎾炲紑鍏炽€侀敋鐐规埧鐙珛鍑虹敓鐐广€丠UD 妯″紡鍒囨崲銆丗2 鐗╃悊閿紱
  - 鍥哄畾姝ｆ瀬涓?CYAN 鍚稿紩 / GOLD 鎺掓枼鐨勫姏鏂瑰悜銆佽寖鍥村闆跺姏銆侀浂璺?杩戣窛瀹夊叏銆佸姏鍏嬫湇閲嶅姏銆佺湡瀹炰笂娴紱
  - 瀹炰綋閬尅锛堜复鏃?StaticBody 涓績杩炵嚎锛夈€佺Щ闄ゅ悗鎭㈠锛涢€熷害 320 涓婇檺锛涙湁澶栧姏淇濇寔 300 鎯€т笌鏃犲鍔涙甯稿噺閫熺殑瀵圭収锛?  - 椤堕儴/宸﹀彸杈圭晫锛涙殏鍋滄椂浣嶇疆銆侀€熷害銆佸満鐘舵€佸拰 HUD 鍐荤粨锛汻 鎭㈠鍑虹敓銆丟OLD銆侀€熷害鍜屾垚鍔熺姸鎬侊紱
  - 鏅€氳窇璺冲け璐ワ紙max x鈮?43.6锛岃惤鍧戦噸鐢燂級銆佸彧鍚稿紩涓嶅垏鎹㈠け璐ワ紙max x鈮?71.1锛夛紱
  - 浜屾鍒囨崲绐楀彛鎵弿锛?6..54 甯э紝19 甯?0.32 s锛夈€佸疄闄呰惤鐐广€佹垚鍔熸í骞呫€佹垚鍔熷悗鍦虹姸鎬佷粛涓虹湡瀹?REPEL銆佹垚鍔熷悗 Q鈫扐TTRACT 涓旂湡瀹炴柦鍔涳紱
  - 浠庡嚭鐢熺偣杩炵画璺戣烦 + 璧疯烦鍚庣 40 甯?Q 鐨勫畬鏁磋矾绾匡紱
  - 鎴愬姛杩旂▼锛氬厛鍋滅ǔ/璧板洖鍙充晶鍙拌竟锛孮鈫扐TTRACT 璧疯烦锛岃捣璺冲悗绗?10..31 甯?Q鈫扜OLD锛涙娊鏍?10/21/31 钀藉洖宸﹀彴锛坸鈮?9.6/28.7/161.7锛屾棤閲嶇疆锛夛紝5/36 澶辫触銆?
### 7.3 GUI

- 宸茬敤鐪熷疄 GUI 绐楀彛鍚姩涓诲満鏅紝纭椤圭洰鍙繍琛屻€丠UD/鑳屾櫙/骞冲彴/瑙掕壊鍙锛岀獥鍙ｆ寜 1280脳720 鏄剧ず锛涘熀纭€鍦烘櫙椤堕儴鍙 `F2: ANCHOR ROOM` 鎻愮ず銆?- 鍊熷姏鎴挎埅鍥剧敱 `tools/capture_anchor.tscn` 鍦ㄧ湡瀹?GUI 绐楀彛涓墦寮€鍚屼竴涓诲満鏅苟娓叉煋锛? 寮犲畾甯?+ 2 寮犺剼鏈墿鐞嗚繍琛岄潤甯э紱涓嶆槸鎵嬪伐杩炵画璇曠帺褰曞儚銆?- 瀹屾暣閿洏娴佺▼鏈仛閫愰」浜哄伐璇曠帺璁板綍锛汧2銆丵銆丏/Shift銆丼pace 绛夌殑瀹為檯琛屼负鐢?headless 鐪熷疄杈撳叆/鐗╃悊姝ヨ繘瑕嗙洊銆傚崗璋冭€呭彲鎸夌 10 鑺傚湪 GUI 涓鏍搞€?- 瀹為檯閿洏宸?Shift 鐨?OS location 鏄惁涓庡悎鎴愪簨浠朵竴鑷达紝寤鸿鍗忚皟鑰呭湪 GUI 涓寜涓€娆″乏/鍙?Shift 澶嶆牳锛涘疄鐜颁娇鐢?`KEY_LOCATION_LEFT`锛屽彸 Shift 鏄庣‘蹇界暐銆?
### 7.4 鎴浘

```powershell
# 鍘熸湁鍩虹鍦烘櫙 01-22锛堥粯璁ゅ彧琛?21/22锛?powershell -NoProfile -ExecutionPolicy Bypass -File "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷\tools\capture_screenshots.ps1"

# 鍊熷姏鎴?4 寮狅紙鐪熷疄 GUI + 鏍硅鍙ｆ崟鑾凤級
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\鏄熸牳鏃呬汉\鍩虹鍦烘櫙鍘熷瀷" res://tools/capture_anchor.tscn
```

- `screenshots/` 鍘熸湁 **22 寮犲熀纭€鍦烘櫙 640脳360 鏍硅鍙ｆ崟鑾?*锛?1鈥?0 legacy銆?1鈥?2 walk锛夛紝鏈疆鏂板 **4 寮犲€熷姏鎴挎崟鑾?*锛?  - `anchor_01_entry.png`锛欶2 杩涘叆鍚庣殑鎴块棿銆佽捣濮嬪彴銆佺鏂囩煶銆佸钀界偣鍜?HUD 寮曞锛堝畾甯э級锛?  - `anchor_02_field_debug.png`锛欳YAN 鍚稿紩濮挎€?+ F3 鑼冨洿鍦堛€佷腑蹇冭繛绾裤€佸姏绠ご锛堝畾甯э級锛?  - `anchor_03_attract_run.png`锛氳剼鏈墿鐞嗚繍琛屼腑璺宠捣/鍚稿紩鐨勯潤甯э紱
  - `anchor_04_success.png`锛氳剼鏈墿鐞嗚繍琛岃惤鍒板钀界偣锛屾垚鍔熸í骞?COMPLETE锛堥潤甯э級銆?- `MANIFEST_ANCHOR.txt` 璁板綍姣忓紶鐨勬ā寮忥紙`FIXED POSE` 鎴?`SCRIPTED RUN`锛夈€佸弬鏁板拰鑴氭湰杈撳叆搴忓垪锛涜繖浜涜繍琛岄潤甯т笉鏄棰戯紝杩炵画琛屼负鐢?301 鏉℃柇瑷€瑕嗙洊銆?- `MANIFEST.txt`銆乣MANIFEST_WALK.txt` 璁板綍鍘熸湁鍩虹鎴挎崟鑾凤紱`CONTACT_SHEET.png` 鏄緝鏃╃殑渚垮埄鎷煎浘锛屾湭闅?F2 鎻愮ず鍜屽€熷姏鎴挎洿鏂帮紝鏌ョ湅褰撳墠 HUD 璇蜂互鍘熷 21/22 鍜?`anchor_*` 涓哄噯銆?- `docs/anchor_audit.png` 鏄簮甯?+ 鎶ょ鍙犲姞鐨?43 甯ч敋鐐瑰璁″浘锛?*涓嶆槸寮曟搸鎴浘**锛涘€熷姏鎴跨収鐗囨槸鐪熷疄涓诲満鏅覆鏌擄紝浣嗗畾甯?鑴氭湰杩愯杈圭晫宸插湪鏍囩鍜?manifest 涓啓鏄庛€?
---

## 8. 鍏抽敭鏂囦欢

```text
鍩虹鍦烘櫙鍘熷瀷/
鈹溾攢 project.godot                  # 640x360 / 1280x720 / viewport / nearest / 60Hz
鈹溾攢 scenes/
鈹? 鈹溾攢 main.tscn                   # 涓诲満鏅細鑳屾櫙銆佷笘鐣屻€乀ileMapLayer銆丳layer銆丄nchorRoom銆丠UD
鈹? 鈹斺攢 player.tscn                 # CharacterBody2D + 瑙嗚/鎶ょ/鐜?鏍囧織鑺傜偣
鈹溾攢 scripts/
鈹? 鈹溾攢 main.gd                     # 鍩虹鎴跨鎾?鍦板舰銆丗2 鍒囨埧銆丠UD/鏆傚仠/澶辩劍/鎸夐敭杞彂
鈹? 鈹溾攢 anchor_room.gd              # 鍊熷姏鎴垮湴褰€佸浐瀹氶敋鐐广€佽寖鍥?閬尅/鍔?鎴愬姛涓庣粯鍒?鈹? 鈹溾攢 player.gd                   # 鐗╃悊銆亀alk/run/鍙屽嚮銆?3 涓€愬抚閿氱偣銆佹瀬鎬?澶栧姏/闄愰€?鈹? 鈹溾攢 hud.gd                      # 鑻辨枃 HUD銆佸熀纭€/鍊熷姏鎴挎ā寮忋€佸満鐘舵€併€佹殏鍋滆鐩?鈹? 鈹溾攢 background.gd               # 澶╃┖/鍓奖/浜戝甫/闆惧垎灞?鈹? 鈹溾攢 input_setup.gd              # 杩愯鏃?InputMap 娉ㄥ唽锛堝惈 F2锛涗笉鍚€氱敤 Shift action锛?鈹? 鈹溾攢 debug_overlay.gd            # F3 鑳稿彛鍗佸瓧/纰版挒妗?鈹? 鈹斺攢 polarity_badge.gd           # 澶撮《 +/鈭掞紙涓嶉暅鍍忥級
鈹溾攢 assets/                        # 澶嶅埗/娲剧敓璧勪骇锛涜 ASSET_CREDITS.md
鈹溾攢 tests/
鈹? 鈹溾攢 test_runner.tscn/.gd        # 301 鏂█ headless 楠屾敹
鈹? 鈹溾攢 run_tests.ps1               # 瀵煎叆 + 娴嬭瘯 + 鏃ュ織锛屽け璐ラ潪 0
鈹? 鈹斺攢 logs/                       # 瀹為檯娴嬭瘯/瀵煎叆/鎹曡幏鏃ュ織
鈹溾攢 tools/
鈹? 鈹溾攢 capture_screenshots.tscn/.gd
鈹? 鈹溾攢 capture_screenshots.ps1
鈹? 鈹溾攢 capture_anchor.tscn/.gd     # 鍊熷姏鎴?4 寮犵湡瀹炲紩鎿庢崟鑾?鈹溾攢 screenshots/                   # 22 寮犲熀纭€鎴?+ 4 寮犻敋鐐规埧瀹為檯鎹曡幏 + manifests
鈹溾攢 docs/
鈹? 鈹溾攢 anchor_audit.png            # 43 甯ф簮甯у彔鍔犲璁★紙闈炲紩鎿庢埅鍥撅級
鈹? 鈹斺攢 ANCHOR_TABLE.md             # 43 涓敋鐐瑰畬鏁磋〃
鈹溾攢 README.md
鈹斺攢 ASSET_CREDITS.md
```

婧愮礌鏉?`individual_sheets/`銆乣绱犳潗搴?`銆乣鑷埗绱犳潗/`銆乣agent.md`銆佺瓥鍒掍功鍧囨湭鏀瑰姩锛涘彧鍚?`assets/` 澶嶅埗浜嗚繍琛屾墍闇€鏂囦欢锛堟柊澧?`male_hero-walk.png`锛夈€傛湭淇敼涓婄骇 git 浠撳簱鍏朵粬椤圭洰/鍒嗘敮锛屾湭鎻愪氦 commit銆?
---

## 9. 宸茬煡闄愬埗銆佹湭楠岃瘉椤逛笌璁稿彲

1. **瑙掕壊璁稿彲鏈煡**锛歚individual_sheets` 娌℃湁浣滆€?璁稿彲鏂囨湰銆傚唴閮ㄨ绋嬪師鍨嬪彲缁х画娴嬭瘯锛涘澶栧彂甯冨墠蹇呴』琛ラ綈鎺堟潈銆傝瑙?`assets/characters/LICENSE_UNKNOWN.txt` 涓?`ASSET_CREDITS.md`銆?2. **娌℃湁 Windows exe**锛氭湰鏈烘病鏈夊尮閰嶇殑 Godot 4.7.2 export templates锛屾湭涓嬭浇/瀹夎銆傞渶瑕佹椂瀹夎妯℃澘鍚庢坊鍔?Windows 瀵煎嚭棰勮鍗冲彲锛涜繖涓嶅簲闃荤褰撳墠婧愬伐绋嬭繍琛屻€?3. **鍊熷姏鎴挎槸鍗曢敋鐐硅瘯楠岋紝涓嶆槸瀹屾暣涓夊叧**锛氬綋鍓嶆病鏈夋槦鏍搞€佹帹鎷?杩愯緭銆佺煶搴с€侀棬銆佹牳蹇冮樆灏?閿佸畾锛涘熀纭€鎴夸粛鏄棤閿氱偣鐨勭Щ鍔?鎶ょ娴嬭瘯鍦恒€俀 鍦ㄥ熀纭€鎴垮彧鏀瑰彉澶栬锛屽湪鍊熷姏鎴挎墠椹卞姩鍔涘満銆?4. **鍔ㄤ綔鑼冨洿**锛氭湭瀹炵幇 combo/鏀诲嚮銆佹墜鏌勩€侀煶棰戙€佽彍鍗曘€佷笁鍏炽€佸瓨妗ｃ€佺粨绠楋紱run 鍙敱宸?Shift/鍚屾柟鍚戝弻鍑昏Е鍙戙€?5. **鑳屾櫙**锛氭病鏈変笓鐢ㄤ簯娴风礌鏉愶紱浣跨敤 Szadi 鐨勫壀褰?+ 浠ｇ爜澶╃┖/闆?浜戝甫浣庡姣旂粍鍚堬紝骞堕潪鏈€缁堢編鏈€備綔鑰呴瑙?鏁村浘娌℃湁浣滀负纰版挒鍦板浘銆?6. **鎵╂暎鐜彲瑙佸害**锛?4脳24 缁嗙嚎鍦?640脳360 涓嬭緝缁嗭紱`17/18` 鎴浘鏀惧ぇ鍚庡彲鐪嬫竻銆傛寔缁?0.2 s锛岀鍚堣鏍笺€?7. **楠岃瘉鑼冨洿**锛氳涓烘祴璇曚负 headless 鐪熷疄鐗╃悊/杈撳叆锛汫UI 宸茬‘璁ゅ熀纭€鍦烘櫙鍚姩/娓叉煋锛屽苟鐢ㄧ湡瀹?GUI 鐨勬崟鑾峰満鏅覆鏌撳€熷姏鎴?4 寮犲浘銆傛湭鍋氬紓鏈恒€?K/闈炴暣鏁扮缉鏀俱€佹墜鏌勩€佷汉宸ヨ繛缁畬鏁磋瘯鐜╋紱瀹為檯宸?鍙?Shift 鐨?OS location 寤鸿鍗忚皟鑰呭湪 GUI 澶嶆牳銆傜獥鍙ｆ斁澶т娇鐢?viewport+nearest锛屾湭楠岃瘉 4K銆?8. **鎴浘涓嶆槸瀹炴椂褰曞儚**锛氬師鏈?01鈥?2 鏄?`show_showcase()` 鍐荤粨鐗瑰啓锛沗anchor_01/02` 鏄畾甯э紝`anchor_03/04` 鏄剼鏈墿鐞嗚繍琛岄潤甯э紙鐪熷疄杈撳叆/鐗╃悊锛屼絾涓嶆槸瑙嗛锛夈€傝繛缁涓虹敱 301 鏉℃祴璇曡鐩栥€?1鈥?0 鏄?pre-walk legacy锛屼笉鑳戒唬琛ㄥ綋鍓嶉粯璁ゆ帶鍒躲€?9. **鍊熷姏鎴块伄鎸?*锛氭棤姘镐箙閬尅鐗╋紱BLOCKED 鐢辨祴璇曚复鏃跺疄浣撳潡楠岃瘉銆傛寮忓叧鍗￠渶瑕佽璁¤嚜鐒堕伄鎸＄偣浣嶃€?10. **涓存椂缇庢湳**锛?8 px 绗︽枃鐭炽€侀噾鑹插姞鍙蜂负绋嬪簭缁樺埗锛涜惤鐐?璧风偣浠嶆槸鐜版湁 Szadi 鍥惧潡銆傛渶缁堢煶鍧椼€佺鏂囧拰鎴块棿缇庢湳寤跺悗銆?
> 鏈枃浠舵槸褰撳墠鏈夋晥璇存槑锛涙棫鐨?walk 鍓嶅悗鎴浘涓庢祴璇曟暟瀛楀凡鍦ㄤ笂鏂囨爣娓咃紝涓嶅啀绱Н涓烘湰杞巻鍙层€?
---

## 10. 鍗忚皟鑰呴獙鏀舵楠?
1. 杩愯 `tests/run_tests.ps1`锛岀‘璁?**314 PASS / 0 FAIL** / 閫€鍑虹爜 0锛涙煡鐪?`tests/logs/headless_test.log`锛岄噸鐐规牳瀵?`ANCHOR` 鍚勮妭鍜?`Q switch window` 琛屻€?2. 鎵撳紑 `screenshots/anchor_01_entry.png`銆乣anchor_02_field_debug.png`銆乣anchor_03_attract_run.png`銆乣anchor_04_success.png`锛氭鏌ヨ捣濮嬪彴/鏂ˉ/瀹借惤鐐广€?8 px 涓存椂绗︽枃鐭炽€丠UD 寮曞銆丗3 鑼冨洿鍦?鍔涚澶淬€佹垚鍔熸í骞呫€傛敞鎰?`anchor_01/02` 鏄畾甯э紝`anchor_03/04` 鏄剼鏈墿鐞嗚繍琛岄潤甯э紝涓嶆槸褰曞儚銆?3. 鎵撳紑 `screenshots/21_walk_right_gold.png`銆乣22_walk_left_cyan.png`锛氭鏌ラ粯璁?walk銆佸乏鍙抽暅鍍忋€侀噾/闈掓姢绗︺€佸熀纭€鎴?HUD 鐨?`L-SHIFT: RUN / DOUBLE-TAP: RUN / F2: ANCHOR ROOM`銆?4. 鎵撳紑鏃?`screenshots/01`鈥揱16`锛坙egacy pre-walk锛夋鏌?idle/run/jump/fall 鐨勬姢绗﹀嚑浣曪紱`17`/`18` 鐪嬬幆锛宍19` 鐪嬮敋鐐?12脳30 纰版挒锛宍20` 鐪嬫殏鍋溿€傛敞鎰忚繖浜涙棫鍥?HUD 鏃?Shift锛屼笉浠ｈ〃褰撳墠榛樿鎺у埗銆?5. 瀵圭収 `docs/ANCHOR_TABLE.md` 涓?`docs/anchor_audit.png`锛屾牳瀵?43 涓€愬抚閿氱偣锛堝惈 walk 10 甯э級銆?6. GUI 鍚姩锛氶粯璁ゆ寜 D 搴斾负 walk锛涙寜宸?Shift 鍙?run锛屾澗寮€鍥?walk锛?.25 s 鍐呰繛鎸?D 绗簩娆℃寜浣忓簲鍙?run锛涘彸 Shift 涓嶅簲鍙?run锛涙殏鍋?閲嶇疆/澶辩劍鍚庢仮澶嶄笉搴旇璺戯紱鍐嶅鏍?Space銆丵銆丷銆丒sc銆丗3銆佽惤鍧戦噸缃€傛寜 F2 杩涘€熷姏鎴匡細Q鈫扖YAN 鍚庤烦鍚戞柇妗ワ紝瓒婅繃绗︽枃鐭冲啀 Q鈫扜OLD锛岃惤涓婂彸渚у鍙帮紱澶辫触钀藉潙/鎸?R 閲嶈瘯銆?7. 璁板綍浠嶅瓨鍦ㄧ殑璁稿彲璇佷笌 export templates 闃诲锛涗笉瑕佸湪娌℃湁瑙掕壊鎺堟潈鐨勬儏鍐典笅瀵瑰鍙戝竷銆?
## 11. 楠屾敹瀵圭収

| 瑕佹眰 | 瀹炵幇/璇佹嵁 |
|---|---|
| 榛樿 A/D/鏂瑰悜 walk锛涘乏 Shift/鍙屽嚮 run | `player.gd` + 200 鏉″師鍩虹娴嬭瘯 MOVEMENT / DOUBLE-TAP锛涙埅鍥?21/22 |
| 鍙屽嚮 0.25 s銆佺浜屾鎸変綇銆佽秴鏃?浜ゆ浛/閲婃斁/鎹㈠悜鍙栨秷 | 鍙屽嚮娴嬭瘯锛涘疄闄?`InputEventKey` |
| 鍙?Shift 涓嶈Е鍙戙€佸乏 Shift location銆乪cho 涓嶇畻绗簩鍑?| 宸﹀彸 Shift location 涓?echo 娴嬭瘯 |
| 绛変环閿?A/鈫愩€丏/鈫?鍚岀粍锛屽悓鏃舵寜浣忎笉瑙﹀彂 | 绛変环閿祴璇?|
| 鏆傚仠/閲嶇疆/澶辩劍娓呯悊锛屼笉璇窇 | SPRINT CLEANUP 娴嬭瘯 |
| 绌轰腑鎸夋剰鍥惧彉閫熴€佹棤鏂扮┖涓姩鐢?| AIR SPEED INTENT 娴嬭瘯 |
| 鍥哄畾鐗╃悊姝ャ€侀噸鍔涖€佸姞鍑忛€熴€?.1 s 瀹归敊 | 60 Hz锛沜oyote + buffer 娴嬭瘯 |
| 骞冲彴涓婄珯銆佽竟鐣屻€佽惤鍧戦噸缃€丷銆丒sc | 5 涓煩褰㈢鎾?杈圭晫 clamp/钀藉潙娴嬭瘯/R & 鏆傚仠娴嬭瘯 |
| Q 閲?闈掋€? 甯у厜鏅曘€?.2 s 鐜€侀暱鎸変笉杩炲彂銆佸揩閫熶笉绱Н | 绾圭悊/HUD/鐜椂闀?鑺傜偣鏁?闀挎寜 120 甯?蹇€?5 娆℃祴璇?|
| 閫愬抚鑳稿彛閿氱偣銆佸乏鍙抽暅鍍忋€佸ご椤?HUD 涓嶉暅鍍?| 43 甯ф暟缁?+ 43/43 鍍忕礌娴嬭瘯 + 闀滃儚娴嬭瘯 + 瀹¤鍥?|
| 灞傜骇绋冲畾銆佷笉澶ч潰绉煋鑴?鍥村肪 | glow z=-1銆乼alisman z=1銆乺ing z=2锛涘厜鏅曞湪韬悗锛涢敋鐐逛腑蹇冧笉鍦ㄥ洿宸?鐨偆 |
| 椤堕儴鎻愮ず/鏋佹€с€佸彸涓嬬姸鎬併€丗3 | HUD + 鎴浘 21/22 鍙?legacy 01鈥?0/19/20锛汧3 娴嬭瘯 |
| F2 杩?鍑哄€熷姏鎴裤€佷繚鐣欏熀纭€鎴垮拰 200 鏂█ | F2 鐪熷疄 InputMap + 涓ゆ埧纰版挒寮€鍏虫祴璇曪紱301 閫氳繃 |
| 鍥哄畾姝ｆ瀬銆佸悓鍙锋枼/寮傚彿鍚搞€佽寖鍥?閬尅/闆惰窛/闄愰€?| ANCHOR FIELD / LOS / SPEED CAP 娴嬭瘯锛汧3 鎴浘 |
| 鍔涘厠鏈嶉噸鍔涖€佹按骞宠緭鍏ヤ笉鎶规帀鎯€?| 瀹為檯涓婃诞娴嬭瘯锛涙湁/鏃犲鍔涚殑 300 px/s 瀵圭収 |
| 鏅€氳窇璺冲埌涓嶄簡銆佸€熷姏鍙揪銆佺函鍚稿紩涓嶅彲杈?| 瀹為檯鐗╃悊锛氭櫘閫?max x鈮?43.6锛涚函鍚稿紩 max x鈮?71.1锛涘鍙?x鈮?00 |
| 浜屾鍒囨崲绐楀彛銆佸疄闄呰惤鐐广€佹垚鍔熷弽棣?| 36..54 甯х獥鍙?杩炵画璺戣烦绗?40 甯?Q锛涜惤鐐?x鈮?11.7锛汣OMPLETE 妯箙 |
| 鏆傚仠鍐荤粨銆丷 鎭㈠銆佽惤鍧戞仮澶嶃€佸け鐒﹁緭鍏ユ竻鐞?| ANCHOR PAUSE / RESET + 鍘?SPRINT CLEANUP 娴嬭瘯 |
| 瀹為檯 Godot 瀵煎叆/鑴氭湰瑙ｆ瀽/鏂█娴嬭瘯/鏃ュ織 | headless 瀵煎叆 + 301 鏉℃柇瑷€ + `tests/logs/` |
| 瀹為檯寮曟搸鎴浘锛屼笉棰勬覆鏌撳啋鍏?| 22 寮犲熀纭€鎴?+ 4 寮犻敋鐐规埧 `get_viewport().get_texture().get_image()` 鎹曡幏 + manifests + 瀹氬抚/鑴氭湰杩愯鏍囨敞 |
| Windows exe锛堟湁妯℃澘鎵嶅鍑猴級 | 鏈満鏃犲尮閰嶆ā鏉?鈫?鏄庣‘闃诲锛屾湭涓嬭浇 |
| 瑙掕壊璁稿彲 | 鏈煡锛屽唴閮ㄥ師鍨嬶紱README/璧勪骇璁板綍宸叉爣鏄?|


---

> 历史备份：本文件保留原乱码内容和旧实验记录，不再作为当前入口说明；新入口见 `../../README.md` 及 `../../基础场景原型/README.md`。

## Star-core bay interaction prototype (2026-10-31)

A standalone single-screen interaction sandbox is available from the normal main scene with **F4**. It uses the existing player, three-state core, star-core bay visual assets, HUD and map background. It is a sandbox for the bay loop, not a formal puzzle, door, three-level layout, anchor combination, pickup/throw system, or new polarity converter.

- F4: enter/leave the interaction room from the main scene. F2 remains the anchor room. Cross-room switches disable the other room's floor collisions, core body and external force.
- E near a loaded bay: open the lid, snapshot the core polarity as the opposite of the player's current polarity, then release after the 0.25 s lid opening. Q during opening changes only the player.
- Current release is an instantaneous `activate_at` placement at the far-side 40 px point. It is **not** a continuous ejection/slide animation; the point only keeps the core clear of the player and pedestal.
- Q: switch only the player's polarity. The released core keeps gold + or cyan -.
- Walk or run with the same/opposite sign to push/pull the core. It is capped at 120 px/s. Walking is the reliable transport; running can open a gap but does not raise the cap.
- **Storage is explicit E only.** There is no automatic capture, no speed gate, and no unkeyed slow/suction drag at a bay. HUD shows `E: STORE CORE (BAY)` only when the player is within 46 px of an empty bay, the active core is within 80 px of the player, and the core centre is inside that bay's small +/-24 x 18 px seat zone. Only then does E brake the core, align it locally (inside the seat, at most ~30 px diagonally), turn it purple, and close the lid. No polarity match is required.
- Invalid E explains itself (no active core, core too far from the player, or core not in the bay seat) and never releases or stores by mistake. E during opening/closing, held E or key echo cannot repeat the action, and one E cannot immediately re-store the core it just released.
- The empty bay stays open until an explicit E store. The start bay stays locked/purple after a release, so it can be a valid return store target; the nearest valid empty bay is selected.
- **Lid animation:** the existing 32x32 glass image is masked per pixel from the two lower sides upward along the dome arc. Closing raises both sides symmetrically and meets at the top centre last; opening removes the top centre first and descends to the sides. There is no whole `scale.y` squash and no uniform alpha fade. See `screenshots/star_core_lid_keyframes.png` (six live 4x engine instances) and `screenshots/MANIFEST_LID.txt`.
- R restores the whole interaction room (start bay locked/purple, target open/empty, one hidden moving core, player at spawn, GOLD). Esc pauses physics and lid animation. F3 draws range/centre line/force arrows and the small store seat zones.
- Target success is only a HUD hint; physics and bay interaction continue. The room stays live after the target is reached, and the core can be released and carried back.
- The heteropolar follow defect was reproduced before the change: the old automatic `_update_capture()` re-locked the just-released CYAN core into the start bay around frame 30 while the GOLD player walked right, so the core stopped following. Removing automatic capture fixed it; the manual E store replaces that mechanism. Details in `docs/STAR_CORE_INTERACTION.md`.

Run the standalone entry with:

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://scenes/star_core_interaction_standalone.tscn
```

Full design notes, exported tuning parameters, actual test results and screenshot modes are in `docs/STAR_CORE_INTERACTION.md`.

Test commands:

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_interaction.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_runner.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_visual.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_bay_visual.tscn
```

Current results: interaction test 185 pass / 0 fail; existing runner 314 pass / 0 fail; star-core visual 100 pass / 0 fail; bay visual 151 pass / 0 fail; GUI bay render pass; lid keyframe pixel check pass. See `tests/logs/` and `docs/STAR_CORE_INTERACTION.md`.

Screenshots from the real engine GUI (scripted physics stills, not human play):

- `screenshots/interaction_01_opening.png`
- `screenshots/interaction_02_transport.png`
- `screenshots/interaction_03_target_capture.png`
- `screenshots/interaction_04_target_release.png`
- `screenshots/star_core_lid_keyframes.png`
- `screenshots/MANIFEST_INTERACTION.txt`
- `screenshots/MANIFEST_LID.txt`

The interaction test uses real InputMap actions and 60 Hz physics for the full E-release / heteropolar walk / no-auto-store / manual E store / re-release / return store route. It also covers same-sign push, run boundary, both initial polarities, premature and held E, pause, R, F2/F4, single-core cleanup and body-push immunity. No manual full human playthrough is claimed.
