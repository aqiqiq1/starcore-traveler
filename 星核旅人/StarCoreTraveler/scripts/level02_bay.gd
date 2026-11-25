extends StarCoreBayInteractable

## Level-02 bay with the shared bay state machine, but release points clamped to
## the actual 1792 px level instead of the old 640 px sandbox. The shared
## component's defaults remain 16..624, so F4/F7 behaviour is unchanged.

@export var release_min_x: float = 16.0
@export var release_max_x: float = 1776.0


func get_release_point(player_x: float) -> Vector2:
	var side: float = 1.0 if player_x <= global_position.x else -1.0
	var point: Vector2 = global_position + Vector2(side * release_distance, 8.0)
	point.x = clampf(point.x, release_min_x, release_max_x)
	return point
