class_name CaptureMirrorEmblem
extends Node

## 640x360 evidence for the 2026-11-28 mirror pass.
## Run WITHOUT --headless:
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 \
##     --path . res://dlc/rift_workshop/tests/capture_mirror_emblem.tscn
##
## Saves to res://screenshots/mirror_emblem_20261128/:
##   01_mirror_gate_56px.png              new 40x64 double mirror + 56 px line
##   02_mirror_walk_ripple.png            body walking into the glass, ripple
##   03_mirror_fade_dark.png              the same entry at ~90% black
##   04_rift_first_frame_black.png        destination first frame under black
##   05_completion_mirror_emblem.png      six-page shared 32x32 mirror emblem
##   06_completion_ripple_fade.png        0.5 s ripple on the completion page
##   07_loom_return_emerge.png            back at the checkpoint, mirror ripple
##   08_defeat_mirror_flash.png           circular defeat flash, no rectangle
##   09_l3_bay_insert_flash.png           base-game bay using the shared look
##
## Every frame is the live 640x360 viewport; the entry, completion and store
## are driven by the real input/signal routes, not by direct scene changes.

const OUT_DIR: String = "res://screenshots/mirror_emblem_20261128"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_03: String = "res://scenes/level_03.tscn"
const PROGRESS: String = "user://mirror_emblem_capture.cfg"

var _saved: Array[String] = []
var _entry_commit_alpha: float = -1.0
var _completion_commit_alpha: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for tip_id: String in [
		"polarity", "core_carry", "relay_link", "float_platform",
		"rift_mirror_tip", "rift_core_tip",
	]:
		MechanicTips.mark_seen(tip_id)
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
	await _capture_gate_entry()
	await _capture_completion_and_return()
	await _capture_defeat_flash()
	await _capture_base_bay()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
	print("MIRROR_EMBLEM_CAPTURE saved=%d files=%s entry_commit_alpha=%.3f completion_commit_alpha=%.3f" % [
		_saved.size(), ", ".join(_saved), _entry_commit_alpha, _completion_commit_alpha
	])
	get_tree().quit(0 if _saved.size() == 15 else 1)


# --- 1. entrance, walk, fade, destination first frame -----------------------

