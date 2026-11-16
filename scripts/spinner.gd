extends Node3D
## Spins a visual (the air scooter's ball) around its own axes.

@export var speed := Vector3(9.0, 4.0, 0.0)


func _process(delta: float) -> void:
	rotation += speed * delta
