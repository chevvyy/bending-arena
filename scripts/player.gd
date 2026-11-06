extends CharacterBody3D
## Third-person bender controller: camera-relative movement, sprint, jump and a
## mouse-orbit camera on a SpringArm3D so the camera never clips into walls.

@export_group("Movement")
@export var move_speed := 6.0
@export var sprint_speed := 9.5
@export var acceleration := 40.0
## Fraction of ground acceleration you keep while in the air.
@export_range(0.0, 1.0) var air_control := 0.35
@export var jump_velocity := 6.5
@export var turn_speed := 12.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch_degrees := -70.0
@export var max_pitch_degrees := 35.0
@export var start_pitch_degrees := -18.0

@export_group("Arena")
## Falling below this height puts you back at the spawn point.
@export var kill_height := -20.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D


func _ready() -> void:
	_spawn_position = global_position
	spring_arm.add_excluded_object(get_rid())
	spring_arm.rotation.x = deg_to_rad(start_pitch_degrees)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		camera_pivot.rotation.y -= motion.relative.x * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# Movement is relative to where the camera looks, flattened onto the floor.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_yaw := Basis(Vector3.UP, camera_pivot.rotation.y)
	var direction := (camera_yaw * Vector3(input.x, 0.0, input.y)).normalized()

	var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(direction * speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# Turn the body toward the way you're moving. The model faces -Z.
	if direction.length_squared() > 0.0001:
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)

	if global_position.y < kill_height:
		respawn()


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO


## Direction the bender is facing, flat on the floor. Use it to aim abilities.
func facing() -> Vector3:
	return -model.global_transform.basis.z.normalized()
