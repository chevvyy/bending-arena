class_name Projectile
extends Area3D
## One bending shot. An ability calls setup() right after adding it to the
## scene. It flies (optionally arcing), hits the first body it touches and
## frees itself. Pierce shots pass through targets but still stop at walls.

var shooter: Node3D
var velocity := Vector3.ZERO
var gravity_strength := 0.0
var lifetime := 1.0
var pierce := false
var hit_info: Dictionary = {}
var _already_hit: Array[Node] = []


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)


func setup(from: Node3D, origin: Vector3, direction: Vector3, stats: Dictionary) -> void:
	shooter = from
	global_position = origin
	var speed: float = float(stats.get("speed", 20.0))
	var launch_up: float = float(stats.get("launch_up", 0.0))
	velocity = direction * speed + Vector3.UP * launch_up
	gravity_strength = float(stats.get("gravity", 0.0))
	lifetime = float(stats.get("range", 20.0)) / maxf(speed, 0.1)
	pierce = bool(stats.get("pierce", false))
	hit_info = {
		"damage": float(stats.get("damage", 5.0)),
		"knockback": float(stats.get("knockback", 0.0)),
		"slow": float(stats.get("slow", 0.0)),
		"slow_time": float(stats.get("slow_time", 0.0)),
	}
	_build_look(float(stats.get("radius", 0.25)), Color(str(stats.get("color", "#ffffff"))))


func _physics_process(delta: float) -> void:
	velocity.y -= gravity_strength * delta
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == shooter or body in _already_hit:
		return
	if body.has_method("take_hit"):
		_already_hit.append(body)
		var hit := hit_info.duplicate()
		hit["direction"] = Vector3(velocity.x, 0.0, velocity.z).normalized()
		hit["attacker"] = shooter
		body.take_hit(hit)
		if pierce:
			return
	queue_free()


## Each shot gets its own shape and mesh so changing one never changes the rest.
## The mesh is drawn 30% bigger than the hitbox so shots read clearly.
func _build_look(radius: float, color: Color) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	$CollisionShape3D.shape = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	var sphere := SphereMesh.new()
	sphere.radius = radius * 1.3
	sphere.height = radius * 2.6
	sphere.material = material
	$MeshInstance3D.mesh = sphere
