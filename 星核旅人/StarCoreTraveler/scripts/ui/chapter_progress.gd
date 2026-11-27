extends RefCounted

## Tiny, chapter-only progress store for the title's 章节 page.
##
## It keeps exactly six booleans: one "completed" flag per chapter.  Unlocking
## is derived from those flags, never stored:
##   L1  always
##   L2  L1 complete        L3  L2 complete
##   loom (DLC3 / 4th) L3 complete
##   trial (DLC1)      L1 complete
##   rift (DLC2)       L2 complete
##
## The file is written only from a chapter's real completion callback.  A
## missing, unreadable or malformed file falls back to "nothing completed",
## which leaves only L1 open.  Existing checkpoints/audio/display settings are
## separate files and are never touched here.

const DEFAULT_PATH: String = "user://chapter_progress.cfg"
const SECTION: String = "chapters"

const ID_L1: String = "l1"
const ID_L2: String = "l2"
const ID_L3: String = "l3"
const ID_LOOM: String = "loom"
const ID_TRIAL: String = "trial"
const ID_RIFT: String = "rift"

## Display order is also the "first unfinished chapter" order used by 开始游戏.
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
		"id": ID_TRIAL,
		"title": "星核试炼场",
		"tag": "DLC1 · 支线",
		"path": "res://dlc/trial_chambers/trial_chambers.tscn",
		"requires": ID_L1,
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


## Missing / unreadable / malformed files all resolve to "nothing completed".
static func load_completed(path: String = "") -> Dictionary:
	var completed: Dictionary = {}
	for chapter: Dictionary in CHAPTERS:
		completed[String(chapter["id"])] = false
	var settings_path: String = resolve_path(path)
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(settings_path)
	if error != OK:
		return completed
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		var raw: Variant = config.get_value(SECTION, id, false)
		completed[id] = typeof(raw) == TYPE_BOOL and bool(raw)
	return completed


static func is_completed(id: String, completed: Dictionary) -> bool:
	return bool(completed.get(id, false))


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


## First chapter in display order that is not completed and whose scene exists.
## Returns "" when everything is complete or no scene is available.
static func first_uncompleted(completed: Dictionary, require_available: bool = true) -> String:
	for chapter: Dictionary in CHAPTERS:
		var id: String = String(chapter["id"])
		if is_completed(id, completed):
			continue
		if require_available and not is_available(id):
			continue
		return id
	return ""


## Writes one completion flag.  The file is always rewritten with all six
## booleans (unreadable files become six false values plus this flag), so the
## schema stays exactly six bools and partial/corrupt files self-heal.
static func mark_completed(id: String, path: String = "") -> Error:
	if get_chapter(id).is_empty():
		return ERR_INVALID_PARAMETER
	var settings_path: String = resolve_path(path)
	var completed: Dictionary = load_completed(settings_path)
	completed[id] = true
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
	var error: Error = config.save(settings_path)
	if error != OK:
		push_warning("ChapterProgress: could not save %s (error %d)" % [settings_path, error])
	return error
