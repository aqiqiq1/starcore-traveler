class_name L3FloatRoute
extends Node2D

## Per-block floating route. There is no global 20 s timer: each block is
## triggered only by the player actually standing on it. Unstepped blocks stay
## stable indefinitely. The fixed device can rebuild the whole group at any
## time after it has been activated; a fall restores the device and resets the
## group to resting rubble.

signal all_stable
signal block_warning(index: int)
signal block_dropped(index: int)

@export var stagger: float = 0.06

var _blocks: Array[L3FloatBlock] = []
var _running: bool = false
var _stable_count: int = 0


func _ready() -> void:
	for child: Node in get_children():
		if child is L3FloatBlock:
			var block: L3FloatBlock = child as L3FloatBlock
			_blocks.append(block)
			block.became_stable.connect(_on_block_stable)
			block.countdown_started.connect(_on_block_countdown.bind(block))
			block.dropped.connect(_on_block_dropped.bind(block))


func set_player_target(player: Node2D) -> void:
	for block: L3FloatBlock in _blocks:
		block.set_player_target(player)


func start_cycle() -> bool:
	if _running:
		reset_idle()
	_running = true
	_stable_count = 0
	for index: int in range(_blocks.size()):
		_blocks[index].reset_for_cycle(stagger * float(index))
	return true


func reset_idle() -> void:
	_running = false
	_stable_count = 0
	for block: L3FloatBlock in _blocks:
		block.reset_to_rest()


func finish_crossing() -> void:
	_running = false


func is_running() -> bool:
	return _running


func is_all_stable() -> bool:
	return _stable_count >= _blocks.size()


func _on_block_stable() -> void:
	_stable_count += 1
	if _stable_count >= _blocks.size():
		all_stable.emit()


func _on_block_countdown(block: L3FloatBlock) -> void:
	block_warning.emit(_blocks.find(block))


func _on_block_dropped(block: L3FloatBlock) -> void:
	block_dropped.emit(_blocks.find(block))


func get_block_states() -> Array[String]:
	var out: Array[String] = []
	for block: L3FloatBlock in _blocks:
		out.append(block.get_phase_label())
	return out


func get_blocks() -> Array[L3FloatBlock]:
	return _blocks.duplicate()


func get_block_count() -> int:
	return _blocks.size()


func get_triggered_count() -> int:
	var count: int = 0
	for block: L3FloatBlock in _blocks:
		if block.is_standing_triggered():
			count += 1
	return count
