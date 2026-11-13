class_name StickFigure
extends Node3D
## The bender's body: a stick figure built from thin cylinders, with a head,
## glowing hands and an element-coloured headband and sash. Animation is
## procedural: every frame it works out a pose for each joint (idle stance,
## running, in the air, knocked out) and blends a short action pose on top
## (punch, kick, push, stomp...) when a move is used. It faces -Z.

const LIMB_RADIUS := 0.05
const UPPER_ARM := 0.32
const FOREARM := 0.3
const THIGH := 0.47
const SHIN := 0.45
const SPINE := 0.55
const HIP_HEIGHT := 0.95

## Action poses: joint -> rotation (x, y, z). "p" in an arm's x is replaced by
## the aim pitch, so punches and pushes follow where you aim.
const ACTIONS := {
	"punch_r": {"sh_r": Vector3(1.0, 0, 0), "el_r": Vector3(0.05, 0, 0), "sh_l": Vector3(0.5, 0, -0.2),
		"el_l": Vector3(1.7, 0, 0), "spine": Vector3(-0.1, 0.4, 0), "aim": ["sh_r"]},
	"punch_l": {"sh_l": Vector3(1.0, 0, 0), "el_l": Vector3(0.05, 0, 0), "sh_r": Vector3(0.5, 0, 0.2),
		"el_r": Vector3(1.7, 0, 0), "spine": Vector3(-0.1, -0.4, 0), "aim": ["sh_l"]},
	"kick": {"hip_r": Vector3(1.55, 0, 0), "kn_r": Vector3(-0.05, 0, 0), "hip_l": Vector3(-0.15, 0, 0),
		"kn_l": Vector3(-0.35, 0, 0), "spine": Vector3(0.3, 0.2, 0), "sh_r": Vector3(0.2, 0, 1.0),
		"sh_l": Vector3(0.4, 0, -1.0), "el_r": Vector3(0.3, 0, 0), "el_l": Vector3(0.3, 0, 0)},
	"push": {"sh_r": Vector3(1.0, 0, -0.15), "sh_l": Vector3(1.0, 0, 0.15), "el_r": Vector3(0.1, 0, 0),
		"el_l": Vector3(0.1, 0, 0), "spine": Vector3(-0.2, 0, 0), "hip_r": Vector3(0.6, 0, 0),
		"kn_r": Vector3(-0.5, 0, 0), "hip_l": Vector3(-0.45, 0, 0), "kn_l": Vector3(-0.1, 0, 0),
		"aim": ["sh_r", "sh_l"]},
	"sweep": {"sh_r": Vector3(PI * 0.5, 0, 1.3), "el_r": Vector3(0.05, 0, 0), "sh_l": Vector3(0.6, 0, -0.6),
		"el_l": Vector3(1.2, 0, 0), "spine": Vector3(-0.1, -0.7, 0), "hip_r": Vector3(0.3, 0, 0.2),
		"kn_r": Vector3(-0.4, 0, 0)},
	"raise": {"sh_r": Vector3(2.9, 0, 0.25), "sh_l": Vector3(2.9, 0, -0.25), "el_r": Vector3(0.2, 0, 0),
		"el_l": Vector3(0.2, 0, 0), "spine": Vector3(0.15, 0, 0), "hip_r": Vector3(0.15, 0, 0.25),
		"hip_l": Vector3(0.15, 0, -0.25), "kn_r": Vector3(-0.3, 0, 0), "kn_l": Vector3(-0.3, 0, 0)},
	"stomp": {"hip_r": Vector3(1.1, 0, 0.1), "kn_r": Vector3(-1.4, 0, 0), "sh_r": Vector3(0.3, 0, 0.7),
		"sh_l": Vector3(0.3, 0, -0.7), "el_r": Vector3(0.6, 0, 0), "el_l": Vector3(0.6, 0, 0),
		"spine": Vector3(-0.25, 0, 0), "kn_l": Vector3(-0.4, 0, 0), "hip_l": Vector3(0.2, 0, 0)},
	"guard": {"sh_r": Vector3(1.35, 0, -0.55), "sh_l": Vector3(1.35, 0, 0.55), "el_r": Vector3(1.6, 0, 0),
		"el_l": Vector3(1.6, 0, 0), "hip_r": Vector3(0.45, 0, 0.2), "hip_l": Vector3(0.45, 0, -0.2),
		"kn_r": Vector3(-0.8, 0, 0), "kn_l": Vector3(-0.8, 0, 0), "drop": 0.15},
	"heal": {"sh_r": Vector3(0.75, 0, -0.3), "sh_l": Vector3(0.75, 0, 0.3), "el_r": Vector3(1.3, 0, 0),
		"el_l": Vector3(1.3, 0, 0), "spine": Vector3(-0.1, 0, 0)},
	"spin": {"sh_r": Vector3(0.1, 0, 1.45), "sh_l": Vector3(0.1, 0, -1.45), "el_r": Vector3(0.1, 0, 0),
		"el_l": Vector3(0.1, 0, 0), "hip_r": Vector3(0.2, 0, 0.2), "hip_l": Vector3(0.2, 0, -0.2)},
	"dash": {"spine": Vector3(-0.55, 0, 0), "sh_r": Vector3(-0.9, 0, 0.3), "sh_l": Vector3(-0.9, 0, -0.3),
		"el_r": Vector3(0.3, 0, 0), "el_l": Vector3(0.3, 0, 0), "hip_r": Vector3(1.0, 0, 0),
		"kn_r": Vector3(-1.1, 0, 0), "hip_l": Vector3(-0.6, 0, 0), "kn_l": Vector3(-0.4, 0, 0)},
	"ride": {"hip_r": Vector3(0.8, 0, 0.15), "hip_l": Vector3(0.8, 0, -0.15), "kn_r": Vector3(-1.3, 0, 0),
		"kn_l": Vector3(-1.3, 0, 0), "sh_r": Vector3(0.3, 0, 0.6), "sh_l": Vector3(0.3, 0, -0.6),
		"el_r": Vector3(0.4, 0, 0), "el_l": Vector3(0.4, 0, 0), "spine": Vector3(-0.2, 0, 0), "drop": 0.28},
	"channel": {"sh_r": Vector3(1.0, 0, 0), "el_r": Vector3(0.0, 0, 0), "sh_l": Vector3(1.0, 0, -0.7),
		"el_l": Vector3(0.4, 0, 0), "spine": Vector3(-0.1, 0.55, 0), "hip_r": Vector3(-0.3, 0, 0.25),
		"hip_l": Vector3(0.5, 0, -0.2), "kn_l": Vector3(-0.5, 0, 0), "aim": ["sh_r", "sh_l"]},
	"hit": {"spine": Vector3(0.4, 0, 0), "sh_r": Vector3(0.3, 0, 0.9), "sh_l": Vector3(0.3, 0, -0.9),
		"el_r": Vector3(0.5, 0, 0), "el_l": Vector3(0.5, 0, 0)},
}
const JOINTS := ["spine", "sh_r", "sh_l", "el_r", "el_l", "hip_r", "hip_l", "kn_r", "kn_l"]

