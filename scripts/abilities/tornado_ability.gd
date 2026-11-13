class_name TornadoAbility
extends Ability
## Tornado: sends a spinning column forward that drags enemies in and hurts
## them a little every "tick" seconds.

const TornadoScript := preload("res://scripts/tornado.gd")


func _activate() -> void:
	var direction: Vector3 = user.flat_aim()
	user.face_aim(direction)
	user.animate(str(stats.get("anim", "spin")))
	var tornado: Node3D = TornadoScript.new()
	user.get_parent().add_child(tornado)
	tornado.setup(user, user.global_position + direction * 1.5, direction, stats)


func reach() -> float:
	return float(stats.get("speed", 6.0)) * float(stats.get("duration", 3.5)) * 0.6
