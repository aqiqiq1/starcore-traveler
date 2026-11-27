class_name HiddenRouteGate
extends Node2D

## Thin, optional side-chapter entrance placed in a mainline room.
##
## It has no collision and never blocks the route.  A one-shot proximity line
## appears inside 56 px (same threshold as the game's other world hints); the
## existing E interact verb then enters the side scene.  The visual is supplied
## by a subclass built only from already-approved project art, so this base
## owns behaviour and accessors, not one shared generic icon.

signal route_entered(target_id: String)

const HINT_DISTANCE: float = 56.0
const REARM_DISTANCE: float = 200.0
const ENTER_DISTANCE: float = 56.0
const VERTICAL_RANGE: float = 96.0

const APPROACH_HINT = preload("res://scripts/ui/approach_hint.gd")
const SIDE_ROUTE = preload("res://dlc/shared/side_route/side_route.gd")

@export var target_id: String = ""
@export var scene_path: String = ""
@export var origin_id: String = ""
@export var origin_path: String = ""
@export var hint_text: String = ""
@export var player_path: NodePath = NodePath("../Player")
@export var hud_path: NodePath = NodePath("../HUD")
@export var enter_distance: float = ENTER_DISTANCE

var _player: Node2D = null
var _hud: Node = null
var _hint: ApproachHint = APPROACH_HINT.new()
var _chapter_progress_path: String = ""
var _entering: bool = false
var _hint_grace: float = 0.0


func _ready() -> void:
	# The chapter root is PROCESS_MODE_ALWAYS; the entrance belongs to the
	# paused world and must freeze with it.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_visual()
	_resolve_nodes()


func _resolve_nodes() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node2D
	if _hud == null or not is_instance_valid(_hud):
		_hud = get_node_or_null(hud_path) as Node


func _physics_process(_delta: float) -> void:
	if _entering or get_tree() == null or get_tree().paused:
		return
	_resolve_nodes()
	if _player == null or not is_instance_valid(_player):
		return
	if not _is_allowed():
		return
	if _hint_grace > 0.0:
		_hint_grace = maxf(_hint_grace - _delta, 0.0)
		return
	_tick_hint()


func _tick_hint() -> void:
	var dx: float = absf(_player.global_position.x - global_position.x)
	var vertical: bool = absf(_player.global_position.y - global_position.y) <= VERTICAL_RANGE
	if _hint.tick(dx, vertical, Time.get_ticks_msec()):
		_show_hint(hint_text, 2.2)


func _is_allowed() -> bool:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("is_side_route_gate_allowed"):
		return bool(parent.call("is_side_route_gate_allowed"))
	return true


func _show_hint(text_value: String, seconds: float) -> void:
	if _hud == null or not is_instance_valid(_hud) or not _hud.has_method("show_event"):
		return
	_hud.call("show_event", text_value, seconds)


func is_player_in_range() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if absf(_player.global_position.y - global_position.y) > VERTICAL_RANGE:
		return false
	return absf(_player.global_position.x - global_position.x) <= enter_distance


## Called by the chapter's existing E / interact route.  Returns true when the
## route really started (so input can stop there).
func try_enter() -> bool:
	if _entering or not is_player_in_range():
		return false
	return _begin_route()


func _begin_route() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var parent: Node = get_parent()
	var return_position: Vector2 = _player.global_position
	var origin_state: Dictionary = {}
	if parent != null and parent.has_method("get_side_route_return_position"):
		var position_value: Variant = parent.call("get_side_route_return_position")
		if typeof(position_value) == TYPE_VECTOR2:
			return_position = position_value
	if parent != null and parent.has_method("get_side_route_origin_state"):
		var state_value: Variant = parent.call("get_side_route_origin_state")
		if typeof(state_value) == TYPE_DICTIONARY:
			origin_state = state_value as Dictionary
	var error: Error = SIDE_ROUTE.enter(
		tree, target_id, scene_path, origin_id, origin_path,
		return_position, origin_state, _chapter_progress_path
	)
	if error != OK:
		_show_hint("支线场景缺失 · 暂时无法进入", 2.0)
		return false
	_entering = true
	route_entered.emit(target_id)
	return true


func set_chapter_progress_path(path: String) -> void:
	_chapter_progress_path = path


func get_chapter_progress_path() -> String:
	return _chapter_progress_path


func get_hint_text() -> String:
	return hint_text


func get_hint_shown_count() -> int:
	return _hint.get_shown_count()


func reset_hint() -> void:
	_hint.reset()


## Used by the origin scene's one-shot resume: the player has just returned
## from this side chapter, so do not immediately prompt them to re-enter it.
func suppress_hints(seconds: float) -> void:
	_hint_grace = maxf(_hint_grace, seconds)
	_hint.reset()


func is_hint_grace_active() -> bool:
	return _hint_grace > 0.0


func is_route_entering() -> bool:
	return _entering


## Subclasses build their approved-art visual here.  The base does not draw a
## fallback marker: a missing subclass visual should read as missing content,
## not as a generic icon.
func _build_visual() -> void:
	pass