var body: CharacterBody3D
var aim_pitch := 0.0

var _rig: Node3D
var _joints: Dictionary = {}
var _limb_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _hand_material: StandardMaterial3D
var _head_material: StandardMaterial3D
var _pose: Dictionary = {}
var _phase := 0.0
var _clock := 0.0
var _air := 0.0
var _action := ""
var _action_time := 0.0
var _action_length := 0.0
var _action_hold := false
var _punch_left := false


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	_build()
	for joint: String in JOINTS:
		_pose[joint] = Vector3.ZERO


## Element colour for the headband, sash and hands; `dark` for the limbs.
func set_colors(accent: Color, dark: Color) -> void:
	_accent_material.albedo_color = accent
	_hand_material.albedo_color = accent.lightened(0.3)
	_hand_material.emission = accent.lightened(0.2)
	_limb_material.albedo_color = dark


## Plays an action pose for `length` seconds. "punch" alternates hands.
## hold keeps the pose until the end (riding, channelling) instead of a quick strike.
func play(action: String, pitch := 0.0, length := -1.0, hold := false) -> void:
	if action == "punch":
		_punch_left = not _punch_left
		action = "punch_l" if _punch_left else "punch_r"
	if not ACTIONS.has(action):
		return
	_action = action
	aim_pitch = clampf(pitch, -1.2, 1.2)
	_action_length = length if length > 0.0 else (0.6 if action in ["spin", "raise", "stomp"] else 0.38)
	_action_time = 0.0
	_action_hold = hold


