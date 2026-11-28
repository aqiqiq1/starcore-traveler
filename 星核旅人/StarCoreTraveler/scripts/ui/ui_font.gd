class_name UiFont
extends RefCounted

## The one pixel font behind every player-visible UI label.
##
## `tutorial_zh.ttf` is authored for integer sizes 12 (body) and 24 (titles).
## Every UI surface must draw it at one of those native sizes, with
## antialiasing, hinting and subpixel positioning disabled, no system fallback,
## no mipmaps and `oversampling = 1.0`.  Oversampling is the important one for a
## 2x window: the automatic value (0) follows the window scale, so the atlas can
## be rasterised at 24 px for a 12 px label and then resampled; forcing 1.0 keeps
## the glyph atlas at the exact size the 640x360 viewport draws.  This helper is
## the single copy of those settings; individual overlays must not duplicate it.
##
## 2026-11-28: extracted from the ~25 per-script `_load_font()` copies that had
## drifted (some missed `oversampling`, `generate_mipmaps` or the fallback),
## which is why the same font looked different between pages and at 2x.

const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

## Native pixel sizes.  Any other size resamples the glyph outlines.
const BODY_SIZE: int = 12
const TITLE_SIZE: int = 24

## 12 px CJK glyphs have 1 px inner counters; a 2 px dark outline closes them and
## makes the row read as a bold smear.  1 px is the approved maximum.
const OUTLINE_SIZE: int = 1

static var _shared: FontFile = null
static var _checked: bool = false


## Shared FontFile with the approved pixel settings.  The returned object is
## cached for the process, so callers must not mutate it.
static func get_font() -> Font:
	var font: FontFile = get_font_file()
	return font if font != null else ThemeDB.fallback_font


## Same object typed as FontFile, or null when the asset is missing.  Callers
## that cache the result (drawn text helpers) use this overload.
static func get_font_file() -> FontFile:
	if _checked:
		return _shared
	_checked = true
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("UiFont: %s is missing; using the engine fallback" % FONT_PATH)
		return null
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		push_warning("UiFont: %s did not load as FontFile" % FONT_PATH)
		return null
	# Keep the imported resource untouched: other systems may use it for
	# measurements.  The copy below is the shared UI face.
	var font: FontFile = base.duplicate() as FontFile
	if font == null:
		font = base
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = false
	font.generate_mipmaps = false
	font.oversampling = 1.0
	_shared = font
	return font


## True for the two native sizes.  Tests use this instead of repeating 12/24.
static func is_native_size(font_size: int) -> bool:
	return font_size == BODY_SIZE or font_size == TITLE_SIZE
