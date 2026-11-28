extends RefCounted

## Tiny, chapter-only progress store for the title's 章节 page.
##
## It keeps five "completed" flags (one per listed chapter) plus one
## "discovered" flag for the hidden side chapter.  Unlocking is derived from the
## completion flags, never stored:
##   L1  always
##   L2  L1 complete        L3  L2 complete
##   loom (DLC3 / 4th) L3 complete
##   rift (DLC2)       L2 complete
##
## 星核试炼场 (DLC1) is no longer a chapter-page row (2026-11-28).  Its scenes
## and tests stay in the project and the chapter can still be launched directly,
## but it has no row, no discovery write and no 开始游戏 target.  ID_TRIAL stays
## exported only so the standalone trial scene can keep referring to its old id.
##
## Visibility is separate from unlocking: the four mainline rows are always
## part of the chapter page, while rift stays hidden until its in-level
## entrance has really been entered.  Discovery is written by the entrance,
## not by completion, and never changes the unlock rule.
##
## A missing, unreadable or malformed file falls back to "nothing completed,
## nothing discovered", which leaves only L1 open and hides the side row.
## Older files that contain the old six booleans still load: the extra trial
## key is ignored.  Existing checkpoints/audio/display settings are separate
## files and are never touched here.

const DEFAULT_PATH: String = "user://chapter_progress.cfg"
const SECTION: String = "chapters"

const ID_L1: String = "l1"
const ID_L2: String = "l2"
const ID_L3: String = "l3"
const ID_LOOM: String = "loom"
## Legacy standalone-scene id, intentionally not a chapter row.
const ID_TRIAL: String = "trial"
const ID_RIFT: String = "rift"

const DISCOVERY_KEY_PREFIX: String = "discovered_"
const SIDE_CHAPTERS: Array[String] = [ID_RIFT]

## Display order is also the "first unfinished chapter" order used by 开始游戏.
## Exactly five rows: four mainline chapters plus the rift side chapter.
const CHAPTERS: Array[Dictionary] = [
	{
		"id": ID_L1,
		"title": "断桥庭院",
		"tag": "L1",
		"path": "res://scenes/level_01.tscn",
		"requires": "",
	},
	{
		"id": ID_L2,
		"title": "沉寂回廊",
		"tag": "L2",
		"path": "res://scenes/level_02.tscn",
		"requires": ID_L1,
	},
	{
		"id": ID_L3,
		"title": "断桥外郭",
		"tag": "L3",
		"path": "res://scenes/level_03.tscn",
		"requires": ID_L2,
	},
	{
		"id": ID_LOOM,
		"title": "星核织机·城内",
		"tag": "DLC3 · 第四关",
		"path": "res://dlc/star_loom/star_loom.tscn",
		"requires": ID_L3,
	},
	{
		"id": ID_RIFT,
		"title": "裂隙工坊",
		"tag": "DLC2 · 支线",
		"path": "res://dlc/rift_workshop/rift_workshop.tscn",
		"requires": ID_L2,
	},
]


static func resolve_path(path: String = "") -> String:
	return DEFAULT_PATH if path.is_empty() else path


static func get_chapter(id: String) -> Dictionary:
	for chapter: Dictionary in CHAPTERS:
		if String(chapter["id"]) == id:
			return chapter
	return {}


static func chapter_ids() -> Array[String]:
	var ids: Array[String] = []
	for chapter: Dictionary in CHAPTERS:
		ids.append(String(chapter["id"]))
	return ids


static func chapter_count() -> int:
	return CHAPTERS.size()


## Missing / unreadable / malformed files all resolve to "nothing completed,
## nothing discovered".
static func load_completed(path: String = "") -> Dictionary:
	var completed: Dictionary = {}
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		completed[id] = false
		if is_side_chapter(id):
			completed[discovery_key(id)] = false
	var settings_path: String = resolve_path(path)
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(settings_path)
	if error != OK:
		return completed
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		var raw: Variant = config.get_value(SECTION, id, false)
		completed[id] = typeof(raw) == TYPE_BOOL and bool(raw)
		if not is_side_chapter(id):
			continue
		var raw_discovered: Variant = config.get_value(
			SECTION, discovery_key(id), false
		)
		completed[discovery_key(id)] = (
			typeof(raw_discovered) == TYPE_BOOL and bool(raw_discovered)
		)
	return completed


static func is_completed(id: String, completed: Dictionary) -> bool:
	return bool(completed.get(id, false))