func flash(color: Color) -> void:
	_limb_material.emission = color
	_head_material.emission = color
	var tween := create_tween().set_parallel()
	tween.tween_property(_limb_material, "emission", Color.BLACK, 0.25)
	tween.tween_property(_head_material, "emission", Color.BLACK, 0.25)


func reset_pose() -> void:
	_action = ""
	_rig.rotation = Vector3.ZERO
	_rig.position = Vector3.ZERO


## World position of a hand, where bending visibly starts from.
func hand_position(left: bool) -> Vector3:
	var hand: Node3D = _joints["hand_l" if left else "hand_r"]
	return hand.global_position


## Rock plates on the torso and limbs, for Rock Armor.
func add_armor(color: Color, seconds: float) -> void:
	var material := Effects.mat(color)
	for part: String in ["spine", "sh_r", "sh_l", "hip_r", "hip_l"]:
		var holder: Node3D = _joints[part]
		var count := 3 if part == "spine" else 1
		for i in count:
			var plate := Effects.mesh_instance(Effects.box(Vector3(0.22, 0.16, 0.12) * randf_range(0.9, 1.3)), material)
			plate.position = Vector3(randf_range(-0.06, 0.06), 0.15 + i * 0.16 if part == "spine" else -0.15,
				-0.06 if i % 2 == 0 else 0.06)
			plate.rotation = Vector3(randf(), randf(), randf()) * 0.6
			holder.add_child(plate)
			plate.scale = Vector3.ZERO
			var tween := plate.create_tween()
			tween.tween_property(plate, "scale", Vector3.ONE, 0.15)
			tween.tween_interval(seconds)
			tween.tween_property(plate, "scale", Vector3.ZERO, 0.2)
			tween.tween_callback(plate.queue_free)


