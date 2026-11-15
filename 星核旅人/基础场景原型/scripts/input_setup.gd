extends Node

## Registers the prototype's input map at runtime so the project file stays
## readable and rebindable without hand-editing InputEvent serialization.

func _enter_tree() -> void:
	_add_action(&"move_left", [KEY_A, KEY_LEFT])
	_add_action(&"move_right", [KEY_D, KEY_RIGHT])
	_add_action(&"jump", [KEY_SPACE])
	_add_action(&"polarity", [KEY_Q])
	_add_action(&"reset", [KEY_R])
	_add_action(&"pause", [KEY_ESCAPE])
	_add_action(&"toggle_debug", [KEY_F3])
	_add_action(&"toggle_anchor_room", [KEY_F2])
	_add_action(&"toggle_interaction_room", [KEY_F4])
	_add_action(&"toggle_record_room", [KEY_F7])
	_add_action(&"interact", [KEY_E])
	_add_action(&"tutorial_next", [KEY_F])


func _add_action(action: StringName, physical_keys: Array[int]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in physical_keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key as Key
		InputMap.action_add_event(action, event)
