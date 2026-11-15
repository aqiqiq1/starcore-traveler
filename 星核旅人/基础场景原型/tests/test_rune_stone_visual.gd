extends Node

## Independent acceptance test for the concept-derived rune-stone state PNGs,
## the RuneStoneVisual component, its dim-then-relight transition, pause
## freezing, and the standalone 640x360 look-dev preview.
##
## Run:
##   D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_rune_stone_visual.tscn
##
## This scene is intentionally separate from test_runner.tscn and does not
## change the existing project test suite.

const RUNE_SCENE: PackedScene = preload("res://scenes/rune_stone_visual.tscn")
const PREVIEW_SCENE: PackedScene = preload("res://tools/preview_rune_stone.tscn")

const SLEEP_PATH: String = "res://assets/rune_stone/rune_stone_sleep.png"
const GOLD_PATH: String = "res://assets/rune_stone/rune_stone_gold.png"
const CYAN_PATH: String = "res://assets/rune_stone/rune_stone_cyan.png"
const POSITIVE: Color = Color("#f4cd63")
const NEGATIVE: Color = Color("#5fe1e6")

var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _log_lines: Array[String] = []
var _transition_events: Array[bool] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_log("Star Core Traveler - independent rune-stone visual test")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"],
		DisplayServer.get_name(),
	])

	_test_project_config()
	_test_source_layers()
	await _test_component_contract()
	await _test_state_switching_and_geometry()
	await _test_transition_and_pause()
	await _test_inactive_visual_state()
	await _test_preview()
	_finish()


func _test_project_config() -> void:
	_section("PROJECT AND ASSET CONFIG")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
		"project logic viewport is 640x360"
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0,
		"project default texture filter is nearest"
	)


func _test_source_layers() -> void:
	_section("CONCEPT-DERIVED 32x32 STATE PNGS")
	var sleep_image: Image = _load_source_image(SLEEP_PATH)
	var gold_image: Image = _load_source_image(GOLD_PATH)
	var cyan_image: Image = _load_source_image(CYAN_PATH)
	_check(sleep_image != null, "sleep state PNG loads as an Image")
	_check(gold_image != null, "gold state PNG loads as an Image")
	_check(cyan_image != null, "cyan state PNG loads as an Image")
	if sleep_image == null or gold_image == null or cyan_image == null:
		return

	_check(sleep_image.get_size() == Vector2i(32, 32), "sleep source is 32x32", str(sleep_image.get_size()))
	_check(gold_image.get_size() == Vector2i(32, 32), "gold source is 32x32", str(gold_image.get_size()))
	_check(cyan_image.get_size() == Vector2i(32, 32), "cyan source is 32x32", str(cyan_image.get_size()))
	_check(sleep_image.detect_alpha() != Image.ALPHA_NONE, "sleep keeps an alpha channel")
	_check(gold_image.detect_alpha() != Image.ALPHA_NONE, "gold keeps an alpha channel")
	_check(cyan_image.detect_alpha() != Image.ALPHA_NONE, "cyan keeps an alpha channel")
	_check(
		sleep_image.get_pixel(0, 0).a8 == 0
		and sleep_image.get_pixel(31, 0).a8 == 0
		and sleep_image.get_pixel(0, 31).a8 == 0
		and sleep_image.get_pixel(31, 31).a8 == 0,
		"sleep corners are transparent"
	)

	var opaque_shell: int = 0
	for y: int in range(32):
		for x: int in range(32):
			if sleep_image.get_pixel(x, y).a8 == 255:
				opaque_shell += 1
	_check(
		opaque_shell == 535,
		"direct NEAREST of the approved 96px concept yields the expected 535 px shell",
		str(opaque_shell)
	)

	# All three in-game textures are direct NEAREST samples of the same approved
	# concept sprite silhouette; only the colour state may change.
	_check(_silhouettes_equal([sleep_image, gold_image, cyan_image]),
		"all three states share the exact same shell and crack silhouette")
	_check(_images_differ(sleep_image, gold_image) > 100,
		"gold replaces the dormant core/reflection with the concept's gold light",
		str(_images_differ(sleep_image, gold_image)))
	_check(_images_differ(sleep_image, cyan_image) > 100,
		"cyan replaces the dormant core/reflection with the concept's cyan light",
		str(_images_differ(sleep_image, cyan_image)))
	_check(_images_differ(gold_image, cyan_image) > 100,
		"gold and cyan states are clearly distinct",
		str(_images_differ(gold_image, cyan_image)))

	# The concept's lit core palette is shaded from #f4cd63 / #5fe1e6 toward a
	# hot inner highlight. Radius 55 covers that authored family at 32px.
	var sleep_gold: int = _count_near_color(sleep_image, POSITIVE, 55)
	var sleep_cyan: int = _count_near_color(sleep_image, NEGATIVE, 55)
	var gold_light: int = _count_near_color(gold_image, POSITIVE, 55)
	var cyan_light: int = _count_near_color(cyan_image, NEGATIVE, 55)
	_check(sleep_gold == 0 and sleep_cyan == 0,
		"dormant state contains no gold or cyan light",
		"gold=%d cyan=%d" % [sleep_gold, sleep_cyan])
	_check(gold_light >= 20, "gold state keeps the concept's baked gold core", str(gold_light))
	_check(cyan_light >= 20, "cyan state keeps the concept's baked cyan core", str(cyan_light))

	# The old shell + white-mask layer pair must not be silently used again.
	_check(
		not ResourceLoader.exists("res://assets/rune_stone/rune_stone_shell.png", "Texture2D")
		and not ResourceLoader.exists("res://assets/rune_stone/rune_stone_crack_mask.png", "Texture2D"),
		"legacy two-layer shell/mask textures are gone"
	)


