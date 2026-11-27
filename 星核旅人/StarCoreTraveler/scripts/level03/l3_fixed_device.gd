class_name L3FixedDevice
extends Node2D

## Fixed stone device that starts the floating-platform route.  It is not a
## star-core bay: E only changes the device's own core from the locked state to
## the live 辉相 core.  The transport core is never read, moved or consumed
## here.
##
## Art (2026-11-27 second pass): the old 48x40 PNG baked a purple orb into the
## device.  The shell is now the same stone arch with a code-drawn dark socket,
## and the core is the shared `StarCoreVisual` scene at 16x16 / 12 frames.  The
## active sheet is `star_core_positive_12f.png`; the idle sheet is the locked
## purple sheet, so the two states still read at 1:1 without a +/− badge.
## The free core draws no outer metal ring; only this device's own stone arch
## and socket remain around it.

signal activated

const SHELL_TEXTURE: Texture2D = preload(
	"res://assets/level03_prototype/fixed_core_inactive.png"
)
const CORE_SCENE: PackedScene = preload("res://scenes/star_core_visual.tscn")
const FOOT_ANCHOR: Vector2 = Vector2(24.0, 39.0)
const SOCKET_CENTER: Vector2 = Vector2(24.0, 16.0)
const SOCKET_RADIUS: float = 8.5
const SOCKET_DARK: Color = Color("#0d1517")
const SOCKET_LIP: Color = Color("#485558")
## The old orb bbox is x=17..30, y=9..22 (centre 23.5, 15.5).  The new 16x16
## core uses integer pixels at (24,16), a half-pixel shift that stays inside the
## 18 px socket.
const CORE_POSITION: Vector2 = Vector2(0.0, -23.0)

@export var interaction_range: float = 46.0
@export var foot_y: float = 210.0

var _core: StarCoreVisual = null
var _active: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	_core = get_node_or_null("Core") as StarCoreVisual
	if _core == null:
		_core = CORE_SCENE.instantiate() as StarCoreVisual
		_core.name = "Core"
		add_child(_core)
	_core.position = CORE_POSITION
	_core.show_state_badge = false
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position.y = foot_y
	_apply_state()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += delta
	# Restrained integer-pixel breathing; the 12-frame sheet keeps spinning.
	var pulse: int = 0 if fmod(_pulse_time, 1.6) < 1.1 else 1
	if _core != null:
		_core.position.y = CORE_POSITION.y - float(pulse)


func activate() -> void:
	if _active:
		return
	_active = true
	_apply_state()
	activated.emit()


func reset_state() -> void:
	_active = false
	_pulse_time = 0.0
	_apply_state()


func is_active() -> bool:
	return _active


func get_core_visual() -> StarCoreVisual:
	return _core


func get_interaction_center() -> Vector2:
	return global_position + Vector2(0.0, -20.0)


func is_player_in_range(player_position: Vector2) -> bool:
	return global_position.distance_to(player_position + Vector2(0.0, -15.0)) <= interaction_range


## The visible core sheet, not the stone shell.  This is the path the art audit
## and tests check; active = POSITIVE 12f, idle = LOCKED 12f.
func get_texture_path() -> String:
	if _core == null:
		return ""
	return _core.get_state_sheet_path()


func _apply_state() -> void:
	if _core == null:
		return
	_core.state = (
		StarCoreVisual.CoreState.POSITIVE if _active
		else StarCoreVisual.CoreState.LOCKED
	)
	_core.animate = _active
	_core.visible = true
	_core.position = CORE_POSITION
	_core.refresh()
	set_process(_active)
	queue_redraw()


func _draw() -> void:
	draw_texture(SHELL_TEXTURE, -FOOT_ANCHOR)
	_draw_socket()


## Cover the old baked orb with a clean dark recess.  The stone arch around it
## belongs to the device, so the free core itself still has no outer ring.
func _draw_socket() -> void:
	var radius_sq: float = SOCKET_RADIUS * SOCKET_RADIUS
	for y: int in range(int(SOCKET_CENTER.y - SOCKET_RADIUS - 1.0),
			int(SOCKET_CENTER.y + SOCKET_RADIUS + 1.0)):
		var dy: float = (float(y) + 0.5) - SOCKET_CENTER.y
		for x: int in range(int(SOCKET_CENTER.x - SOCKET_RADIUS - 1.0),
				int(SOCKET_CENTER.x + SOCKET_RADIUS + 1.0)):
			var dx: float = (float(x) + 0.5) - SOCKET_CENTER.x
			if dx * dx + dy * dy <= radius_sq:
				draw_rect(Rect2(float(x), float(y), 1.0, 1.0), SOCKET_DARK)
	# One dim top-left lip on the device itself; no ring is drawn on the core.
	for x: int in range(17, 24):
		draw_rect(Rect2(float(x), 7.0, 1.0, 1.0), SOCKET_LIP)