func _capture_gate_entry() -> void:
	var level: Node = await _load_level(LOOM, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	var gate: MirrorRiftGate = level.call("get_hidden_rift_gate") as MirrorRiftGate
	var player: L3Player = level.call("get_player") as L3Player
	var camera: Camera2D = level.call("get_camera") as Camera2D
	var hud: LoomHUD = level.call("get_hud") as LoomHUD
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	player.face_direction(1)
	camera.reset_smoothing()
	await _wait_physics(5)
	await _wait_seconds(0.30)
	print("GATE_STATE pos=%s hint=%d event=%s cover=%.3f" % [
		str(gate.global_position), gate.get_hint_shown_count(),
		hud.get_event_text(), gate.get_cover_alpha()
	])
	await _save("01_mirror_gate_56px")
	if not gate.route_entered.is_connected(_on_route_entered):
		gate.route_entered.connect(_on_route_entered.bind(gate))
	await _press_e()
	await _wait_seconds(0.20)
	print("WALK_STATE player=%s hidden=%s ripple=%s" % [
		str(player.global_position), str(not player.visible), str(gate.is_ripple_active())
	])
	await _save("02_mirror_walk_ripple")
	await _wait_seconds(0.10)
	print("WALK_INSIDE player=%s hidden=%s" % [
		str(player.global_position), str(not player.visible)
	])
	await _save("02b_mirror_walk_inside")
	await _wait_seconds(0.50)
	print("FADE_STATE cover=%.3f entering=%s" % [
		gate.get_cover_alpha(), str(gate.is_route_entering())
	])
	await _save("03_mirror_fade_dark")
	var arrived: bool = await _wait_for_scene(RIFT, 240)
	if not arrived:
		print("CAPTURE_FAIL rift scene did not load")
		return
	# First rendered frame of the side chapter: still fully covered.
	var rift: Node = get_tree().current_scene
	var alpha: float = float(rift.call("get_mirror_black_cover_alpha"))
	print("RIFT_FIRST_FRAME black_alpha=%.3f" % alpha)
	await _save("04_rift_first_frame_black")


func _on_route_entered(_target_id: String, gate: MirrorRiftGate) -> void:
	_entry_commit_alpha = gate.get_cover_alpha()


# --- 2. completion emblem, fade, return ------------------------------------

func _capture_completion_and_return() -> void:
	var rift: Node = get_tree().current_scene
	if rift == null or not rift.has_method("get_hud"):
		print("CAPTURE_FAIL no rift for completion")
		return
	await _settle_side_intro(rift)
	rift.call("_complete_chapter")
	await _wait_process(60)
	var hud: RiftWorkshopHUD = rift.call("get_hud") as RiftWorkshopHUD
	var emblem: CompletionEmblem = hud.find_child(
		"CompletionEmblem", true, false
	) as CompletionEmblem
	print("COMPLETION emblem=%s size=%s art=%s primary=%s" % [
		str(emblem != null),
		str(emblem.size) if emblem != null else "none",
		emblem.get_art_id() if emblem != null else "none",
		hud.get_completion_primary_button().text
	])
	await _save("05_completion_mirror_emblem")
	if not hud.mainline_requested.is_connected(_on_completion_mainline):
		hud.mainline_requested.connect(_on_completion_mainline.bind(hud))
	hud.get_completion_primary_button().pressed.emit()
	await _wait_seconds(0.24)
	print("COMPLETION_FADE progress=%.3f" % _completion_fade_progress(hud))
	await _save("06_completion_ripple_fade")
	await _wait_seconds(0.18)
	print("COMPLETION_FADE_LATE progress=%.3f alpha=%.3f" % [
		_completion_fade_progress(hud), _completion_fade_alpha(hud)
	])
	await _save("06b_completion_fade_black")
	var returned: bool = await _wait_for_scene(LOOM, 240)
	if not returned:
		print("CAPTURE_FAIL loom did not return")
		return
	var loom: Node = get_tree().current_scene
	print("LOOM_FIRST_FRAME black_alpha=%.3f" % float(
		loom.call("get_mirror_black_cover_alpha")
	))
	var player: L3Player = loom.call("get_player") as L3Player
	var checkpoint: LevelCheckpoint = loom.call("get_checkpoint") as LevelCheckpoint
	var gate: MirrorRiftGate = loom.call("get_hidden_rift_gate") as MirrorRiftGate
	print("LOOM_RETURN player=%s checkpoint=%s ripple=%s" % [
		str(player.global_position), str(checkpoint.global_position),
		str(gate.is_ripple_active())
	])
	var camera: Camera2D = loom.call("get_camera") as Camera2D
	camera.reset_smoothing()
	await _wait_seconds(0.30)
	print("LOOM_EMERGE_EARLY cover=%.2f ripple=%s" % [
		float(loom.call("get_mirror_black_cover_alpha")), str(gate.is_ripple_active())
	])
	await _save("07_loom_return_emerge")
	await _wait_seconds(0.12)
	print("LOOM_EMERGE_LATE ripple=%s" % str(gate.is_ripple_active()))
	await _save("07b_loom_return_emerge_late")


func _on_completion_mainline(hud: RiftWorkshopHUD) -> void:
	var fade: CompletionMirrorFade = hud.get_completion_mirror_fade()
	_completion_commit_alpha = fade.get_cover_alpha() if fade != null else -1.0


func _completion_fade_progress(hud: RiftWorkshopHUD) -> float:
	var fade: CompletionMirrorFade = hud.get_completion_mirror_fade()
	return fade.get_progress() if fade != null else -1.0


func _completion_fade_alpha(hud: RiftWorkshopHUD) -> float:
	var fade: CompletionMirrorFade = hud.get_completion_mirror_fade()
	return fade.get_cover_alpha() if fade != null else -1.0


# --- 3. defeat flash --------------------------------------------------------

func _capture_defeat_flash() -> void:
	var level: Node = await _load_level(RIFT, func(node: Node) -> void:
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
		node.set("chapter_progress_path", PROGRESS)
	)
	if level == null:
		return
	var player: L3Player = level.call("get_player") as L3Player
	var camera: Camera2D = level.call("get_camera") as Camera2D
	var boss: RiftMirrorBoss = level.call("get_boss") as RiftMirrorBoss
	var popup: Variant = level.get("_mechanic_popup")
	if popup != null and popup.has_method("is_open") and bool(popup.call("is_open")):
		popup.call("close")
	get_tree().paused = false
	player.global_position = Vector2(1480.0, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(6)
	boss.begin_fight()
	await _wait_seconds(0.45)
	boss.debug_force_defeat()
	var flash: RiftDefeatFlash = boss.get_defeat_flash()
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and not flash.is_playing():
		await get_tree().process_frame
	if not flash.is_playing():
		print("CAPTURE_FAIL defeat flash never started")
	print("DEFEAT_FLASH playing=%s radius=%s fullscreen_rect=%s circular=%s" % [
		str(flash.is_playing()), str(flash.get_flash_radius()),
		str(flash.has_fullscreen_rect()), str(flash.is_circular_flash())
	])
	# Continuous frames: full disc -> 1/3 -> 2/3 -> gone.
	await _save("08a_defeat_flash_start")
	await _wait_seconds(0.06)
	await _save("08b_defeat_flash_mid")
	await _wait_seconds(0.06)
	await _save("08c_defeat_flash_small")
	await _wait_seconds(0.08)
	print("DEFEAT_FLASH_LATE playing=%s progress=%.2f" % [
		str(flash.is_playing()), flash.get_progress()
	])
	await _save("08d_defeat_flash_end")
	await _wait_seconds(0.20)


# --- 4. base-game bay using the shared look ---------------------------------

func _capture_base_bay() -> void:
	var level: Node = await _load_level(LEVEL_03, func(node: Node) -> void:
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	var player: L3Player = level.call("get_player") as L3Player
	var camera: Camera2D = level.call("get_camera") as Camera2D
	var start_bay: StarCoreBayInteractable = level.call("get_start_bay")
	var target_bay: StarCoreBayInteractable = level.call("get_target_bay")
	var core: StarCoreCarrier = level.get_node_or_null("Core") as StarCoreCarrier
	if player == null or start_bay == null or target_bay == null or core == null:
		print("CAPTURE_FAIL L3 bay nodes missing")
		return
	# L3's near-gate echo film owns the input until it is aborted.
	var cine: Variant = level.call("get_cine")
	if cine != null and bool(cine.call("is_active")):
		cine.call("abort")
		await _wait_process(8)
	player.global_position = Vector2(start_bay.global_position.x, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(4)
	await _press_e()
	var released: bool = await _wait_until(func() -> bool: return core.is_active(), 180)
	if not released:
		print("CAPTURE_FAIL base core did not release")
		return
	core.global_position = target_bay.get_store_center()
	player.global_position = Vector2(target_bay.global_position.x - 40.0, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(4)
	await _press_e()
	var stored: bool = await _wait_until(
		func() -> bool: return target_bay.is_closing() or target_bay.is_locked(), 60
	)
	# Step clear of the glass so the flash and sparks are the subject.
	player.global_position = Vector2(target_bay.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()
	await _wait_physics(2)
	var lit: float = float(target_bay.get_visual().get_lit_blend())
	print("BASE_BAY stored=%s lit=%.2f flash=%.2f sfx=%s" % [
		str(stored), lit, target_bay.get_visual().get_flash_left(),
		target_bay.get_visual().get_seat_sfx_path(true)
	])
	await _save("09_l3_bay_insert_flash")


# --- helpers ---------------------------------------------------------------

func _load_level(path: String, configure: Callable) -> Node:
	await _drop_scene()
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("CAPTURE_FAIL cannot load " + path)
		return null
	var level: Node = packed.instantiate()
	configure.call(level)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(10)
	await _wait_physics(6)
	return level


func _drop_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null and current != self:
		current.queue_free()
		await _wait_process(6)


func _wait_for_scene(path: String, frames: int) -> bool:
	for _index: int in range(frames):
		var current: Node = get_tree().current_scene
		if current != null and current.scene_file_path == path:
			return true
		await get_tree().process_frame
	return false


func _settle_side_intro(scene: Node) -> void:
	scene.set("show_intro_guide", false)
	var intro: Variant = scene.get("_intro_cinematic")
	if intro != null and bool(intro.call("is_active")):
		intro.call("_request_skip")
	for _index: int in range(120):
		var guide: Variant = scene.get("_intro_guide")
		if guide != null and bool(guide.call("is_open")):
			guide.call("close")
			break
		if not bool(scene.get("_intro_active")):
			break
		await get_tree().process_frame
	await _wait_process(6)


func _press_e() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_E
	down.keycode = KEY_E
	down.pressed = true
	Input.parse_input_event(down)
	await _wait_physics(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_E
	up.keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	await _wait_physics(2)


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _index: int in range(frames):
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return false


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(file_name + ".png"))
	if error == OK:
		_saved.append(file_name + ".png")
	print("SHOT %s size=%dx%d error=%d" % [
		file_name, image.get_width(), image.get_height(), error
	])