func _test_component_contract() -> void:
	_section("COMPONENT CONTRACT")
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	add_child(stone)
	await get_tree().process_frame

	_check(stone != null, "scene instantiates as RuneStoneVisual")
	if stone == null:
		return
	_check(stone is Node2D, "component root is Node2D")
	_check(stone.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "root uses nearest filtering")
	_check(stone.get_script() != null and stone.get_script().is_tool(), "component script is @tool")
	_check(stone.get_child_count() == 2, "component owns only Base and Accent sprites")
	_check(_count_physics_nodes(stone) == 0, "component has no collision, area or physics nodes")

	var base_sprite: Sprite2D = stone.get_base_sprite()
	var accent_sprite: Sprite2D = stone.get_accent_sprite()
	_check(base_sprite != null and base_sprite.name == "Base", "Base sprite exists")
	_check(accent_sprite != null and accent_sprite.name == "Accent", "Accent sprite exists")
	for sprite: Sprite2D in [base_sprite, accent_sprite]:
		if sprite == null:
			continue
		_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s uses nearest filtering" % sprite.name)
		_check(sprite.centered and sprite.scale == Vector2.ONE, "%s is centered at 1:1" % sprite.name)
		_check(not sprite.flip_h and not sprite.flip_v and sprite.rotation == 0.0, "%s is not mirrored or rotated" % sprite.name)
	_check(base_sprite.z_index == 0 and accent_sprite.z_index == 1,
		"sleep base stays under the gold/cyan accent")

	_check(stone.polarity_positive, "default polarity is positive")
	_check(stone.is_energized(), "default visual is energized for existing callers")
	_check(stone.get_hint_kind() == &"plus", "default hint kind is plus")
	_check(not stone.show_polarity_hint, "hint is hidden by default")
	_check(is_equal_approx(stone.transition_duration, 0.22), "default transition duration is 0.22 s")
	_check(stone.get_source_size() == Vector2i(32, 32), "declared source size is 32x32")
	_check(stone.get_stone_rect() == Rect2(-16.0, -16.0, 32.0, 32.0), "stone occupies the 32x32 rect around the origin")
	_check(not stone.get_hint_rect().intersects(stone.get_stone_rect()), "hint is outside the stone body")
	_check(
		stone.get_hint_rect().position.y < stone.get_stone_rect().position.y
		and stone.get_hint_rect().position.x > stone.get_stone_rect().position.x,
		"hint floats above and right of the stone"
	)
	_check(stone.has_art(), "all three concept state PNGs load for the component")
	if stone.has_art():
		_check(Vector2i(base_sprite.texture.get_size()) == Vector2i(32, 32), "base texture is 32x32")
		_check(Vector2i(accent_sprite.texture.get_size()) == Vector2i(32, 32), "accent texture is 32x32")
		_check(base_sprite.texture == stone.get_sleep_texture(), "base shows the sleep state")
		_check(accent_sprite.texture == stone.get_state_texture(true), "settled positive accent is the gold state")
		_check(is_equal_approx(stone.get_accent_strength(), 1.0), "settled state shows the accent at full alpha")
		# Import-cache proof: compare every imported texture with the source PNG.
		_check(
			_visible_pixels_match(base_sprite.texture.get_image(), _load_source_image(SLEEP_PATH)),
			"imported sleep texture matches the source PNG",
			"cache check"
		)
		_check(
			_visible_pixels_match(stone.get_state_texture(true).get_image(), _load_source_image(GOLD_PATH)),
			"imported gold texture matches the source PNG",
			"cache check"
		)
		_check(
			_visible_pixels_match(stone.get_state_texture(false).get_image(), _load_source_image(CYAN_PATH)),
			"imported cyan texture matches the source PNG",
			"cache check"
		)
		_check(stone.get_displayed_color().is_equal_approx(POSITIVE), "settled positive colour is #f4cd63")
		_check(base_sprite.modulate == Color.WHITE, "base keeps its concept colours")
		_check(accent_sprite.modulate.r == 1.0 and accent_sprite.modulate.g == 1.0
			and accent_sprite.modulate.b == 1.0 and is_equal_approx(accent_sprite.modulate.a, 1.0),
			"accent keeps its concept colours at full alpha")

	var exported: Dictionary = {}
	for property: Dictionary in stone.get_property_list():
		if str(property.name) in ["polarity_positive", "energized", "show_polarity_hint", "transition_duration"]:
			exported[str(property.name)] = property
			_check(
				(int(property.usage) & PROPERTY_USAGE_EDITOR) != 0,
				"%s is exposed to the inspector" % property.name
			)
	_check(exported.size() == 4, "all four interface properties are present", str(exported.keys()))
	_check(stone.has_signal("transition_finished"), "transition_finished signal is declared")
	var signal_info: Dictionary = {}
	for info: Dictionary in stone.get_signal_list():
		if str(info.name) == "transition_finished":
			signal_info = info
	var signal_args: Array = signal_info.get("args", [])
	_check(
		signal_args.size() == 1 and str(signal_args[0].get("name", "")) == "positive",
		"transition_finished carries one positive argument"
	)
	_check(stone.has_method("set_polarity"), "public set_polarity method exists")
	_check(not stone.is_processing(), "settled component does not run an autonomous process")

	stone.queue_free()
	await get_tree().process_frame