func _build() -> void:
	_limb_material = Effects.mat(Color(0.1, 0.1, 0.12))
	_limb_material.emission_enabled = true
	_limb_material.emission = Color.BLACK
	_head_material = Effects.mat(Color(0.93, 0.9, 0.84))
	_head_material.emission_enabled = true
	_head_material.emission = Color.BLACK
	_accent_material = Effects.mat(Color(0.8, 0.3, 0.2))
	_hand_material = Effects.mat(Color(1, 0.6, 0.3), 1.5)

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var hips := _joint("hips", _rig, Vector3(0, HIP_HEIGHT, 0))
	var spine := _joint("spine", hips, Vector3.ZERO)
	_limb(spine, SPINE, LIMB_RADIUS * 1.25, true)
	# Shoulder and hip bars make it read as a figure from any angle.
	var shoulders := Effects.mesh_instance(_capsule(0.34, LIMB_RADIUS), _limb_material)
	shoulders.rotation.z = PI * 0.5
	shoulders.position.y = SPINE - 0.04
	spine.add_child(shoulders)
	var hip_bar := Effects.mesh_instance(_capsule(0.24, LIMB_RADIUS), _limb_material)
	hip_bar.rotation.z = PI * 0.5
	hips.add_child(hip_bar)

	var sash := Effects.mesh_instance(_ring(0.11, 0.07), _accent_material)
	sash.position.y = 0.06
	spine.add_child(sash)
	var head := Effects.mesh_instance(Effects.sphere(0.16, 16), _head_material)
	head.position.y = SPINE + 0.2
	spine.add_child(head)
	var neck := Effects.mesh_instance(_capsule(0.12, LIMB_RADIUS), _limb_material)
	neck.position.y = SPINE + 0.04
	spine.add_child(neck)
	var band := Effects.mesh_instance(_ring(0.165, 0.05), _accent_material)
	band.position.y = SPINE + 0.25
	spine.add_child(band)
	var nose := Effects.mesh_instance(Effects.box(Vector3(0.05, 0.05, 0.08)), _limb_material)
	nose.position = Vector3(0, SPINE + 0.2, -0.16)
	spine.add_child(nose)

	for side in [1.0, -1.0]:
		var s := "r" if side > 0.0 else "l"
		var shoulder := _joint("sh_" + s, spine, Vector3(0.17 * side, SPINE - 0.04, 0))
		_limb(shoulder, UPPER_ARM, LIMB_RADIUS, false)
		var elbow := _joint("el_" + s, shoulder, Vector3(0, -UPPER_ARM, 0))
		_limb(elbow, FOREARM, LIMB_RADIUS * 0.9, false)
		var hand := _joint("hand_" + s, elbow, Vector3(0, -FOREARM - 0.03, 0))
		hand.add_child(Effects.mesh_instance(Effects.sphere(0.065, 8), _hand_material))

		var hip := _joint("hip_" + s, hips, Vector3(0.11 * side, 0, 0))
		_limb(hip, THIGH, LIMB_RADIUS * 1.1, false)
		var knee := _joint("kn_" + s, hip, Vector3(0, -THIGH, 0))
		_limb(knee, SHIN, LIMB_RADIUS, false)
		var foot := Effects.mesh_instance(Effects.box(Vector3(0.09, 0.06, 0.2)), _limb_material)
		foot.position = Vector3(0, -SHIN - 0.01, -0.05)
		knee.add_child(foot)


