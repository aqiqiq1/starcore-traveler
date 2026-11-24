class_name DisplayOptions
extends RefCounted

## Pure display-size rules shared by the menu UI and the tests.
##
## The game always renders a 640x360 logical canvas.  Windowed output is one of
## the 16:9 integer multiples below; fullscreen uses the desktop size and lets
## the root Window keep the aspect with an integer scale and black bars.
## 1920x1080 is the one borderless windowed choice: a decorated window cannot
## fit it above a taskbar, but a borderless window can cover the whole screen
## at the exact 3x integer scale.  Nothing here talks to DisplayServer, so the
## screen-size filtering can be unit tested without changing the real window.

const LOGICAL_SIZE: Vector2i = Vector2i(640, 360)
const DEFAULT_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const MAX_SAVED_DIMENSION: int = 16384

## The only windowed candidate that runs with the border/title bar removed.
const BORDERLESS_SIZE: Vector2i = Vector2i(1920, 1080)

## Conservative frame/taskbar allowance used when decorations cannot be
## measured (headless, early startup).  The live controller replaces this with
## the measured decoration size where Windows reports it.
const DEFAULT_FRAME_MARGIN: Vector2i = Vector2i(24, 56)

const CANDIDATES: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

enum Mode { WINDOWED = 0, FULLSCREEN = 1 }


static func mode_to_text(mode: int) -> String:
	return "fullscreen" if mode == Mode.FULLSCREEN else "windowed"


static func mode_from_value(value: Variant) -> int:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var text: String = String(value).strip_edges().to_lower()
		if text == "fullscreen":
			return Mode.FULLSCREEN
		if text == "windowed" or text == "window":
			return Mode.WINDOWED
	return Mode.WINDOWED


static func format_size(size: Vector2i) -> String:
	return "%d×%d" % [size.x, size.y]


static func is_borderless_size(size: Vector2i) -> bool:
	return size == BORDERLESS_SIZE


## Label used by the resolution buttons.  The borderless option must say so,
## because the same 1920x1080 pixels behave differently from a framed window.
static func size_label(size: Vector2i) -> String:
	if is_borderless_size(size):
		return "%s（无边框）" % format_size(size)
	return format_size(size)


static func is_borderless_choice(mode: int, size: Vector2i) -> bool:
	return mode == Mode.WINDOWED and is_borderless_size(size)


static func available_size(usable_rect: Rect2i, frame_margin: Vector2i) -> Vector2i:
	var margin: Vector2i = Vector2i(maxi(frame_margin.x, 0), maxi(frame_margin.y, 0))
	return Vector2i(
		maxi(usable_rect.size.x - margin.x, 0),
		maxi(usable_rect.size.y - margin.y, 0)
	)


## Full screen rectangle.  Callers pass the live DisplayServer rect; tests and
## early startup can fall back to the usable rect plus the decoration margin.
static func windowed_screen_rect(
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	screen_rect: Rect2i = Rect2i()
) -> Rect2i:
	if screen_rect.size.x > 0 and screen_rect.size.y > 0:
		return screen_rect
	var margin: Vector2i = Vector2i(maxi(frame_margin.x, 0), maxi(frame_margin.y, 0))
	return Rect2i(usable_rect.position - margin, usable_rect.size + margin * 2)


