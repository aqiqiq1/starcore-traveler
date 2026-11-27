class_name ApproachHint
extends RefCounted

## One-shot proximity hint for a world device.
##
## The device only speaks when the player is close, in front of it and facing
## it.  Contact no longer raises a second copy.  After the player leaves by more
## than REARM_DISTANCE the hint may arm again, but the same line is never shown
## twice inside REPEAT_COOLDOWN_MSEC.  A blocked re-entry consumes the arming,
## so the player must leave 200 px again rather than stand in range until the
## cooldown expires.

const SHOW_DISTANCE: float = 56.0
const REARM_DISTANCE: float = 200.0
const REPEAT_COOLDOWN_MSEC: int = 10000

var _armed: bool = true
var _last_shown_msec: int = -REPEAT_COOLDOWN_MSEC
var _shown_count: int = 0


func reset() -> void:
	_armed = true
	_last_shown_msec = -REPEAT_COOLDOWN_MSEC
	_shown_count = 0


## Returns true at most once per approach.  `distance` is the absolute
## horizontal gap; `facing_toward` must include the game's own in-scene and
## vertical checks.
func tick(distance: float, facing_toward: bool, now_msec: int) -> bool:
	if not _armed:
		if distance > REARM_DISTANCE:
			_armed = true
		return false
	if distance > SHOW_DISTANCE or not facing_toward:
		return false
	_armed = false
	if now_msec - _last_shown_msec < REPEAT_COOLDOWN_MSEC:
		return false
	_last_shown_msec = now_msec
	_shown_count += 1
	return true


func is_armed() -> bool:
	return _armed


func get_shown_count() -> int:
	return _shown_count


func get_last_shown_msec() -> int:
	return _last_shown_msec