func _joint(joint_name: String, parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = joint_name
	j.position = at
	parent.add_child(j)
	_joints[joint_name] = j
	return j


## A limb from the joint along -Y (or +Y for the spine).
func _limb(joint: Node3D, length: float, radius: float, up: bool) -> void:
	var limb := Effects.mesh_instance(_capsule(length + radius * 2.0, radius), _limb_material)
	limb.position.y = length * 0.5 * (1.0 if up else -1.0)
	limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	joint.add_child(limb)


func _capsule(height: float, radius: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.0)
	c.radial_segments = 8
	c.rings = 2
	return c


func _ring(radius: float, thickness: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = thickness
	c.radial_segments = 12
	c.rings = 1
	return c


func _process(delta: float) -> void:
	if body == null:
		return
	_clock += delta
	var target := _base_pose(delta)
	var drop := 0.0
	if _action != "":
		_action_time += delta
		var u := _action_time / _action_length
		if u >= 1.0:
			_action = ""
			_rig.rotation.y = 0.0
		else:
			var w := _action_weight(u)
			var pose: Dictionary = ACTIONS[_action]
			var aimed: Array = pose.get("aim", [])
			for joint: String in JOINTS:
				if pose.has(joint):
					var r: Vector3 = pose[joint]
					if joint in aimed:
						r.x = PI * 0.5 + aim_pitch
					target[joint] = (target[joint] as Vector3).lerp(r, w)
			drop = float(pose.get("drop", 0.0)) * w
			if _action == "spin":
				_rig.rotation.y = TAU * smoothstep(0.0, 1.0, u)
	# Quick blend toward the target pose so changes never snap.
	var blend := clampf(delta * 18.0, 0.0, 1.0)
	for joint: String in JOINTS:
		_pose[joint] = (_pose[joint] as Vector3).lerp(target[joint], blend)
		(_joints[joint] as Node3D).rotation = _pose[joint]
	_rig.position.y = lerpf(_rig.position.y, float(target.get("bob", 0.0)) - drop, blend)


func _action_weight(u: float) -> float:
	if _action_hold:
		return clampf(minf(u / 0.08, (1.0 - u) / 0.08), 0.0, 1.0)
	if u < 0.18:
		return u / 0.18
	if u < 0.55:
		return 1.0
	return 1.0 - (u - 0.55) / 0.45


## Stance, running and air poses from the body's velocity.
func _base_pose(delta: float) -> Dictionary:
	var pose := {}
	if body.has_method("is_alive") and not body.is_alive():
		for joint: String in JOINTS:
			pose[joint] = Vector3.ZERO
		pose["sh_r"] = Vector3(0.2, 0, 1.2)
		pose["sh_l"] = Vector3(0.2, 0, -1.2)
		pose["hip_r"] = Vector3(0, 0, 0.3)
		pose["hip_l"] = Vector3(0, 0, -0.3)
		pose["bob"] = 0.0
		return pose
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var base_speed := maxf(float(body.get("move_speed")), 0.1)
	var s := clampf(flat.length() / base_speed, 0.0, 1.6)
	var run := clampf(s, 0.0, 1.0)
	_phase += delta * (5.0 + 6.5 * minf(s, 1.4))
	var sw := sin(_phase)
	var leg := 0.8 * minf(s, 1.3)
	var breathe := sin(_clock * 2.2) * 0.03 * (1.0 - run)

	# Fighting stance: knees soft, fists up.
	pose["spine"] = Vector3(-0.14 * minf(s, 1.3) + breathe, 0, 0)
	var guard_sh := Vector3(0.55, 0, 0.18)
	var swing := 0.75 * minf(s, 1.3)
	pose["sh_r"] = guard_sh.lerp(Vector3(-sw * swing, 0, 0.12), run)
	pose["sh_l"] = Vector3(guard_sh.x, 0, -guard_sh.z).lerp(Vector3(sw * swing, 0, -0.12), run)
	pose["el_r"] = Vector3(lerpf(1.55, 1.2, run), 0, 0)
	pose["el_l"] = Vector3(lerpf(1.55, 1.2, run), 0, 0)
	pose["hip_r"] = Vector3(lerpf(0.12, sw * leg, run), 0, lerpf(0.1, 0.02, run))
	pose["hip_l"] = Vector3(lerpf(0.12, -sw * leg, run), 0, lerpf(-0.1, -0.02, run))
	pose["kn_r"] = Vector3(lerpf(-0.25, -0.15 - maxf(0.0, cos(_phase)) * 1.1 * run, run), 0, 0)
	pose["kn_l"] = Vector3(lerpf(-0.25, -0.15 - maxf(0.0, -cos(_phase)) * 1.1 * run, run), 0, 0)
	pose["bob"] = absf(sin(_phase)) * 0.06 * run - 0.03 * (1.0 - run)

	# In the air: tuck the legs and throw the arms out.
	var airborne := 0.0 if body.is_on_floor() else 1.0
	_air = lerpf(_air, airborne, clampf(delta * 10.0, 0.0, 1.0))
	if _air > 0.01:
		var air_pose := {
			"hip_r": Vector3(0.8, 0, 0.1), "hip_l": Vector3(0.2, 0, -0.1),
			"kn_r": Vector3(-1.2, 0, 0), "kn_l": Vector3(-0.7, 0, 0),
			"sh_r": Vector3(0.4, 0, 0.9), "sh_l": Vector3(0.4, 0, -0.9),
			"el_r": Vector3(0.5, 0, 0), "el_l": Vector3(0.5, 0, 0),
		}
		for joint: String in air_pose:
			pose[joint] = (pose[joint] as Vector3).lerp(air_pose[joint], _air)
		pose["bob"] = lerpf(float(pose["bob"]), 0.0, _air)
	return pose
