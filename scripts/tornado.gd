extends Node3D
## The Tornado ultimate: drifts forward, pulls nearby enemies toward its centre
## and damages them every tick. Built from stacked transparent cylinders.

var caster: Node3D
var direction := Vector3.FORWARD
var speed := 6.0
var radius := 3.0
var pull := 5.0
var damage := 3.0
var tick := 0.25
var lifetime := 3.5
var _tick_left := 0.0
var _spin: Node3D


func setup(from: Node3D, origin: Vector3, dir: Vector3, stats: Dictionary) -> void:
	add_to_group("spawned")
	caster = from
	global_position = Vector3(origin.x, 0.0, origin.z)
	direction = dir
	speed = float(stats.get("speed", speed))
	radius = float(stats.get("radius", radius))
	pull = float(stats.get("pull", pull))
	damage = float(stats.get("damage", damage))
	tick = maxf(float(stats.get("tick", tick)), 0.05)
	lifetime = float(stats.get("duration", lifetime))
	_build_look(Color(str(stats.get("color", "#dfe8ee"))))


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_spin.rotate_y(10.0 * delta)
	_tick_left -= delta
	var do_damage := _tick_left <= 0.0
	if do_damage:
		_tick_left = tick
	for target: Node3D in Effects.hittables(caster):
		var offset := global_position - target.global_position
		offset.y = 0.0
		if offset.length() > radius:
			continue
		if target is CharacterBody3D and offset.length() > 0.3:
			(target as CharacterBody3D).move_and_collide(offset.normalized() * pull * delta)
		if do_damage:
			target.take_hit({"damage": damage, "direction": -offset.normalized(), "attacker": caster})
	lifetime -= delta
	if lifetime <= 0.0 or absf(global_position.x) > 20.0 or absf(global_position.z) > 20.0:
		queue_free()


func _build_look(color: Color) -> void:
	_spin = Node3D.new()
	add_child(_spin)
	for i in 4:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius * (0.45 + 0.17 * i)
		mesh.bottom_radius = radius * (0.25 + 0.17 * i)
		mesh.height = 1.1
		mesh.radial_segments = 10
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color, 0.35)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = material
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.position = Vector3(0.15 * (i % 2), 0.55 + 1.0 * i, 0.0)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin.add_child(part)