func _test_state_switching_and_geometry() -> void:
	_section("STATE SWITCH AND FIXED STONE")
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	add_child(stone)
	await get_tree().process_frame
	_transition_events.clear()
	stone.transition_finished.connect(_on_transition_finished)

	var base_sprite: Sprite2D = stone.get_base_sprite()
	var accent_sprite: Sprite2D = stone.get_accent_sprite()
	var base_texture: Texture2D = base_sprite.texture
	var gold_texture: Texture2D = stone.get_state_texture(true)
	var cyan_texture: Texture2D = stone.get_state_texture(false)
	var start_position: Vector2 = stone.position
	var start_rotation: float = stone.rotation
	var start_scale: Vector2 = stone.scale
	var start_base_position: Vector2 = base_sprite.position
	var start_base_rotation: float = base_sprite.rotation
	var start_accent_position: Vector2 = accent_sprite.position
	var start_accent_rotation: float = accent_sprite.rotation

	stone.show_polarity_hint = true
	_check(stone.get_hint_kind() == &"plus", "positive state uses a small plus hint")
	_check(not stone.get_hint_rect().intersects(stone.get_stone_rect()), "plus hint stays outside the stone")

	stone.set_polarity(false, true)
	_check(not stone.polarity_positive and not stone.get_applied_positive(), "immediate negative switches state")
	_check(stone.get_displayed_color().is_equal_approx(NEGATIVE), "immediate negative shows #5fe1e6")
	_check(accent_sprite.texture == cyan_texture, "immediate negative shows the concept cyan state")
	_check(is_equal_approx(stone.get_accent_strength(), 1.0), "immediate negative shows the accent fully")
	_check(not stone.is_transitioning(), "immediate change does not leave a transition running")
	_check(_transition_events.is_empty(), "immediate change emits no transition_finished signal")
	_check(stone.get_hint_kind() == &"minus", "negative state uses a small minus hint")
	_check(base_sprite.texture == base_texture, "negative state reuses the exact sleep base texture")
	_check(base_texture == stone.get_sleep_texture(), "sleep base is the approved dormant state")
	_check(stone.position == start_position and stone.rotation == start_rotation and stone.scale == start_scale, "stone transform is fixed")
	_check(
		base_sprite.position == start_base_position
		and base_sprite.rotation == start_base_rotation
		and accent_sprite.position == start_accent_position
		and accent_sprite.rotation == start_accent_rotation,
		"layer transforms stay fixed across polarity"
	)
	_check(base_sprite.modulate == Color.WHITE, "only the accent state changes; sleep base is untouched")

	stone.set_polarity(false, false)
	_check(not stone.is_transitioning() and _transition_events.is_empty(), "same-state non-immediate call is a no-op")

	stone.set_polarity(true, true)
	_check(stone.polarity_positive and stone.get_applied_positive(), "immediate positive restores the gold state")
	_check(stone.get_displayed_color().is_equal_approx(POSITIVE), "restored positive colour is #f4cd63")
	_check(accent_sprite.texture == gold_texture, "immediate positive shows the concept gold state")
	_check(stone.get_hint_kind() == &"plus", "hint returns to plus")
	_check(_transition_events.is_empty(), "restoring positive immediate still emits no signal")

	stone.show_polarity_hint = false
	_check(not stone.show_polarity_hint, "hint can be switched off again")

	stone.queue_free()
	await get_tree().process_frame