static func discovery_key(id: String) -> String:
	return DISCOVERY_KEY_PREFIX + id


static func is_side_chapter(id: String) -> bool:
	return SIDE_CHAPTERS.has(id)


## Mainline rows are always part of the page.  A side row appears only after
## its in-level entrance has been entered; a legacy file therefore keeps the
## side row hidden until the player really finds it.  An id that is not one of
## the five listed chapters (for example the retired trial id) is never visible.
static func is_discovered(id: String, completed: Dictionary) -> bool:
	if get_chapter(id).is_empty():
		return false
	if not is_side_chapter(id):
		return true
	return bool(completed.get(discovery_key(id), false))


static func is_visible(id: String, completed: Dictionary) -> bool:
	return is_discovered(id, completed)


static func is_unlocked(id: String, completed: Dictionary) -> bool:
	var chapter: Dictionary = get_chapter(id)
	if chapter.is_empty():
		return false
	var requires: String = String(chapter["requires"])
	return requires.is_empty() or is_completed(requires, completed)


## Scene presence is separate from progression so a missing DLC folder never
## crashes the title and never counts as "unlocked".
static func is_available(id: String) -> bool:
	var chapter: Dictionary = get_chapter(id)
	if chapter.is_empty():
		return false
	return ResourceLoader.exists(String(chapter["path"]))


static func required_title(id: String) -> String:
	var chapter: Dictionary = get_chapter(id)
	if chapter.is_empty():
		return ""
	var requires: String = String(chapter["requires"])
	if requires.is_empty():
		return ""
	return String(get_chapter(requires).get("title", ""))


## First chapter in display order that is not completed, visible and (by
## default) whose scene exists.  Hidden side chapters are skipped so 开始游戏
## never sends the player to an undiscovered row.  Returns "" when everything
## visible is complete or no scene is available.
static func first_uncompleted(
	completed: Dictionary,
	require_available: bool = true,
	require_visible: bool = true
) -> String:
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		if is_completed(id, completed):
			continue
		if require_visible and not is_visible(id, completed):
			continue
		if require_available and not is_available(id):
			continue
		return id
	return ""


## Title-only unlock-all used by the hidden kskbl sequence.  Writes the same
## schema as a real completion, marking every chapter completed and discovered
## so every derived unlock is true and both side rows are visible.
static func complete_all(path: String = "") -> Error:
	var completed: Dictionary = {}
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		completed[id] = true
		if is_side_chapter(id):
			completed[discovery_key(id)] = true
	return _save_completed(completed, resolve_path(path))


## Writes one completion flag.  The file is always rewritten with all
## completion and discovery flags (unreadable files become false values plus
## this flag), so partial/corrupt files self-heal without losing discovery.
static func mark_completed(id: String, path: String = "") -> Error:
	if get_chapter(id).is_empty():
		return ERR_INVALID_PARAMETER
	var settings_path: String = resolve_path(path)
	var completed: Dictionary = load_completed(settings_path)
	completed[id] = true
	return _save_completed(completed, settings_path)


## Written by a hidden entrance the moment the player really enters it; no
## completion is required.  Mainline ids are ignored.
static func mark_discovered(id: String, path: String = "") -> Error:
	if not is_side_chapter(id):
		return ERR_INVALID_PARAMETER
	var settings_path: String = resolve_path(path)
	var completed: Dictionary = load_completed(settings_path)
	completed[discovery_key(id)] = true
	return _save_completed(completed, settings_path)


static func forget(id: String, path: String = "") -> Error:
	if get_chapter(id).is_empty():
		return ERR_INVALID_PARAMETER
	var settings_path: String = resolve_path(path)
	var completed: Dictionary = load_completed(settings_path)
	completed[id] = false
	return _save_completed(completed, settings_path)


static func _save_completed(completed: Dictionary, settings_path: String) -> Error:
	var config: ConfigFile = ConfigFile.new()
	for chapter: Dictionary in CHAPTERS:
		var chapter_id: String = String(chapter["id"])
		config.set_value(SECTION, chapter_id, bool(completed.get(chapter_id, false)))
		if is_side_chapter(chapter_id):
			config.set_value(
				SECTION, discovery_key(chapter_id),
				bool(completed.get(discovery_key(chapter_id), false))
			)
	var error: Error = config.save(settings_path)
	if error != OK:
		push_warning("ChapterProgress: could not save %s (error %d)" % [settings_path, error])
	return error
