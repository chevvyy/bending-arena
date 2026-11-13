class_name Effects
extends RefCounted
## Visual helpers built from primitives and CPU particles (no imported assets),
## plus the shared "who can be hit" queries used by area moves.


## Everyone except `user` that can take a hit right now: benders and targets.
static func hittables(user: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var tree := user.get_tree()
	for group in ["benders", "targets"]:
		for node in tree.get_nodes_in_group(group):
			if node == user or not node is Node3D or not node.has_method("take_hit"):
				continue
			if node.has_method("is_alive") and not node.is_alive():
				continue
			found.append(node)
	return found


## Hits everyone within `radius` (flat distance) of `center`, pushing them
## away from it. Returns how many were hit.
static func area_hit(user: Node3D, center: Vector3, radius: float, hit: Dictionary) -> int:
	var count := 0
	for target: Node3D in hittables(user):
		var offset := target.global_position - center
		offset.y = 0.0
		if offset.length() > radius or absf(target.global_position.y - center.y) > 3.0:
			continue
		var h := hit.duplicate()
		h["direction"] = offset.normalized() if offset.length() > 0.05 else -user.global_basis.z
		h["attacker"] = user
		target.take_hit(h)
		count += 1
	return count


# --- Materials -----------------------------------------------------------

## A material for a colour: glow adds emission, alpha below 1 makes it see-through.
static func mat(color: Color, glow := 0.0, unshaded := false, two_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = glow
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _particle_material(solid: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if solid:
		m.roughness = 0.95
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func mesh_instance(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material != null:
		instance.material_override = material
	return instance


static func sphere(radius: float, segments := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(segments / 2, 3)
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## A cone pointing up +Y (a spike or shard).
static func cone(radius: float, height: float, segments := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


# --- Particles -------------------------------------------------------------

## A particle emitter that fades from `from` to `to`. opts: amount, lifetime,
## one_shot, explosiveness, size, solid (lit boxes, for rocks), direction,
## spread, speed (Vector2 min/max), gravity, emit_radius, local, damping,
## scale (Vector2), end_scale.
static func emitter(from: Color, to: Color, opts: Dictionary = {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(opts.get("amount", 24))
	p.lifetime = float(opts.get("lifetime", 0.5))
	p.one_shot = bool(opts.get("one_shot", false))
	p.explosiveness = float(opts.get("explosiveness", 0.0))
	p.randomness = 0.4
	p.local_coords = bool(opts.get("local", false))
	var solid := bool(opts.get("solid", false))
	var size := float(opts.get("size", 0.12))
	var mesh: PrimitiveMesh = box(Vector3.ONE * size) if solid else sphere(size * 0.5, 8)
	mesh.material = _particle_material(solid)
	p.mesh = mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(float(opts.get("emit_radius", 0.1)), 0.01)
	p.direction = opts.get("direction", Vector3.UP)
	p.spread = float(opts.get("spread", 45.0))
	var speed: Vector2 = opts.get("speed", Vector2(1.0, 3.0))
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = opts.get("gravity", Vector3.ZERO)
	p.damping_min = float(opts.get("damping", 0.0))
	p.damping_max = float(opts.get("damping", 0.0))
	var scale: Vector2 = opts.get("scale", Vector2(0.6, 1.2))
	p.scale_amount_min = scale.x
	p.scale_amount_max = scale.y
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, float(opts.get("end_scale", 0.15))))
	p.scale_amount_curve = curve
	if solid:
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	p.color_ramp = gradient
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## One puff of particles at a point that cleans itself up.
static func burst(parent: Node, at: Vector3, from: Color, to: Color, opts: Dictionary = {}) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var o := opts.duplicate()
	o["one_shot"] = true
	o["explosiveness"] = float(o.get("explosiveness", 0.9))
	var p := emitter(from, to, o)
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	free_after(p, p.lifetime + 0.3)


## Keeps an emitter (or any node) on `parent` for `seconds`, then stops and frees it.
static func attach(parent: Node, node: Node3D, seconds: float, offset := Vector3.ZERO) -> void:
	parent.add_child(node)
	node.position = offset
	node.add_to_group("spawned")
	if node is CPUParticles3D:
		var particles := node as CPUParticles3D
		particles.emitting = true
		# Stop emitting on time, then free once the last particles fade.
		parent.get_tree().create_timer(seconds, false).timeout.connect(particles.set.bind("emitting", false))
		free_after(node, seconds + particles.lifetime + 0.1)
	else:
		free_after(node, seconds)


static func free_after(node: Node, seconds: float) -> void:
	if node.is_inside_tree():
		node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


## A light that flashes and fades out.
static func flash(parent: Node, at: Vector3, color: Color, energy := 3.0, reach := 6.0,
		seconds := 0.3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


# --- Element effects ---------------------------------------------------------

static func fire_burst(parent: Node, at: Vector3, size := 1.0) -> void:
	burst(parent, at, Color(1.0, 0.95, 0.6), Color(0.8, 0.1, 0.0, 0.0), {
		"amount": int(26 * size), "lifetime": 0.45, "size": 0.35 * size, "speed": Vector2(1.5, 5.0) * size,
		"spread": 180.0, "gravity": Vector3(0, 3, 0), "damping": 4.0, "emit_radius": 0.2 * size})
	burst(parent, at, Color(0.3, 0.25, 0.22, 0.6), Color(0.2, 0.2, 0.2, 0.0), {
		"amount": int(10 * size), "lifetime": 0.9, "size": 0.4 * size, "speed": Vector2(0.5, 1.5),
		"spread": 180.0, "gravity": Vector3(0, 1.5, 0), "explosiveness": 0.6, "emit_radius": 0.3 * size})
	flash(parent, at, Color(1.0, 0.55, 0.2), 4.0 * size, 5.0 * size, 0.3)


static func splash(parent: Node, at: Vector3, color: Color, size := 1.0) -> void:
	burst(parent, at, Color(color.lightened(0.4), 0.95), Color(color, 0.0), {
		"amount": int(24 * size), "lifetime": 0.6, "size": 0.16 * size, "speed": Vector2(2.0, 5.0) * size,
		"spread": 70.0, "direction": Vector3.UP, "gravity": Vector3(0, -12, 0), "emit_radius": 0.2 * size})


static func shatter(parent: Node, at: Vector3, color: Color, size := 1.0) -> void:
	burst(parent, at, Color(color, 0.95), Color(1, 1, 1, 0.0), {
		"amount": int(16 * size), "lifetime": 0.6, "size": 0.14 * size, "speed": Vector2(2.0, 6.0),
		"spread": 180.0, "gravity": Vector3(0, -9, 0), "solid": true})
	burst(parent, at, Color(0.9, 1.0, 1.0, 0.8), Color(0.8, 0.95, 1.0, 0.0), {
		"amount": 10, "lifetime": 0.5, "size": 0.25 * size, "speed": Vector2(0.5, 2.0), "spread": 180.0})


static func debris(parent: Node, at: Vector3, color: Color, size := 1.0) -> void:
	burst(parent, at, color, color.darkened(0.4), {
		"amount": int(14 * size), "lifetime": 0.9, "size": 0.2 * size, "speed": Vector2(2.0, 6.0) * size,
		"spread": 75.0, "direction": Vector3.UP, "gravity": Vector3(0, -14, 0), "solid": true})
	dust(parent, at, size)


static func dust(parent: Node, at: Vector3, size := 1.0) -> void:
	burst(parent, at, Color(0.72, 0.62, 0.48, 0.55), Color(0.7, 0.62, 0.5, 0.0), {
		"amount": int(16 * size), "lifetime": 0.9, "size": 0.6 * size, "speed": Vector2(1.0, 3.0) * size,
		"spread": 90.0, "direction": Vector3.UP, "gravity": Vector3(0, 0.5, 0), "damping": 2.5,
		"emit_radius": 0.4 * size, "end_scale": 1.6, "explosiveness": 0.8})


static func gust(parent: Node, at: Vector3, size := 1.0) -> void:
	burst(parent, at, Color(1, 1, 1, 0.7), Color(0.85, 0.92, 1.0, 0.0), {
		"amount": int(18 * size), "lifetime": 0.45, "size": 0.3 * size, "speed": Vector2(3.0, 7.0) * size,
		"spread": 180.0, "damping": 8.0, "emit_radius": 0.3 * size, "end_scale": 1.4})
	ring(parent, at, 1.4 * size, Color(1, 1, 1), 0.3)


## Impact for a move's look ("fire_bolt", "rock", ...).
static func impact(parent: Node, at: Vector3, look: String, color: Color, size := 1.0) -> void:
	if look.begins_with("fire"):
		fire_burst(parent, at, size)
	elif look.begins_with("water") or look == "wave":
		splash(parent, at, color, size)
	elif look.begins_with("ice"):
		shatter(parent, at, color, size)
	elif look.begins_with("rock") or look == "boulder":
		debris(parent, at, color, size)
	else:
		gust(parent, at, size)


# --- Shapes --------------------------------------------------------------------

## A flat crescent in the XZ plane, bulging toward -Z, for kicks and slices.
static func arc_mesh(radius: float, half_angle_degrees: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var half := deg_to_rad(half_angle_degrees)
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	for i in steps + 1:
		var t := float(i) / steps
		var angle := lerpf(-half, half, t)
		var w := width * sin(PI * t) + 0.02
		var dir := Vector3(sin(angle), 0.0, -cos(angle))
		var p_in := dir * (radius - w * 0.5) + Vector3(0, 0, radius * 0.7)
		var p_out := dir * (radius + w * 0.5) + Vector3(0, 0, radius * 0.7)
		if i > 0:
			for v in [prev_in, prev_out, p_out, prev_in, p_out, p_in]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		prev_in = p_in
		prev_out = p_out
	return st.commit()


## A curved wall of water: `width` across, `height` tall, curling toward -Z at the top.
static func wave_mesh(width: float, height: float, curl: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 12
	var rows := 8
	var points := []
	for r in rows + 1:
		var row := []
		var v := float(r) / rows
		for c in cols + 1:
			var u := float(c) / cols
			var x := lerpf(-width * 0.5, width * 0.5, u)
			var edge := sin(PI * u)
			var h := height * (0.35 + 0.65 * edge)
			var y := v * h
			var z := -curl * v * v * edge + absf(x) * 0.25
			row.append(Vector3(x, y, z))
		points.append(row)
	for r in rows:
		for c in cols:
			var a: Vector3 = points[r][c]
			var b: Vector3 = points[r][c + 1]
			var cc: Vector3 = points[r + 1][c + 1]
			var d: Vector3 = points[r + 1][c]
			for v in [a, b, cc, a, cc, d]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(v)
	return st.commit()


## A jagged lightning bolt from a to b, with a couple of side forks.
static func bolt(parent: Node, a: Vector3, b: Vector3, color: Color, seconds := 0.25) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.add_to_group("spawned")
	var core := mat(Color(1, 1, 1), 4.0, true)
	var glow := mat(Color(color, 0.45), 3.0, true)
	var points := _jagged(a, b, 10, 0.45)
	for i in points.size() - 1:
		_segment(root, points[i], points[i + 1], 0.035, core)
		_segment(root, points[i], points[i + 1], 0.11, glow)
		if i in [3, 6]:
			var fork_end: Vector3 = points[i] + (b - a).normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9)) * 2.0 \
					+ Vector3(0, randf_range(-1.0, 1.0), 0)
			var fork := _jagged(points[i], fork_end, 4, 0.3)
			for j in fork.size() - 1:
				_segment(root, fork[j], fork[j + 1], 0.06, glow)
	var tween := root.create_tween()
	tween.tween_property(glow, "albedo_color:a", 0.0, seconds)
	tween.parallel().tween_property(core, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(root.queue_free)
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


static func _jagged(a: Vector3, b: Vector3, steps: int, jitter: float) -> Array:
	var points := [a]
	for i in range(1, steps):
		var t := float(i) / steps
		points.append(a.lerp(b, t) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter)
	points.append(b)
	return points


static func _segment(parent: Node3D, p: Vector3, q: Vector3, radius: float, material: Material) -> void:
	var length := p.distance_to(q)
	if length < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 5
	mesh.rings = 1
	var instance := mesh_instance(mesh, material)
	parent.add_child(instance)
	var y := (q - p) / length
	var helper := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	instance.global_transform = Transform3D(Basis(x, y, z), (p + q) * 0.5)


## A stone or ice spike that shoots out of the floor, waits and sinks back.
static func spike(parent: Node, at: Vector3, height: float, radius: float, color: Color,
		seconds := 0.7) -> void:
	var instance := mesh_instance(cone(radius, height, 5), mat(color, 0.0 if color.a >= 1.0 else 0.6))
	parent.add_child(instance)
	instance.add_to_group("spawned")
	instance.global_position = at + Vector3(0, -height * 0.5, 0)
	instance.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	var tween := instance.create_tween()
	tween.tween_property(instance, "global_position:y", at.y + height * 0.4, 0.08)
	tween.tween_interval(seconds)
	tween.tween_property(instance, "global_position:y", at.y - height * 0.6, 0.3)
	tween.tween_callback(instance.queue_free)


# --- Rings and numbers ---------------------------------------------------------

## A flat ring that grows to `radius` and fades out. Shows the size of area moves.
static func ring(parent: Node, at: Vector3, radius: float, color: Color, seconds: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	var material := mat(Color(color, 0.85), 1.0, true)
	mesh.material = material
	var instance := mesh_instance(mesh)
	parent.add_child(instance)
	instance.global_position = at
	instance.scale = Vector3.ONE * 0.2
	var tween := instance.create_tween().set_parallel()
	tween.tween_property(instance, "scale", Vector3(radius, 1.0, radius), seconds)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(instance.queue_free)


## Floating number that rises and fades, for damage (red) or healing (green).
static func number(parent: Node, at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.004
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", at.y + 1.2, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
