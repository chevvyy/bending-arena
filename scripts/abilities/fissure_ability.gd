class_name FissureAbility
extends Ability
## Fissure: a line of stone spikes races along the floor where you aim,
## knocking up and slowing everyone it passes.

const FissureScript := preload("res://scripts/fissure.gd")


func _activate() -> void:
	var direction: Vector3 = user.flat_aim()
	user.face_aim(direction)
	user.animate(str(stats.get("anim", "stomp")))
	var fissure: Node3D = FissureScript.new()
	user.get_parent().add_child(fissure)
	fissure.setup(user, user.global_position + direction * 0.8, direction, stats)
	Effects.dust(user.get_parent(), user.global_position, 0.8)


func reach() -> float:
	return float(stats.get("range", 15.0))
