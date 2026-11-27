extends RefCounted

## Small shared helper for the two formal levels' scene transitions.
##
## The production scenes are real files on disk: leaving a level always goes
## through SceneTree.change_scene_to_file().  Tests may keep a harness alive by
## clearing current_scene first, but the game never fakes the transition.

const LEVEL_01_PATH: String = "res://scenes/level_01.tscn"
const LEVEL_02_PATH: String = "res://scenes/level_02.tscn"
const LEVEL_03_PATH: String = "res://scenes/level_03.tscn"

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"polarity",
	&"reset",
	&"pause",
	&"interact",
	&"tutorial_next",
]


const ONE_SHOT_ACTIONS: Array[StringName] = [
	&"jump",
	&"polarity",
	&"reset",
	&"pause",
	&"interact",
	&"tutorial_next",
]

## Set by the title's black fade before the real scene switch, consumed by the
## fresh level_01 so its opening starts without the title menu. This is the only
## state carried across a new-game change_scene.
static var _new_game_requested: bool = false


## Starts a fresh level_01 after the title has reached full black. The flag is
## consumed by the new scene's _ready before it decides whether to show the menu.
static func start_new_game(tree: SceneTree) -> Error:
	if tree == null:
		return ERR_UNCONFIGURED
	_new_game_requested = true
	tree.paused = false
	release_gameplay_actions()
	var error: Error = tree.change_scene_to_file(LEVEL_01_PATH)
	if error != OK:
		_new_game_requested = false
	return error


static func consume_new_game_request() -> bool:
	var requested: bool = _new_game_requested
	_new_game_requested = false
	return requested


static func clear_new_game_request() -> void:
	_new_game_requested = false


## Drop any physical/action state that could leak into the newly loaded scene.
## A held Enter/Space/R/E must not jump, toggle polarity, interact or restart on
## the first frame of the next level.
static func release_gameplay_actions() -> void:
	for action: StringName in GAMEPLAY_ACTIONS:
		Input.action_release(action)
	Input.flush_buffered_events()


## A menu button activated with Space/Enter must not become a jump/polarity/E/R
## press when the pause menu closes on the same frame. Movement actions are left
## alone so a player holding a direction after a short pause keeps moving.
static func release_one_shot_actions() -> void:
	for action: StringName in ONE_SHOT_ACTIONS:
		Input.action_release(action)


## Production scene change: unpause the tree first (pause is tree-global), then
## switch to the real PackedScene path.  Returns the engine error so title
## callers can restore their menu instead of freezing on a black frame.
static func change_scene(tree: SceneTree, path: String) -> Error:
	if tree == null:
		return ERR_UNCONFIGURED
	tree.paused = false
	release_gameplay_actions()
	return tree.change_scene_to_file(path)


static func return_to_title(tree: SceneTree) -> void:
	change_scene(tree, LEVEL_01_PATH)


static func start_level_02(tree: SceneTree) -> void:
	change_scene(tree, LEVEL_02_PATH)


static func start_level_03(tree: SceneTree) -> void:
	change_scene(tree, LEVEL_03_PATH)
