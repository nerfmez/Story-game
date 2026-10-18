extends Node2D
## Copies the x position of another node every frame (e.g. a reflection of the train in the wet road).

@export var target: Node2D
## Also show/hide together with the target (the train's reflection). Off for things that only
## follow the camera (dust, rain splashes), whose visibility the time of day sets.
@export var copy_visible := true


func _process(_delta: float) -> void:
	if target:
		position.x = target.position.x
		if copy_visible:
			visible = target.visible
