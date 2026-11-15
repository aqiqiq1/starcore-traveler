extends RefCounted

## Small shared helper for the two formal levels' scene transitions.
##
## The production scenes are real files on disk: leaving a level always goes
## through SceneTree.change_scene_to_file().  Tests may keep a harness alive by
## clearing current_scene first, but the game never fakes the transition.

const LEVEL_01_PATH: String = "res://scenes/level_01.tscn"
const LEVEL_02_PATH: String = "res://scenes/level_02.tscn"

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
## switch to the real PackedScene path.
static func change_scene(tree: SceneTree, path: String) -> void:
	if tree == null:
		return
	tree.paused = false
	release_gameplay_actions()
	tree.change_scene_to_file(path)


static func return_to_title(tree: SceneTree) -> void:
	change_scene(tree, LEVEL_01_PATH)


static func start_level_02(tree: SceneTree) -> void:
	change_scene(tree, LEVEL_02_PATH)
