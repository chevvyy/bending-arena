class_name PlayerBender
extends Bender
## The bender you control: camera-relative movement, sprint, jump, a mouse-orbit
## camera on a SpringArm3D (so it never clips into walls) and the ability keys.
## Aim follows the camera, with a light aim assist toward the opponent.

const SLOT_ACTIONS := {
	"basic": "attack_basic",
	"special": "attack_special",
	"utility": "ability_utility",
	"ultimate": "ability_ultimate",
}

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch_degrees := -70.0
@export var max_pitch_degrees := 35.0
@export var start_pitch_degrees := -14.0
## Shots bend toward the opponent when they are within this many degrees of the crosshair.
@export var aim_assist_degrees := 7.0

## The opponent or training dummy, for aim assist. Set by the round manager.
var target: Node3D
## Training mode lets 1-4 switch element on the fly.
var allow_element_switch := false
## Smoke test only: drive this bender with the AI brain.
var brain: AiBrain

var _move_input := Vector3.ZERO

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	super._ready()
	spring_arm.add_excluded_object(get_rid())
	spring_arm.rotation.x = deg_to_rad(start_pitch_degrees)
	capture_mouse()


func capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		camera_pivot.rotation.y -= motion.relative.x * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees))


func _unhandled_input(event: InputEvent) -> void:
	if not allow_element_switch:
		return
	for key: String in Game.ELEMENTS:
		if event.is_action_pressed("element_" + key):
			apply_element(key, Game.player_loadout(key, true))
			return


func _physics_process(delta: float) -> void:
	if brain != null:
		brain.update(delta)
		_move_input = brain.move
		move_with(brain.move, brain.sprint, brain.jump, delta)
		brain.take_actions()
		# Point the camera where the autopilot aims, so recordings look right.
		camera_pivot.global_rotation.y = lerp_angle(camera_pivot.global_rotation.y,
			atan2(-brain.aim.x, -brain.aim.z), 4.0 * delta)
		return

	# Movement is relative to where the camera looks, flattened onto the floor.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_yaw := Basis(Vector3.UP, camera_pivot.rotation.y)
	_move_input = (camera_yaw * Vector3(input.x, 0.0, input.y)).normalized()
	move_with(_move_input, Input.is_action_pressed("sprint"),
		Input.is_action_just_pressed("jump"), delta)

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return
	# Hold a button to keep using it; each ability's cooldown sets the rate.
	for slot: String in SLOT_ACTIONS:
		if Input.is_action_pressed(SLOT_ACTIONS[slot]):
			use_slot(slot)


func _process(_delta: float) -> void:
	# Hide your own body when a wall pushes the camera right up against it.
	model.visible = spring_arm.get_hit_length() > 1.4


func reset_for_round() -> void:
	super.reset_for_round()
	# Face the camera the same way as the spawn point.
	camera_pivot.rotation.y = 0.0
	spring_arm.rotation.x = deg_to_rad(start_pitch_degrees)


## Flat direction toward whatever is under the crosshair (the camera sits over
## your right shoulder, so this is not quite where the camera faces), nudged
## onto the target when it is close to the crosshair.
func aim_direction() -> Vector3:
	if brain != null:
		return brain.aim
	var forward := _crosshair_point() - global_position
	forward.y = 0.0
	if forward.length() < 1.0:
		forward = -camera_pivot.global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()
	if target != null and is_instance_valid(target) \
			and (not target.has_method("is_alive") or target.is_alive()):
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.5 \
				and rad_to_deg(forward.angle_to(to_target.normalized())) < aim_assist_degrees:
			return to_target.normalized()
	return forward


## The point in the world under the screen centre, up to 60 m away.
func _crosshair_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 7, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else to


## Dash the way you're pressing, or where you aim when standing still.
func dash_direction() -> Vector3:
	return _move_input if _move_input.length_squared() > 0.01 else aim_direction()
