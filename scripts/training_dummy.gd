extends StaticBody3D
## Target for training mode, in group "targets". Takes hits, squashes so you can
## see them land, shows damage numbers, and stands back up after it breaks.

signal broken

var display_name := "Training Dummy"

@onready var health: Health = $Health
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health.died.connect(_on_died)


func is_alive() -> bool:
	return not health.is_dead()


## hit is a Dictionary: damage, direction, attacker, plus extras like
## knockback or slow that only moving targets use.
func take_hit(hit: Dictionary) -> void:
	if not is_alive():
		return
	var damage := float(hit.get("damage", 0.0))
	health.take_damage(damage)
	mesh.scale = Vector3(1.2, 0.85, 1.2)
	create_tween().tween_property(mesh, "scale", Vector3.ONE, 0.15)
	if damage > 0.0:
		Effects.number(get_parent(), global_position + Vector3.UP * 2.1,
			str(roundi(damage)), Color(1.0, 0.85, 0.3))


func reset_for_round() -> void:
	health.reset()
	mesh.rotation = Vector3.ZERO


func _on_died() -> void:
	create_tween().tween_property(mesh, "rotation:x", -PI * 0.5, 0.3)
	broken.emit()
