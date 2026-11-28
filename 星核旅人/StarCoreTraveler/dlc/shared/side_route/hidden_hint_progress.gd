class_name HiddenHintProgress
extends RefCounted

## One-shot local markers for the hidden side-route hints.
##
## These lines are not mechanism lessons (MechanicTeach) and not chapter flags
## (ChapterProgress): they belong to the presentation of this save.  A separate
## tiny file keeps them from rewriting either approved schema.
##
## Missing, empty or malformed files read as "not shown yet"; a write always
## rewrites the whole file.  Tests pass a throwaway path through the host's
## `hint_progress_path`; `STAR_CORE_HIDDEN_HINT` isolates the headless suite.

const DEFAULT_PATH: String = "user://hidden_hint.cfg"
const ENV_PATH: String = "STAR_CORE_HIDDEN_HINT"
const SECTION: String = "hints"

## DLC3 checkpoint line: only the first recorded checkpoint in this save shows
## the mirror nudge.
const CHECKPOINT_MIRROR: String = "checkpoint_mirror"


static func resolve_path(path: String = "") -> String:
	if not path.is_empty():
		return path
	var from_env: String = OS.get_environment(ENV_PATH).strip_edges()
	if not from_env.is_empty():
		return from_env
	return DEFAULT_PATH


static func is_shown(key: String, path: String = "") -> bool:
	if key.is_empty():
		return false
	var resolved: String = resolve_path(path)
	if not FileAccess.file_exists(resolved):
		return false
	var config: ConfigFile = ConfigFile.new()
	if config.load(resolved) != OK:
		return false
	var value: Variant = config.get_value(SECTION, key, false)
	return typeof(value) == TYPE_BOOL and bool(value)


static func mark_shown(key: String, path: String = "") -> Error:
	if key.is_empty():
		return ERR_INVALID_PARAMETER
	var resolved: String = resolve_path(path)
	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(resolved):
		if config.load(resolved) != OK:
			config = ConfigFile.new()
	config.set_value(SECTION, key, true)
	return config.save(resolved)
