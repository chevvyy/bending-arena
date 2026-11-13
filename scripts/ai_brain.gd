class_name AiBrain
extends RefCounted
## Decision-making for a computer-controlled bender. Each "think" (every
## `reaction` seconds) it picks where to move and which moves to use; between
## thinks it keeps doing the last thing, which is what makes slower reactions
## easier to beat. The AI opponent uses it, and so does the player's
## autopilot in the smoke test.

## How far away each element likes to fight.
const PREFERRED_RANGE := {"fire": 9.0, "water": 7.5, "earth": 11.0, "air": 4.5}
## Inside this box the arena is safe; past it the AI steers back to the middle.
const ARENA_HALF := 16.5

var body: Bender
var target: Node3D
var reaction := 0.28
var aim_error_degrees := 6.0
var fire_chance := 0.8
var use_chance := 0.6

var move := Vector3.ZERO
var sprint := false
var jump := false
var aim := Vector3.FORWARD

var _think_left := 0.0
var _strafe_sign := 1.0
var _strafe_left := 0.0
var _firing := false
var _aim_error := 0.0
var _last_position := Vector3.ZERO
var _stuck_time := 0.0
var _pending: Array[String] = []


func _init(p_body: Bender, level: String) -> void:
	body = p_body
	configure(level)


func configure(level: String) -> void:
	var settings: Dictionary = Balance.get_value("ai.%s" % level, {})
	reaction = float(settings.get("reaction", reaction))
	aim_error_degrees = float(settings.get("aim_error_degrees", aim_error_degrees))
	fire_chance = float(settings.get("fire_chance", fire_chance))
	use_chance = float(settings.get("use_chance", use_chance))


## Run once per physics frame. Afterwards read move/sprint/jump/aim and call
## take_actions() to fire whatever the brain decided on.
func update(delta: float) -> void:
	jump = false
	if target == null or not is_instance_valid(target) or not body.can_act():
		move = Vector3.ZERO
		_firing = false
		_pending.clear()
		return
	var to_target := target.global_position - body.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var toward := to_target / distance if distance > 0.01 else body.facing()

	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_left = randf_range(0.8, 2.2)
		_strafe_sign = -_strafe_sign if randf() < 0.6 else _strafe_sign

	_check_stuck(delta)
	_aim_at(toward, distance)

	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = reaction * randf_range(0.8, 1.2)
		_think(toward, distance)


func take_actions() -> void:
	if _firing and _in_reach("basic", target_distance()) and has_line_of_sight():
		body.use_slot("basic")
	while not _pending.is_empty():
		body.use_slot(_pending.pop_front())


func target_distance() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	var offset := target.global_position - body.global_position
	offset.y = 0.0
	return offset.length()


func has_line_of_sight() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var from := body.global_position + Vector3.UP * 1.2
	var to := target.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _think(toward: Vector3, distance: float) -> void:
	var sees := has_line_of_sight()
	var preferred: float = PREFERRED_RANGE.get(body.element, 8.0)
	var radial := 0.0
	if not sees or distance > preferred + 1.5:
		radial = 1.0
	elif distance < preferred - 1.5:
		radial = -1.0
	var tangent := Vector3(-toward.z, 0.0, toward.x) * _strafe_sign
	var wish := toward * radial + tangent * (1.2 if not sees else 0.8)
	# Steer back toward the middle near the walls so it doesn't get pinned.
	var pos := body.global_position
	if absf(pos.x) > ARENA_HALF or absf(pos.z) > ARENA_HALF:
		wish += -Vector3(pos.x, 0.0, pos.z).normalized() * 1.5
	move = wish.normalized() if wish.length() > 0.01 else Vector3.ZERO
	sprint = distance > preferred + 6.0
	if randf() < 0.06:
		jump = true

	_firing = sees and randf() < fire_chance
	_aim_error = deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees))
	_pending.clear()
	if randf() > use_chance:
		return
	for slot in ["ultimate", "special", "utility"]:
		if body.has_slot(slot) and _wants(slot, distance, sees):
			_pending.append(slot)
			break


func _wants(slot: String, distance: float, sees: bool) -> bool:
	var ability: Ability = body.abilities.get(slot)
	if ability == null or not ability.is_ready() or not body.chi.has(ability.chi_cost):
		return false
	if ability is HealAbility:
		return body.health.ratio() < 0.6
	if ability is DashAbility:
		# Air leaps in to close distance; fire dashes out when crowded.
		if body.element == "air":
			return distance > 9.0
		return distance < 3.5 or body.health.ratio() < 0.4
	if ability is WallAbility:
		return sees and distance > 6.0 and body.health.ratio() < 0.85 and randf() < 0.5
	if ability is AreaAbility:
		return distance < ability.reach() * 0.8
	return sees and distance < ability.reach() * 0.85


func _in_reach(slot: String, distance: float) -> bool:
	var ability: Ability = body.abilities.get(slot)
	return ability != null and distance < ability.reach() * 0.95


## Aims at where the target will be when a basic shot arrives, plus some error.
func _aim_at(toward: Vector3, distance: float) -> void:
	var lead := Vector3.ZERO
	var basic: Ability = body.abilities.get("basic")
	if basic != null and target is CharacterBody3D:
		var speed := maxf(float(basic.stats.get("speed", 20.0)), 1.0)
		var target_velocity := (target as CharacterBody3D).velocity
		target_velocity.y = 0.0
		lead = target_velocity * (distance / speed)
	var point := target.global_position + lead - body.global_position
	point.y = 0.0
	var direction := point.normalized() if point.length() > 0.01 else toward
	aim = direction.rotated(Vector3.UP, _aim_error)


## Walking into a pillar for a while: switch strafe direction and hop.
func _check_stuck(delta: float) -> void:
	var moved := body.global_position.distance_to(_last_position)
	_last_position = body.global_position
	if move.length() > 0.5 and moved < 0.5 * body.move_speed * delta:
		_stuck_time += delta
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			_strafe_sign = -_strafe_sign
			jump = true
	else:
		_stuck_time = 0.0