func _test_transition_and_pause() -> void:
	_section("TRANSITION, PAUSE AND SIGNAL")
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	add_child(stone)
	await get_tree().process_frame
	_transition_events.clear()
	stone.transition_finished.connect(_on_transition_finished)

	var base_sprite: Sprite2D = stone.get_base_sprite()
	var accent_sprite: Sprite2D = stone.get_accent_sprite()
	var base_texture: Texture2D = base_sprite.texture
	var gold_texture: Texture2D = stone.get_state_texture(true)
	var cyan_texture: Texture2D = stone.get_state_texture(false)
	var start_base_transform: Transform2D = base_sprite.transform
	var start_accent_transform: Transform2D = accent_sprite.transform
	var start_stone_transform: Transform2D = stone.transform

	stone.set_polarity(false, false)
	_check(stone.is_transitioning(), "non-immediate switch starts a transition")
	_check(stone.polarity_positive == false, "target polarity is negative immediately")
	_check(stone.get_applied_positive(), "applied polarity is still positive until the transition ends")
	_check(_transition_events.is_empty(), "transition does not finish synchronously")
	_check(stone.is_processing(), "active transition enables process")
	_check(accent_sprite.texture == gold_texture and is_equal_approx(stone.get_accent_strength(), 1.0),
		"transition starts from the old full gold accent")

	var duration: float = stone.transition_duration
	stone.advance_transition(duration * 0.20)
	var dim_color: Color = stone.get_displayed_color()
	var dim_alpha: float = stone.get_accent_strength()
	_check(stone.get_transition_progress() > 0.15 and stone.get_transition_progress() < 0.30, "first fifth reaches the dim phase")
	_check(dim_color.r < POSITIVE.r and dim_color.g < POSITIVE.g and dim_color.b < POSITIVE.b, "old gold light gets darker first")
	_check(maxf(dim_color.r, maxf(dim_color.g, dim_color.b)) < 0.60, "dim phase is visibly subdued")
	_check(dim_alpha < 0.80 and dim_alpha > 0.05, "old gold accent fades instead of switching instantly", str(dim_alpha))
	_check(accent_sprite.texture == gold_texture, "dim phase keeps the old gold state image")
	_check(base_sprite.modulate == Color.WHITE, "transition never tints the sleep base")
	_check(base_sprite.texture == base_texture, "transition keeps the sleep base texture")
	_check(base_sprite.transform == start_base_transform, "transition does not move the base")
	_check(accent_sprite.transform == start_accent_transform, "transition does not move the accent")
	_check(stone.transform == start_stone_transform, "transition does not rotate or move the stone")

	var paused_elapsed: float = stone.get_transition_elapsed()
	var paused_progress: float = stone.get_transition_progress()
	var paused_alpha: float = stone.get_accent_strength()
	get_tree().paused = true
	await get_tree().process_frame
	stone.advance_transition(duration * 0.60)
	_check(stone.is_transitioning(), "pause keeps the transition unfinished")
	_check(is_equal_approx(stone.get_transition_elapsed(), paused_elapsed), "pause freezes transition elapsed time")
	_check(is_equal_approx(stone.get_transition_progress(), paused_progress), "pause freezes transition progress")
	_check(is_equal_approx(stone.get_accent_strength(), paused_alpha), "pause freezes the accent alpha")
	_check(_transition_events.is_empty(), "pause emits no transition_finished")
	get_tree().paused = false
	await get_tree().process_frame

	# Move into the relight half explicitly: the state image changes only after
	# the old accent has faded fully out.
	stone.advance_transition(duration * 0.20)
	_check(stone.get_transition_progress() > 0.35 and stone.get_transition_progress() < 0.45,
		"second fifth crosses into the relight phase")
	_check(accent_sprite.texture == cyan_texture, "relight phase shows the target cyan state image")
	_check(stone.get_accent_strength() < 0.10, "target accent starts near zero after the dim", str(stone.get_accent_strength()))
	stone.advance_transition(duration * 0.40)
	var relight_color: Color = stone.get_displayed_color()
	_check(stone.get_accent_strength() > 0.50, "target cyan accent rises during the second half")
	_check(relight_color.g > 0.20 and relight_color.b < 0.90, "new cyan light rises after the dim phase")

	stone.advance_transition(duration)
	_check(not stone.is_transitioning(), "unpaused transition completes")
	_check(is_equal_approx(stone.get_transition_progress(), 1.0), "completed progress is 1.0")
	_check(not stone.get_applied_positive(), "applied polarity becomes negative")
	_check(stone.get_displayed_color().is_equal_approx(NEGATIVE), "completed light is exactly #5fe1e6")
	_check(accent_sprite.texture == cyan_texture and is_equal_approx(stone.get_accent_strength(), 1.0),
		"completed transition settles on the full cyan state")
	_check(base_sprite.texture == base_texture and base_sprite.transform == start_base_transform,
		"completed transition keeps the sleep base and its transform")
	_check(_transition_events.size() == 1 and _transition_events[0] == false, "one transition_finished(false) is emitted")
	_check(not stone.is_processing(), "process turns off after completion")
	_check(stone.transform == start_stone_transform, "completed transition keeps the stone fixed")

	_transition_events.clear()
	stone.set_polarity(true, false)
	stone.advance_transition(duration * 0.80)
	var reverse_color: Color = stone.get_displayed_color()
	_check(stone.get_accent_strength() > 0.50, "reverse gold accent rises during the second half")
	_check(reverse_color.g > 0.20 and reverse_color.b < 0.80, "new gold light rises after the dim phase")
	_check(accent_sprite.texture == gold_texture, "reverse transition settles toward the concept gold state")
	stone.advance_transition(duration)
	_check(_transition_events.size() == 1 and _transition_events[0] == true, "reverse transition emits one transition_finished(true)")
	_check(stone.get_displayed_color().is_equal_approx(POSITIVE), "reverse transition ends at gold")

	_transition_events.clear()
	stone.set_polarity(false, false)
	stone.advance_transition(duration * 0.10)
	stone.set_polarity(true, true)
	_check(not stone.is_transitioning(), "immediate call cancels an active transition")
	_check(stone.get_applied_positive(), "immediate call applies positive at once")
	_check(accent_sprite.texture == gold_texture and is_equal_approx(stone.get_accent_strength(), 1.0),
		"cancelled transition snaps to the full gold state")
	_check(_transition_events.is_empty(), "cancelled transition emits no completion signal")
	_check(not stone.is_processing(), "cancelled transition turns process off")

	stone.transition_duration = 0.0
	_check(is_equal_approx(stone.transition_duration, 0.05), "transition duration clamps to 0.05 s")
	stone.transition_duration = 99.0
	_check(is_equal_approx(stone.transition_duration, 2.0), "transition duration clamps to 2.0 s")

	stone.queue_free()
	await get_tree().process_frame


