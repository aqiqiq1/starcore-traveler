class_name MechanicTeach
extends Node

## First-encounter teaching for every row in MechanicRegistry.
##
## A level or DLC chapter creates one node, binds `show_line` to its own HUD
## event row, and calls `request(id)` / `observe_near(...)` from the real
## mechanism (door approach, bay, rune, guard start, first hazard...).  The
## first accepted id is persisted in user://mechanic_progress.cfg, so the same
## mechanism never teaches again in any later chapter or launch.  Repeats in
## the same launch are also suppressed by the in-memory dictionary.
##
## This node owns no gameplay state, collision or gates.  It only:
##   * de-duplicates an id across the whole save,
##   * writes the progress file safely (missing/corrupt -> empty, never crash),
##   * shows the registry `summary` once through the host HUD,
##   * queues a request while a guide/pause/other page owns the screen.
##
## Test isolation: STAR_CORE_MECHANIC_PROGRESS or
## set_progress_path_override() may point at a throwaway file.  Production uses
## the exact user://mechanic_progress.cfg path.

signal taught(id: String)

const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")
const DEFAULT_PROGRESS_PATH: String = "user://mechanic_progress.cfg"
const PROGRESS_ENV: String = "STAR_CORE_MECHANIC_PROGRESS"
const SECTION: String = "mechanics"
const LINE_COOLDOWN: float = 2.2
const DEFAULT_RADIUS: float = 56.0
const DEFAULT_Y_SLACK: float = 72.0

static var _progress_override: String = ""

## Bound by the host before the first request.  `show_line` receives the
## registry summary and should display it for about 2.4 s.
var show_line: Callable = Callable()
## Optional host state callback.  True means a guide / pause page / completion
## page currently owns the screen; the request stays queued.
var blocked_check: Callable = Callable()

var _unlocked: Dictionary = {}
var _pending: Array[String] = []
var _cooldown_left: float = 0.0
var _last_shown_id: String = ""
var _last_line: String = ""
var _taught_count: int = 0
var _loaded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_progress()
	set_process(true)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0 and not _pending.is_empty():
		_try_show_head()


# --- Progress file ---------------------------------------------------------

static func set_progress_path_override(path: String) -> void:
	_progress_override = path


static func clear_progress_path_override() -> void:
	_progress_override = ""


static func get_progress_path() -> String:
	if not _progress_override.is_empty():
		return _progress_override
	var from_env: String = OS.get_environment(PROGRESS_ENV).strip_edges()
	if not from_env.is_empty():
		return from_env
	return DEFAULT_PROGRESS_PATH


## Missing, unreadable or malformed files simply produce an empty set.  Values
## that are not real bools are ignored rather than coerced.
static func load_unlocked_ids(path: String = "") -> Dictionary:
	var result: Dictionary = {}
	var resolved: String = path if not path.is_empty() else get_progress_path()
	if resolved.is_empty():
		return result
	if not FileAccess.file_exists(resolved):
		return result
	var source: String = FileAccess.get_file_as_string(resolved)
	if not _looks_like_config(source):
		return result
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.parse(source)
	if err != OK:
		return result
	for id: String in REGISTRY.all_ids():
		var value: Variant = config.get_value(SECTION, id, false)
		if typeof(value) == TYPE_BOOL and bool(value):
			result[id] = true
	return result


## Cheap structural screen before ConfigFile.parse.  A truncated or binary
## user file is rejected here so Godot never prints a parse error while a
## player launches with a damaged save.
static func _looks_like_config(source: String) -> bool:
	if source.strip_edges().is_empty():
		return false
	var has_section: bool = false
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("["):
			if not line.ends_with("]"):
				return false
			has_section = true
			continue
		if line.contains("="):
			continue
		return false
	return has_section


func load_progress() -> void:
	_unlocked = load_unlocked_ids(get_progress_path())
	_loaded = true


func save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	for id: String in REGISTRY.all_ids():
		if _unlocked.has(id):
			config.set_value(SECTION, id, true)
	# A failed save (read-only user dir, bad path) must not interrupt play; the
	# in-memory set still suppresses repeats for this launch.
	config.save(get_progress_path())


# --- Public state ----------------------------------------------------------

func is_loaded() -> bool:
	return _loaded


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func get_unlocked_count() -> int:
	return _unlocked.size()


func get_unlocked_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in REGISTRY.all_ids():
		if _unlocked.has(id):
			ids.append(id)
	return ids


func get_pending_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_pending)
	return ids


func get_last_shown_id() -> String:
	return _last_shown_id


func get_last_line() -> String:
	return _last_line


func get_taught_count() -> int:
	return _taught_count


func get_cooldown_left() -> float:
	return _cooldown_left


## Manual/test helper: records an id without showing a line.  Production
## triggers use request()/observe_near().  Returns true when it was new.
func mark_unlocked(id: String) -> bool:
	if not REGISTRY.has(id) or _unlocked.has(id):
		return false
	_unlocked[id] = true
	save_progress()
	return true


# --- Triggering ------------------------------------------------------------

## Queue a mechanism.  Returns true only when this call displayed the line
## immediately; a line blocked by a guide/pause or waiting behind another line
## returns false and is shown later by _process.
func request(id: String) -> bool:
	if not REGISTRY.has(id) or _unlocked.has(id) or _pending.has(id):
		return false
	_pending.append(id)
	return _try_show_head()


## Proximity trigger with an explicit world object.  `facing` is the player's
## -1/1 facing; require_facing is used by doors.  `y_slack` 0 disables the
## vertical band.  The caller still owns the actual object reference, so no
## chapter-specific x coordinate lives here.
func observe_near(
	id: String,
	object_position: Vector2,
	player_position: Vector2,
	facing: int = 0,
	radius: float = DEFAULT_RADIUS,
	y_slack: float = DEFAULT_Y_SLACK,
	require_facing: bool = false
) -> bool:
	var dx: float = object_position.x - player_position.x
	if absf(dx) > radius:
		return false
	if y_slack > 0.0 and absf(object_position.y - player_position.y) > y_slack:
		return false
	if require_facing:
		if is_zero_approx(dx) or signf(dx) != float(facing):
			return false
	return request(id)


## For hosts that already computed distance/facing (the old ApproachHint
## paths).  Same one-shot semantics as observe_near.
func observe_distance(
	id: String,
	distance: float,
	facing_toward: bool = true,
	radius: float = DEFAULT_RADIUS
) -> bool:
	if distance > radius or not facing_toward:
		return false
	return request(id)


# --- Internal --------------------------------------------------------------

func _is_blocked() -> bool:
	if blocked_check.is_valid():
		return bool(blocked_check.call())
	return false


func _try_show_head() -> bool:
	if _pending.is_empty() or _cooldown_left > 0.0:
		return false
	if _is_blocked():
		return false
	var id: String = _pending[0]
	if not REGISTRY.has(id) or _unlocked.has(id):
		_pending.pop_front()
		return false
	_pending.pop_front()
	_unlocked[id] = true
	save_progress()
	_last_shown_id = id
	_last_line = REGISTRY.get_summary(id)
	_cooldown_left = LINE_COOLDOWN
	_taught_count += 1
	if show_line.is_valid():
		show_line.call(_last_line)
	taught.emit(id)
	return true


## Test-only convenience: forget the in-memory set and reload the configured
## file.  The file itself is not deleted (tests own their override path).
func reset_for_test() -> void:
	_unlocked.clear()
	_pending.clear()
	_cooldown_left = 0.0
	_last_shown_id = ""
	_last_line = ""
	_taught_count = 0
	load_progress()
