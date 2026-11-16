extends Node3D
## Fissure: the head of the move races along the floor, leaving stone spikes
## behind it, and hits each target it passes once (damage, knock-up, slow).
## Stops at walls and pillars.

var caster: Node3D
var direction := Vector3.FORWARD
var speed := 16.0
var travel_left := 15.0
var radius := 1.0
var hit_info: Dictionary = {}
var color := Color(0.55, 0.45, 0.32)
var _since_spike := 0.0
var _hit: Array[Node] = []
var _dust: CPUParticles3D


func setup(from: Node3D, origin: Vector3, dir: Vector3, stats: Dictionary) -> void:
	add_to_group("spawned")
	caster = from
	global_position = Vector3(origin.x, 0.0, origin.z)
	direction = dir
	speed = float(stats.get("speed", speed))
	travel_left = float(stats.get("range", travel_left))
	radius = float(stats.get("radius", radius))
	color = Color(str(stats.get("color", "#8a7050")))
	hit_info = {
		"damage": float(stats.get("damage", 12.0)),
		"launch": float(stats.get("launch", 5.0)),
		"slow": float(stats.get("slow", 0.0)),
		"slow_time": float(stats.get("slow_time", 0.0)),
		"knockback": float(stats.get("knockback", 2.0)),
	}
	_dust = Effects.emitter(Color(0.72, 0.62, 0.48, 0.6), Color(0.7, 0.62, 0.5, 0.0), {
		"amount": 40, "lifetime": 0.7, "size": 0.5, "speed": Vector2(0.5, 2.0), "direction": Vector3.UP,
		"spread": 60.0, "emit_radius": 0.4, "end_scale": 1.5})
	_dust.emitting = true
	add_child(_dust)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * (step + 0.3), 1)
	var blocked := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	global_position += direction * step
	travel_left -= step
	_since_spike += step
	if _since_spike > 0.65:
		_since_spike = 0.0
		var side := Vector3(-direction.z, 0, direction.x) * randf_range(-0.3, 0.3)
		Effects.spike(get_parent(), global_position + side, randf_range(1.0, 1.6), 0.35, color, 0.6)
	for target: Node3D in Effects.hittables(caster):
		if target in _hit:
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() > radius or target.global_position.y > 2.0:
			continue
		_hit.append(target)
		var hit := hit_info.duplicate()
		hit["direction"] = direction
		hit["attacker"] = caster
		target.take_hit(hit)
		Effects.debris(get_parent(), target.global_position, color, 0.8)
	if blocked or travel_left <= 0.0:
		Effects.debris(get_parent(), global_position + Vector3.UP * 0.3, color, 0.8)
		_dust.emitting = false
		set_physics_process(false)
		Effects.free_after(self, 0.8)
