class_name MechanicTips
extends RefCounted

## Run-scoped "already shown" memory for the mechanic teaching popups.
##
## Static on purpose: it survives R restarts and level scene changes inside one
## launch, and it deliberately never writes user:// (cross-launch memory is not
## part of the approved spec). Restarting the executable clears it.

static var _seen: Dictionary = {}


static func has_seen(id: String) -> bool:
	return _seen.has(id)


static func mark_seen(id: String) -> void:
	if id.is_empty():
		return
	_seen[id] = true


static func get_seen_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in _seen.keys():
		ids.append(String(key))
	ids.sort()
	return ids


## Test-only helper. Production code never calls this.
static func reset_for_test() -> void:
	_seen.clear()
