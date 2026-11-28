extends Node

## Acceptance for the 2026-11-28 wording + text-layout pass.
##
## Headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/text_layout_20261128/tests/text_layout_test.tscn
##
## Covers:
##   - chapter-page tags are 第四关 / 隐藏关, with no DLC numbering left
##   - title 章节 page side hint uses 隐藏关
##   - no player-visible string literal in shipped scripts/scenes contains
##     DLC1/DLC2/DLC3 or 支线 (test/tool harnesses are whitelisted)
##
## The manual's pitch, page indicator, page turns, ellipsis and column gutters
## are asserted in res://scripts/ui/tests/mechanic_manual_test.gd; the six
## completion emblems in pause_completion_alignment_test.gd.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const START_MENU_PATH: String = "res://scripts/start_menu.gd"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://dlc", "res://scenes"]

## Dev harnesses and this audit folder are allowed to name the internal DLC
## numbering in their labels/logs; they are not shipped player copy.
const WHITELIST_PARTS: Array[String] = [
	"/tests/", "/tools/", "text_layout_20261128/", "audit_20261128/",
	"_20261127/", "_20261128/", "hud_fix_20261127/", "hint_timing/",
	"core_art_20261127/", "core_badge_20261127/", "art_audit_20261127/",
	"hidden_levels_20261127/", "chapter_select/tests/", "opening_l1/tests/",
]

const BANNED: Array[String] = ["DLC1", "DLC2", "DLC3", "支线"]

var _checks: int = 0
var _failures: Array[String] = []
var _scanned: int = 0
var _literals: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("TEXT_LAYOUT_TEST checks=%d failures=%d scanned=%d literals=%d" % [
		_checks, _failures.size(), _scanned, _literals
	])
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: %s%s" % [label, (" [%s]" % detail) if not detail.is_empty() else ""])
		return
	_failures.append(label + ((" [" + detail + "]") if not detail.is_empty() else ""))
	print("FAIL: %s%s" % [label, (" [" + detail + "]") if not detail.is_empty() else ""])


func _run() -> void:
	# --- chapter tags ----------------------------------------------------
	var loom: Dictionary = CHAPTER_PROGRESS.get_chapter(CHAPTER_PROGRESS.ID_LOOM)
	var rift: Dictionary = CHAPTER_PROGRESS.get_chapter(CHAPTER_PROGRESS.ID_RIFT)
	_check(
		String(loom.get("tag", "")) == "第四关",
		"loom chapter row tag reads 第四关",
		String(loom.get("tag", ""))
	)
	_check(
		String(rift.get("tag", "")) == "隐藏关",
		"rift chapter row tag reads 隐藏关",
		String(rift.get("tag", ""))
	)
	for chapter: Dictionary in CHAPTER_PROGRESS.CHAPTERS:
		var tag: String = String(chapter.get("tag", ""))
		var title: String = String(chapter.get("title", ""))
		_check(
			not tag.contains("DLC") and not tag.contains("支线"),
			"chapter tag %s has no DLC/支线" % String(chapter.get("id", "")),
			tag
		)
		_check(
			not title.contains("DLC") and not title.contains("支线"),
			"chapter title %s has no DLC/支线" % String(chapter.get("id", "")),
			title
		)

	# --- title chapter-page side hint ------------------------------------
	var start_menu_text: String = FileAccess.get_file_as_string(START_MENU_PATH)
	var hint_line: String = ""
	for line: String in start_menu_text.split("\n"):
		if line.contains("CHAPTERS_SIDE_HINT_TEXT"):
			hint_line = line
			break
	_check(
		hint_line.contains("隐藏关") and not hint_line.contains("支线"),
		"title chapter-page side hint says 隐藏关",
		hint_line.strip_edges()
	)

	# --- visible string scan --------------------------------------------
	var files: Array[String] = []
	for root: String in SCAN_ROOTS:
		_collect_files(root, files)
	_check(files.size() > 200, "the scan really covers the project",
		str(files.size()))
	var hits: Array[String] = []
	for path: String in files:
		if _is_whitelisted(path):
			continue
		_scanned += 1
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var line_number: int = 0
		for line: String in text.split("\n"):
			line_number += 1
			for literal: String in _string_literals(line):
				_literals += 1
				for banned: String in BANNED:
					if literal.contains(banned):
						hits.append("%s:%d %s -> %s" % [
							path, line_number, banned, literal
						])
	_check(
		hits.is_empty(),
		"no player-visible DLC1/2/3 or 支线 string outside whitelisted tests",
		", ".join(hits.slice(0, 6))
	)


func _collect_files(path: String, out: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full: String = path.path_join(entry)
		if directory.current_is_dir():
			_collect_files(full, out)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn"):
			out.append(full)
		entry = directory.get_next()
	directory.list_dir_end()


func _is_whitelisted(path: String) -> bool:
	for part: String in WHITELIST_PARTS:
		if path.contains(part):
			return true
	return false


## Extracts double/single quoted literals from one source line, stopping at a
## `#` that is outside a string.  Good enough for this project's GDScript/tscn
## style; multi-line strings are not used for player copy.
func _string_literals(line: String) -> Array[String]:
	var out: Array[String] = []
	var quote: String = ""
	var current: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if quote.is_empty():
			if character == "#":
				break
			if character == "\"" or character == "'":
				quote = character
				current = ""
			index += 1
			continue
		if character == "\\" and index + 1 < line.length():
			current += line[index + 1]
			index += 2
			continue
		if character == quote:
			out.append(current)
			quote = ""
			current = ""
			index += 1
			continue
		current += character
		index += 1
	return out
