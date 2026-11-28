class_name SideRoute
extends RefCounted

## One-shot "hidden side chapter" route state shared by the two in-level
## entrances (DLC3 镜面裂隙 -> 裂隙工坊, L3 试炼碑 -> 星核试炼场).
##
## The route is deliberately small and process-local:
##   - the entrance records the origin id/path, the real return position and an
##     optional snapshot of the origin's gameplay state;
##   - the side chapter asks `claim_entry()` whether it was entered this way;
##   - its completion page can call `return_to_origin()` instead of the title;
##   - a pause/game-over exit calls `abort()` so a failed side run never leaves
##     a stale resume seed behind.
##
## Static vars survive the real SceneTree.change_scene_to_file() used by the
## game, and are cleared as soon as the origin scene consumes the resume seed.

const ORIGIN_LOOM: String = "loom"
const ORIGIN_L3: String = "l3"

const LEVEL_FLOW = preload("res://scripts/ui/level_flow.gd")
const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")

static var _active: bool = false
static var _target_id: String = ""
static var _origin_id: String = ""
static var _origin_path: String = ""
static var _return_position: Vector2 = Vector2.ZERO
static var _origin_state: Dictionary = {}
static var _progress_path: String = ""

static var _pending_resume: bool = false
static var _pending_origin_id: String = ""
static var _pending_position: Vector2 = Vector2.ZERO
static var _pending_state: Dictionary = {}

## One-shot black-entry marker.  The mirror entrance fades the origin to black
## before the real scene change; the side chapter consumes this flag during its
## first _ready so its very first rendered frame is covered by black.
static var _black_entry: bool = false
static var _black_entry_target: String = ""


## Marks the side chapter discovered immediately, stores the return context and
## performs the real scene change.  A failed scene change clears the route.
static func enter(
	tree: SceneTree,
	target_id: String,
	scene_path: String,
	origin_id: String,
	origin_path: String,
	return_position: Vector2,
	origin_state: Dictionary = {},
	progress_path: String = ""
) -> Error:
	if tree == null:
		return ERR_UNCONFIGURED
	if not ResourceLoader.exists(scene_path):
		_black_entry = false
		_black_entry_target = ""
		return ERR_FILE_NOT_FOUND
	active_clear()
	CHAPTER_PROGRESS.mark_discovered(target_id, progress_path)
	_target_id = target_id
	_origin_id = origin_id
	_origin_path = origin_path
	_return_position = return_position
	_origin_state = origin_state.duplicate(true)
	_progress_path = progress_path
	_active = true
	var error: Error = LEVEL_FLOW.change_scene(tree, scene_path)
	if error != OK:
		active_clear()
		_black_entry = false
		_black_entry_target = ""
	return error


## Called by an entrance that has already faded its own frame to black.  The
## destination consumes it exactly once, after a successful scene change.
static func mark_black_entry(target_id: String) -> void:
	_black_entry = not target_id.is_empty()
	_black_entry_target = target_id


static func consume_black_entry(target_id: String) -> bool:
	if not _black_entry or _black_entry_target != target_id:
		return false
	_black_entry = false
	_black_entry_target = ""
	return true


static func clear_black_entry() -> void:
	_black_entry = false
	_black_entry_target = ""



## True only inside the side chapter that the entrance just loaded.  Merely
## opening the row from the title never claims a route.
static func claim_entry(target_id: String) -> bool:
	return _active and _target_id == target_id


## The progress file the side run started from, so its own completion write
## lands in the same file as the discovery flag (tests use a throwaway path).
static func get_progress_path() -> String:
	return _progress_path


static func is_active() -> bool:
	return _active


static func get_target_id() -> String:
	return _target_id


static func get_origin_id() -> String:
	return _origin_id


static func get_origin_path() -> String:
	return _origin_path


static func get_return_position() -> Vector2:
	return _return_position


static func get_origin_state() -> Dictionary:
	return _origin_state.duplicate(true)


## Called by the side chapter's completion page.  Queues a one-shot resume seed
## for the origin scene, then performs the real scene change.
static func return_to_origin(tree: SceneTree) -> Error:
	if tree == null or not _active:
		return ERR_UNCONFIGURED
	if not ResourceLoader.exists(_origin_path):
		return ERR_FILE_NOT_FOUND
	_pending_resume = true
	_pending_origin_id = _origin_id
	_pending_position = _return_position
	_pending_state = _origin_state.duplicate(true)
	var target_path: String = _origin_path
	active_clear()
	var error: Error = LEVEL_FLOW.change_scene(tree, target_path)
	if error != OK:
		_pending_resume = false
		_pending_origin_id = ""
		_pending_position = Vector2.ZERO
		_pending_state.clear()
	return error


## Consumed by the origin level's _ready.  One-shot: a later reload of the same
## origin (R, a new chapter entry) never receives the seed again.
static func consume_resume(origin_id: String) -> Dictionary:
	if not _pending_resume or _pending_origin_id != origin_id:
		return {}
	var result: Dictionary = {
		"origin_id": _pending_origin_id,
		"position": _pending_position,
		"state": _pending_state.duplicate(true),
	}
	_pending_resume = false
	_pending_origin_id = ""
	_pending_position = Vector2.ZERO
	_pending_state.clear()
	return result


static func has_pending_resume() -> bool:
	return _pending_resume


## Pause / game over / quit-to-title: the side run is over and no resume seed
## may be left for a later mainline reload.
static func abort() -> void:
	active_clear()
	_pending_resume = false
	_pending_origin_id = ""
	_pending_position = Vector2.ZERO
	_pending_state.clear()


static func active_clear() -> void:
	_active = false
	_target_id = ""
	_origin_id = ""
	_origin_path = ""
	_return_position = Vector2.ZERO
	_origin_state.clear()
	_progress_path = ""