static func fits_screen(size: Vector2i, screen_rect: Rect2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	if screen_rect.size.x <= 0 or screen_rect.size.y <= 0:
		return false
	return size.x <= screen_rect.size.x and size.y <= screen_rect.size.y


## A decorated window must leave room for its frame and title bar.
static func fits_bordered(size: Vector2i, usable_rect: Rect2i, frame_margin: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	var available: Vector2i = available_size(usable_rect, frame_margin)
	return size.x <= available.x and size.y <= available.y


## Whether the size is usable in windowed mode.  1920x1080 is allowed when the
## physical screen is at least that size, because that candidate runs
## borderless and therefore needs no decoration margin.
static func fits(
	size: Vector2i,
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	screen_rect: Rect2i = Rect2i()
) -> bool:
	if is_borderless_size(size):
		return fits_screen(size, windowed_screen_rect(usable_rect, frame_margin, screen_rect))
	return fits_bordered(size, usable_rect, frame_margin)


static func is_candidate(size: Vector2i) -> bool:
	return CANDIDATES.has(size)


static func candidate_entries(
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	screen_rect: Rect2i = Rect2i()
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var available: Vector2i = available_size(usable_rect, frame_margin)
	var screen: Rect2i = windowed_screen_rect(usable_rect, frame_margin, screen_rect)
	for size: Vector2i in CANDIDATES:
		var borderless: bool = is_borderless_size(size)
		var fits_now: bool = fits(size, usable_rect, frame_margin, screen)
		var reason: String = ""
		if not fits_now:
			if borderless:
				reason = "超出本屏 %s" % format_size(screen.size)
			else:
				reason = "超出本屏工作区 %s" % format_size(available)
		entries.append({
			"size": size,
			"fits": fits_now,
			"borderless": borderless,
			"label": size_label(size),
			"reason": reason,
		})
	return entries


## Largest approved candidate that fits, otherwise a 16:9 downscaled window
## that still stays inside the usable area.  Never returns the 2560x1440
## candidate on a smaller desktop just because it is in the list.
static func default_window_size(usable_rect: Rect2i, frame_margin: Vector2i) -> Vector2i:
	# Missing config keeps the project's 1280x720 default when the screen can
	# hold it.  A larger desktop must not silently promote a first run to
	# 1920/2560 just because those candidates fit.
	if fits(DEFAULT_WINDOW_SIZE, usable_rect, frame_margin):
		return DEFAULT_WINDOW_SIZE
	var smallest_candidate: Vector2i = CANDIDATES[0]
	if fits(smallest_candidate, usable_rect, frame_margin):
		return smallest_candidate
	return _fallback_fit(usable_rect, frame_margin)


static func resolve_window_size(
	requested: Vector2i,
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	screen_rect: Rect2i = Rect2i()
) -> Vector2i:
	if is_candidate(requested) and fits(requested, usable_rect, frame_margin, screen_rect):
		return requested
	return default_window_size(usable_rect, frame_margin)


static func validate_saved_state(
	mode_value: Variant,
	width_value: Variant,
	height_value: Variant,
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	borderless_value: Variant = null,
	screen_rect: Rect2i = Rect2i()
) -> Dictionary:
	var changed: bool = false
	var reasons: Array[String] = []
	var mode: int = Mode.WINDOWED
	if typeof(mode_value) == TYPE_STRING or typeof(mode_value) == TYPE_STRING_NAME:
		var text: String = String(mode_value).strip_edges().to_lower()
		if text == "fullscreen":
			mode = Mode.FULLSCREEN
		elif text == "windowed" or text == "window":
			mode = Mode.WINDOWED
		else:
			changed = true
			reasons.append("显示模式无效")
	else:
		changed = true
		reasons.append("显示模式缺失")

	var saved_size: Vector2i = Vector2i.ZERO
	var size_ok: bool = false
	var width: float = _numeric_value(width_value)
	var height: float = _numeric_value(height_value)
	if is_finite(width) and is_finite(height):
		if (
			width > 0.0 and height > 0.0
			and width <= float(MAX_SAVED_DIMENSION)
			and height <= float(MAX_SAVED_DIMENSION)
			and floorf(width) == width and floorf(height) == height
		):
			saved_size = Vector2i(int(width), int(height))
			size_ok = true
	if not size_ok:
		changed = true
		reasons.append("窗口尺寸无效")

	# Older configs have no borderless field.  Missing means "derive it from the
	# resolution"; the only resolution that means borderless is 1920x1080.
	# Unknown or contradictory values are corrected instead of failing to load.
	var borderless: bool = size_ok and is_borderless_size(saved_size)
	if borderless_value != null:
		if typeof(borderless_value) == TYPE_BOOL:
			borderless = bool(borderless_value)
			if borderless and not is_borderless_size(saved_size):
				borderless = false
				changed = true
				reasons.append("无边框标记与窗口尺寸不一致")
		else:
			changed = true
			reasons.append("无边框设置无效")

	var screen: Rect2i = windowed_screen_rect(usable_rect, frame_margin, screen_rect)
	var fit_now: bool = false
	if size_ok and is_candidate(saved_size):
		if borderless:
			fit_now = fits_screen(saved_size, screen)
		else:
			fit_now = fits_bordered(saved_size, usable_rect, frame_margin)
	var window_size: Vector2i = saved_size
	if not size_ok or not is_candidate(saved_size) or not fit_now:
		window_size = default_window_size(usable_rect, frame_margin)
		if size_ok:
			changed = true
			reasons.append("保存的窗口尺寸超出当前屏幕")
	var final_borderless: bool = (
		mode == Mode.WINDOWED and is_borderless_size(window_size)
	)
	return {
		"mode": mode,
		"window_size": window_size,
		"borderless": final_borderless,
		"changed": changed,
		"reason": "；".join(reasons),
	}


static func validate_choice(
	mode: int,
	window_size: Vector2i,
	usable_rect: Rect2i,
	frame_margin: Vector2i,
	screen_rect: Rect2i = Rect2i()
) -> Dictionary:
	if mode != Mode.WINDOWED and mode != Mode.FULLSCREEN:
		return {
			"ok": false,
			"message": "显示模式无效",
			"mode": Mode.WINDOWED,
			"window_size": window_size,
			"borderless": false,
		}
	if mode == Mode.FULLSCREEN:
		if window_size.x <= 0 or window_size.y <= 0:
			return {
				"ok": false,
				"message": "窗口目标尺寸无效",
				"mode": mode,
				"window_size": default_window_size(usable_rect, frame_margin),
				"borderless": false,
			}
		return {
			"ok": true,
			"message": "",
			"mode": mode,
			"window_size": window_size,
			"borderless": false,
		}
	if not is_candidate(window_size):
		return {
			"ok": false,
			"message": "分辨率不在允许列表中",
			"mode": mode,
			"window_size": window_size,
			"borderless": false,
		}
	if is_borderless_size(window_size):
		var screen: Rect2i = windowed_screen_rect(usable_rect, frame_margin, screen_rect)
		if not fits_screen(window_size, screen):
			return {
				"ok": false,
				"message": "无边框窗口需要至少 %s 的屏幕" % format_size(window_size),
				"mode": mode,
				"window_size": window_size,
				"borderless": true,
			}
		return {
			"ok": true,
			"message": "",
			"mode": mode,
			"window_size": window_size,
			"borderless": true,
		}
	if not fits_bordered(window_size, usable_rect, frame_margin):
		return {
			"ok": false,
			"message": "窗口尺寸超出当前屏幕工作区",
			"mode": mode,
			"window_size": window_size,
			"borderless": false,
		}
	return {
		"ok": true,
		"message": "",
		"mode": mode,
		"window_size": window_size,
		"borderless": false,
	}


## Physical content rectangle inside a window for the 640x360 canvas.
## Integer upscaling is used whenever possible; the leftover area is black.
static func content_rect(window_size: Vector2i, logical_size: Vector2i = LOGICAL_SIZE) -> Rect2i:
	if window_size.x <= 0 or window_size.y <= 0 or logical_size.x <= 0 or logical_size.y <= 0:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	var integer_scale: int = mini(window_size.x / logical_size.x, window_size.y / logical_size.y)
	if integer_scale >= 1:
		var content: Vector2i = logical_size * integer_scale
		return Rect2i((window_size - content) / 2, content)
	# Very small compatibility windows downscale fractionally but keep 16:9.
	var scale: float = minf(
		float(window_size.x) / float(logical_size.x),
		float(window_size.y) / float(logical_size.y)
	)
	var content_size: Vector2i = Vector2i(
		maxi(int(floorf(float(logical_size.x) * scale)), 1),
		maxi(int(floorf(float(logical_size.y) * scale)), 1)
	)
	return Rect2i((window_size - content_size) / 2, content_size)


static func integer_scale(window_size: Vector2i, logical_size: Vector2i = LOGICAL_SIZE) -> int:
	return mini(window_size.x / logical_size.x, window_size.y / logical_size.y)


static func _numeric_value(value: Variant) -> float:
	if typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_FLOAT:
		return float(value)
	return NAN


static func _fallback_fit(usable_rect: Rect2i, frame_margin: Vector2i) -> Vector2i:
	var available: Vector2i = available_size(usable_rect, frame_margin)
	if available.x <= 0 or available.y <= 0:
		# No usable desktop area was reported.  Keep a tiny 16:9 request; the
		# controller still clamps the position to the usable origin.
		return Vector2i(16, 9)
	if available.x < 16 or available.y < 9:
		return Vector2i(maxi(available.x, 1), maxi(available.y, 1))
	var scale: float = minf(
		float(available.x) / float(LOGICAL_SIZE.x),
		float(available.y) / float(LOGICAL_SIZE.y)
	)
	scale = minf(scale, 1.0)
	var width: int = maxi(int(floorf(float(LOGICAL_SIZE.x) * scale)), 16)
	var height: int = int(roundf(float(width) * 9.0 / 16.0))
	if height > available.y:
		height = maxi(available.y, 9)
		width = int(floorf(float(height) * 16.0 / 9.0))
	width = clampi(width, 16, available.x)
	height = clampi(height, 9, available.y)
	if width > 32 and width % 2 != 0:
		width -= 1
	if height > 18 and height % 2 != 0:
		height -= 1
	return Vector2i(width, height)
