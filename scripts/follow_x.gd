extends Node2D
## Copies the x position of another node every frame (e.g. a reflection of the train in the wet road).

@export var target: Node2D


func _process(_delta: float) -> void:
	if target:
		position.x = target.position.x
		visible = target.visible