func _test_inactive_visual_state() -> void:
	_section("INACTIVE / CONCEPT SLEEP / FIRST LIGHT-UP")
	var stone: RuneStoneVisual = RUNE_SCENE.instantiate() as RuneStoneVisual
	add_child(stone)
	await get_tree().process_frame
	_transition_events.clear()
	stone.transition_finished.connect(_on_transition_finished)

	var base_sprite: Sprite2D = stone.get_base_sprite()
	var accent_sprite: Sprite2D = stone.get_accent_sprite()
	var base_texture: Texture2D = base_sprite.texture
	var gold_texture: Texture2D = stone.get_state_texture(true)
	var base_transform: Transform2D = base_sprite.transform
	var stone_transform: Transform2D = stone.transform

	stone.show_polarity_hint = true
	stone.set_energized(false, true)
	_check(not stone.is_energized(), "set_energized(false) puts the stone dormant")
	_check(not stone.is_transitioning(), "dormant switch leaves no transition running")
	_check(stone.get_hint_kind() == &"none", "dormant stone reports no plus/minus hint kind")
	_check(stone.get_displayed_color().is_equal_approx(RuneStoneVisual.INACTIVE_COLOR),
		"dormant API reports the dark colour", str(stone.get_displayed_color()))
	_check(is_equal_approx(stone.get_accent_strength(), 0.0),
		"dormant state hides the gold/cyan accent", str(stone.get_accent_strength()))
	_check(base_sprite.texture == base_texture, "dormant state keeps the concept sleep image")
	_check(base_sprite.modulate == Color.WHITE, "dormant state leaves the sleep image untouched")
	_check(base_sprite.texture == stone.get_sleep_texture(), "sleep image is the approved dormant state")
	_check(base_sprite.transform == base_transform and stone.transform == stone_transform,
		"dormant state does not move, rotate or scale the stone")
	_check(_transition_events.is_empty(), "dormant switch emits no completion")
	_check(not stone.is_processing(), "dormant stone runs no autonomous process")

	# The +/- must not draw while dormant even if the hint flag was left true.
	_check(stone.show_polarity_hint, "test keeps the hint flag true while dormant")
	_check(not stone.should_draw_polarity_hint(),
		"dormant stone suppresses the +/- draw despite the true flag")

	# First light-up starts from the sleep image, not from an instant gold flash.
	stone.energize_to(true, false)
	_check(stone.is_energized() and stone.is_transitioning(),
		"energize_to starts a sleep-to-colour transition")
	_check(stone.get_applied_positive(), "energize_to target is GOLD")
	_check(stone.get_transition_progress() < 0.01, "first light-up starts at zero progress")
	_check(is_equal_approx(stone.get_accent_strength(), 0.0), "first light-up starts with the accent hidden")
	_check(_transition_events.is_empty(), "first light-up does not finish synchronously")
	stone.advance_transition(stone.transition_duration * 0.10)
	var dark_phase: Color = stone.get_displayed_color()
	_check(maxf(dark_phase.r, maxf(dark_phase.g, dark_phase.b)) < 0.35,
		"early first light-up is still visibly dark", str(dark_phase))
	_check(is_equal_approx(stone.get_accent_strength(), 0.0),
		"during the dim half the sleep base still shows no accent")
	stone.advance_transition(stone.transition_duration * 0.60)
	var rising: Color = stone.get_displayed_color()
	_check(stone.get_accent_strength() > 0.30, "first light-up accent rises in the second half")
	_check(rising.g > dark_phase.g or rising.r > dark_phase.r,
		"first light-up rises toward the target colour", str(rising))
	_check(accent_sprite.texture == gold_texture, "first light-up target shows the concept gold image")
	stone.advance_transition(stone.transition_duration)
	_check(not stone.is_transitioning(), "first light-up finishes")
	_check(stone.get_displayed_color().is_equal_approx(POSITIVE),
		"first light-up ends at exactly #f4cd63")
	_check(is_equal_approx(stone.get_accent_strength(), 1.0), "first light-up ends with the full gold accent")
	_check(_transition_events.size() == 1 and _transition_events[0],
		"first light-up emits one transition_finished(true)")
	_check(stone.get_hint_kind() == &"plus", "energized stone restores the plus hint kind")
	_check(stone.should_draw_polarity_hint(), "energized stone can draw the true hint flag")

	# Switching back to dormant hides the glyph and cancels an in-flight light.
	stone.set_polarity(false, false)
	stone.advance_transition(stone.transition_duration * 0.15)
	stone.set_energized(false, true)
	_check(not stone.is_energized() and not stone.is_transitioning(),
		"dormant switch cancels an in-flight polarity transition")
	_check(stone.get_displayed_color().is_equal_approx(RuneStoneVisual.INACTIVE_COLOR),
		"cancelled transition falls back to the dark sleep state")
	_check(is_equal_approx(stone.get_accent_strength(), 0.0),
		"cancelled transition hides the accent")
	_check(not stone.should_draw_polarity_hint(),
		"cancelled transition still draws no dormant +/- hint")

	stone.queue_free()
	await get_tree().process_frame


