class_name UiReveal
extends RefCounted

## Shared reveal for the 640x360 1x pixel overlays.
##
## The caller owns the real state: is_open()/unpause/focus must switch in the
## same frame as open()/close().  This helper only tweens the dimmer alpha and
## the panel's 4-6 px slide; the panel stays at 1.0 scale so text is never
## resampled.  Open is 0.18 s ease-out; close is 0.12 s with the reverse motion.
## No bounce, blur or shader is used.
##
## TWEEN_PAUSE_PROCESS keeps both directions running while the scene tree is
## paused.  On close the root stays visible only for the fade, with mouse input
## ignored, so a 0.12 s exit can never delay gameplay or block clicks.

const OPEN_DURATION: float = 0.18
const CLOSE_DURATION: float = 0.12
const PANEL_SCALE_FROM: float = 1.0
const SLIDE_IN_PX: float = 5.0
const SLIDE_OUT_PX: float = 3.0

enum Phase { CLOSED, OPENING, OPEN, CLOSING }

var _host: Node = null
var _root: Control = null
var _shade: Control = null
var _panel: Control = null
var _panel_base_position: Vector2 = Vector2.ZERO
var _root_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP
var _shade_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP
var _panel_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP
var _tween: Tween = null
var _phase: Phase = Phase.CLOSED


## Call once after the overlay's UI has been built and before it is shown.
func setup(
	host: Node,
	root: Control,
	shade: Control,
	panel: Control,
	panel_base_position: Vector2
) -> void:
	if host == null or root == null or shade == null or panel == null:
		return
	_host = host
	_root = root
	_shade = shade
	_panel = panel
	_panel_base_position = panel_base_position
	_root_filter = _root.mouse_filter
	_shade_filter = _shade.mouse_filter
	_panel_filter = _panel.mouse_filter
	# Scale around the panel's own centre; position is animated separately.
	_panel.pivot_offset = _panel.size * 0.5
	_apply_closed_values()
	_set_interactive(false)


## Root visibility is set by the caller before this call (or here, safely).
func play_open() -> void:
	if not _has_targets():
		return
	_kill_tween()
	_root.visible = true
	_set_interactive(true)
	_phase = Phase.OPENING
	_tween = _host.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, OPEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, OPEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "position", _panel_base_position, OPEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_on_open_finished)


## Real close/unpause happens before this call.  The panel only finishes its
## visual exit; input is already released because every overlay checks _open.
func play_close() -> void:
	if not _has_targets():
		return
	_kill_tween()
	_root.visible = true
	_set_interactive(false)
	_phase = Phase.CLOSING
	_tween = _host.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 0.0, CLOSE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "scale", Vector2.ONE * PANEL_SCALE_FROM, CLOSE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(
		_panel,
		"position",
		_panel_base_position + Vector2(0.0, SLIDE_OUT_PX),
		CLOSE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_on_close_finished)


## Cancel any running reveal and put the overlay in its hidden rest state.
## Used by scene changes / force-close paths where no exit animation is wanted.
func snap_closed() -> void:
	_kill_tween()
	_phase = Phase.CLOSED
	if not _has_targets():
		return
	_apply_closed_values()
	_root.visible = false
	_set_interactive(false)


## One-shot reveal for overlays that build their own dimmer (the base level
## completion pages: a full-screen ColorRect that also parents the panel).
## The overlay stays visible from the first frame; only alpha/scale move, so
## focus and clicks are never delayed.  Returns the tween for the caller to kill.
static func play_overlay_open(
	host: Node,
	overlay: Control,
	panel: Control,
	panel_base_position: Vector2
) -> Tween:
	if host == null or not is_instance_valid(host):
		return null
	if overlay == null or not is_instance_valid(overlay):
		return null
	overlay.modulate.a = 0.0
	var has_panel: bool = panel != null and is_instance_valid(panel)
	if has_panel:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE * PANEL_SCALE_FROM
		panel.position = panel_base_position + Vector2(0.0, SLIDE_IN_PX)
	var tween: Tween = host.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, OPEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_panel:
		tween.tween_property(panel, "scale", Vector2.ONE, OPEN_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position", panel_base_position, OPEN_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


## Restore the rest values after a one-shot overlay is hidden.
static func snap_overlay(overlay: Control, panel: Control, panel_base_position: Vector2) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.modulate.a = 1.0
	if panel != null and is_instance_valid(panel):
		panel.scale = Vector2.ONE
		panel.position = panel_base_position


func is_animating() -> bool:
	return _phase == Phase.OPENING or _phase == Phase.CLOSING


func is_open_animating() -> bool:
	return _phase == Phase.OPENING


func is_close_animating() -> bool:
	return _phase == Phase.CLOSING


func get_phase() -> int:
	return int(_phase)


func get_shade_alpha() -> float:
	return _shade.modulate.a if _shade != null else 0.0


func get_panel_scale() -> float:
	return _panel.scale.x if _panel != null else 1.0


func get_panel_position() -> Vector2:
	return _panel.position if _panel != null else Vector2.ZERO


func get_panel_base_position() -> Vector2:
	return _panel_base_position


func get_panel_offset_y() -> float:
	return get_panel_position().y - _panel_base_position.y


func is_root_visible() -> bool:
	return _root != null and _root.visible


func _has_targets() -> bool:
	return (
		_host != null
		and is_instance_valid(_host)
		and _root != null
		and is_instance_valid(_root)
		and _shade != null
		and is_instance_valid(_shade)
		and _panel != null
		and is_instance_valid(_panel)
	)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _on_open_finished() -> void:
	if _phase != Phase.OPENING:
		return
	_phase = Phase.OPEN
	_tween = null
	_apply_open_values()


func _on_close_finished() -> void:
	if _phase != Phase.CLOSING:
		return
	_phase = Phase.CLOSED
	_tween = null
	_apply_closed_values()
	if _root != null:
		_root.visible = false
	_set_interactive(false)


func _apply_open_values() -> void:
	if _shade != null:
		_shade.modulate.a = 1.0
	if _panel != null:
		_panel.scale = Vector2.ONE
		_panel.position = _panel_base_position


func _apply_closed_values() -> void:
	if _shade != null:
		_shade.modulate.a = 0.0
	if _panel != null:
		_panel.scale = Vector2.ONE * PANEL_SCALE_FROM
		_panel.position = _panel_base_position + Vector2(0.0, SLIDE_IN_PX)


func _set_interactive(value: bool) -> void:
	if _root != null:
		_root.mouse_filter = _root_filter if value else Control.MOUSE_FILTER_IGNORE
	if _shade != null:
		_shade.mouse_filter = _shade_filter if value else Control.MOUSE_FILTER_IGNORE
	if _panel != null:
		_panel.mouse_filter = _panel_filter if value else Control.MOUSE_FILTER_IGNORE