func _test_preview() -> void:
	_section("640x360 STANDALONE PREVIEW")
	var preview: Control = PREVIEW_SCENE.instantiate() as Control
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(preview != null, "preview scene instantiates")
	if preview == null:
		return
	_check(preview.size == Vector2(640.0, 360.0), "preview canvas is 640x360", str(preview.size))
	_check(_count_physics_nodes(preview) == 0, "preview contains no physics nodes")

	var stones: Array[RuneStoneVisual] = []
	_collect_stones(preview, stones)
	_check(stones.size() == 4, "preview shows two polarities at two integer scales", str(stones.size()))
	var positive_count: int = 0
	var negative_count: int = 0
	var one_x_count: int = 0
	var four_x_count: int = 0
	var hint_1x: int = 0
	var hint_4x: int = 0
	var all_baseline: bool = true
	var all_nearest: bool = true
	var all_art: bool = true
	for stone: RuneStoneVisual in stones:
		if stone.polarity_positive:
			positive_count += 1
		else:
			negative_count += 1
		if is_equal_approx(stone.scale.x, 1.0):
			one_x_count += 1
			if stone.show_polarity_hint:
				hint_1x += 1
		elif is_equal_approx(stone.scale.x, 4.0):
			four_x_count += 1
			if stone.show_polarity_hint:
				hint_4x += 1
		else:
			all_nearest = false
		all_baseline = all_baseline and is_equal_approx(stone.position.y + 16.0 * stone.scale.y, 260.0)
		all_nearest = all_nearest and stone.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		all_art = all_art and stone.has_art()
	_check(positive_count == 2 and negative_count == 2, "both polarities appear twice")
	_check(one_x_count == 2 and four_x_count == 2, "both 1x and 4x views exist")
	_check(hint_1x == 2 and hint_4x == 0, "near hint is forced only on the 1x examples")
	_check(all_baseline, "all stones share the 260 px review baseline")
	_check(all_nearest, "all preview stones use nearest filtering")
	_check(all_art, "all preview stones loaded the three concept state PNGs")

	var character: TextureRect = _find_texture_rect(preview, "PlayerIdle1x")
	_check(character != null, "original character 1x example exists")
	if character != null:
		_check(character.texture is AtlasTexture, "character uses a cropped AtlasTexture")
		if character.texture is AtlasTexture:
			var atlas: AtlasTexture = character.texture as AtlasTexture
			_check(atlas.region == Rect2(41.0, 43.0, 32.0, 37.0), "character crop is idle #0 visible pixels")
		_check(character.size == Vector2(32.0, 37.0), "character visible crop is displayed at 32x37")
		_check(character.scale == Vector2.ONE, "character comparison is actual 1x, not scaled")
		_check(character.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "character comparison uses nearest filtering")
		_check(is_equal_approx(character.position.y + character.size.y, 260.0), "character feet share the stone baseline")

	var labels: Array[Label] = []
	_collect_labels(preview, labels)
	var joined: String = ""
	var ascii_only: bool = true
	for label: Label in labels:
		joined += label.text + "\n"
		ascii_only = ascii_only and not _has_non_ascii(label.text)
	_check(ascii_only, "all preview labels are ASCII-only")
	_check(labels.size() >= 12, "preview has title, state, scale, comparison and status labels", str(labels.size()))
	_check(joined.contains("RUNE STONE VISUAL PREVIEW"), "preview has a title")
	_check(joined.contains("NOT GAMEPLAY"), "preview states that it is not gameplay")
	_check(joined.contains("NEAREST / 96->32"), "preview is marked as concept-derived direct NEAREST, not first-pass art")
	_check(joined.contains("PLAYER 1x"), "preview labels the original character at 1x")
	_check(joined.contains("1x + FORCED HINT"), "preview labels the forced near hint")
	_check(joined.contains("4x INTEGER NEAR VIEW"), "preview labels the 4x near view")
	_check(joined.contains("SAME STONE"), "preview states both states use the same stone")
	_check(joined.contains("SPACE"), "preview documents the SPACE transition demo")
	_check(joined.contains("DIM-THEN-RELIGHT"), "preview documents the dim-then-relight transition")
	_check(joined.contains("3/3 STATES 32x32"), "preview reports all three concept states loaded")
	_check(joined.contains("DIRECT 96->32 NEAREST"), "preview reports the approved direct NEAREST conversion")
	_check(joined.contains("NO PHYSICS, FORCE, COLLISION, PROXIMITY"), "preview lists excluded systems")

	var left_title: Label = _find_title_by_side(labels, true)
	var right_title: Label = _find_title_by_side(labels, false)
	_check(left_title != null and left_title.text == "GOLD / POSITIVE", "left column starts gold")
	_check(right_title != null and right_title.text == "CYAN / NEGATIVE", "right column starts cyan")

	var stones_4x: Array[RuneStoneVisual] = preview.get_demo_stones_4x()
	var space_event: InputEventKey = InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	preview._unhandled_input(space_event)
	_check(preview.is_demo_busy(), "SPACE demo starts a transition")
	_check(
		stones_4x.size() == 2 and stones_4x[0].is_transitioning() and stones_4x[1].is_transitioning(),
		"both 4x examples animate through set_polarity"
	)
	for stone: RuneStoneVisual in stones_4x:
		stone.advance_transition(stone.transition_duration)
	for stone: RuneStoneVisual in preview.get_demo_stones_1x():
		stone.advance_transition(stone.transition_duration)
	await get_tree().process_frame
	_check(not preview.is_demo_busy(), "demo clears its busy state after both columns finish")
	_check(
		stones_4x[0].get_applied_positive() == false
		and stones_4x[1].get_applied_positive() == true,
		"columns swap to cyan and gold"
	)
	left_title = _find_title_by_side(labels, true)
	right_title = _find_title_by_side(labels, false)
	_check(left_title != null and left_title.text == "CYAN / NEGATIVE", "left column label updates to cyan")
	_check(right_title != null and right_title.text == "GOLD / POSITIVE", "right column label updates to gold")
	var left_hint: Label = _find_label_by_text_and_side(labels, "1x + FORCED HINT", true)
	var right_hint: Label = _find_label_by_text_and_side(labels, "1x + FORCED HINT", false)
	_check(
		left_hint != null and right_hint != null
		and left_hint.get_theme_color("font_color").is_equal_approx(NEGATIVE)
		and right_hint.get_theme_color("font_color").is_equal_approx(POSITIVE),
		"1x hint label accents follow the swapped columns"
	)
	_check(joined.contains("VISUAL PREVIEW ONLY"), "footer marks the scene as visual-only")

	preview.queue_free()
	await get_tree().process_frame


func _load_source_image(path: String) -> Image:
	var image: Image = Image.new()
	var error: Error = image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		_log("[FAIL] Image.load failed for %s error=%d" % [path, error])
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _silhouettes_equal(images: Array[Image]) -> bool:
	if images.is_empty():
		return false
	var first: Image = images[0]
	for index: int in range(1, images.size()):
		if images[index].get_size() != first.get_size():
			return false
		for y: int in range(first.get_height()):
			for x: int in range(first.get_width()):
				if images[index].get_pixel(x, y).a8 != first.get_pixel(x, y).a8:
					return false
	return true


func _images_differ(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return 0
	var count: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if not _same_rgba(a.get_pixel(x, y), b.get_pixel(x, y)):
				count += 1
	return count


func _count_near_color(image: Image, target: Color, radius: int) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a8 != 255:
				continue
			var dr: int = pixel.r8 - target.r8
			var dg: int = pixel.g8 - target.g8
			var db: int = pixel.b8 - target.b8
			if dr * dr + dg * dg + db * db <= radius * radius:
				count += 1
	return count


## Compare visible pixels after import. Transparent RGB can be rewritten by the
## importer's alpha-border fixup, so only alpha and the RGB of visible pixels
## are required to match.
func _visible_pixels_match(imported: Image, source: Image) -> bool:
	if imported == null or source == null:
		return false
	if imported.get_size() != source.get_size():
		return false
	var left: Image = imported.duplicate()
	var right: Image = source.duplicate()
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	for y: int in range(left.get_height()):
		for x: int in range(left.get_width()):
			var a: Color = left.get_pixel(x, y)
			var b: Color = right.get_pixel(x, y)
			if a.a8 != b.a8:
				return false
			if a.a8 != 0 and (
				a.r8 != b.r8 or a.g8 != b.g8 or a.b8 != b.b8
			):
				return false
	return true


func _same_rgba(a: Color, b: Color) -> bool:
	return a.r8 == b.r8 and a.g8 == b.g8 and a.b8 == b.b8 and a.a8 == b.a8


func _on_transition_finished(positive: bool) -> void:
	_transition_events.append(positive)


func _find_title_by_side(labels: Array[Label], left: bool) -> Label:
	for label: Label in labels:
		if label.text.contains("POSITIVE") or label.text.contains("NEGATIVE"):
			if left and label.position.x < 300.0:
				return label
			if not left and label.position.x > 300.0:
				return label
	return null


func _find_label_by_text_and_side(labels: Array[Label], text: String, left: bool) -> Label:
	for label: Label in labels:
		if label.text == text:
			if left and label.position.x < 320.0:
				return label
			if not left and label.position.x > 320.0:
				return label
	return null


func _find_texture_rect(node: Node, target_name: String) -> TextureRect:
	for child: Node in node.get_children():
		if child is TextureRect and child.name == target_name:
			return child as TextureRect
		var found: TextureRect = _find_texture_rect(child, target_name)
		if found != null:
			return found
	return null


func _collect_stones(node: Node, out: Array[RuneStoneVisual]) -> void:
	for child: Node in node.get_children():
		if child is RuneStoneVisual:
			out.append(child as RuneStoneVisual)
		_collect_stones(child, out)


func _collect_labels(node: Node, out: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append(child as Label)
		_collect_labels(child, out)


func _count_physics_nodes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Area2D:
			count += 1
		count += _count_physics_nodes(child)
	return count


func _has_non_ascii(text: String) -> bool:
	for index: int in text.length():
		if text.unicode_at(index) > 126:
			return true
	return false


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


func _skip(label: String) -> void:
	_skip_count += 1
	_log("[SKIP] %s" % label)


func _section(title: String) -> void:
	_log("")
	_log("== %s ==" % title)


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	_log("")
	_log("RESULT pass=%d fail=%d skipped=%d" % [_pass_count, _fail_count, _skip_count])
	var log_directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(log_directory)
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/rune_stone_visual_test.log",
		FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RUNE_STONE_VISUAL_TEST_RESULT pass=%d fail=%d skipped=%d" % [
		_pass_count,
		_fail_count,
		_skip_count,
	])
	get_tree().quit(1 if _fail_count > 0 else 0)
