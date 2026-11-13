class_name Bender
extends CharacterBody3D
## Everything the player and the AI opponent share: element stats, HP and chi,
## the ability slots, movement physics, and reactions to hits (slow, knockback,
## dash, healing). player.gd adds keyboard, mouse and camera; ai_bender.gd adds
## the AI brain. Both just call move_with() and use_slot().

signal element_changed(element: String)
signal loadout_changed
signal hit_taken(hit: Dictionary)

const ABILITY_SCRIPTS := {
	"projectile": "res://scripts/abilities/projectile_ability.gd",
	"dash": "res://scripts/abilities/dash_ability.gd",
	"area": "res://scripts/abilities/area_ability.gd",
	"heal": "res://scripts/abilities/heal_ability.gd",
	"wall": "res://scripts/abilities/wall_ability.gd",
	"tornado": "res://scripts/abilities/tornado_ability.gd",
}

@export_enum("fire", "water", "earth", "air") var element := "fire"
@export var display_name := "Bender"

@export_group("Movement")
@export var move_speed := 6.0
@export var acceleration := 40.0
## Fraction of ground acceleration you keep while in the air.
@export_range(0.0, 1.0) var air_control := 0.35
@export var jump_velocity := 6.5
@export var turn_speed := 12.0

@export_group("Arena")
## Falling below this height puts you back at the spawn point.
@export var kill_height := -20.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var sprint_speed := 9.5
## slot name -> Ability
var abilities: Dictionary = {}
## True between rounds: no moving or bending.
var frozen := false

var _walk := Vector3.ZERO
var _knock := Vector3.ZERO
var _slow_amount := 0.0
var _slow_time := 0.0
var _dash_velocity := Vector3.ZERO
var _dash_time := 0.0
var _invulnerable_time := 0.0
var _heal_per_second := 0.0
var _heal_time := 0.0
var _spawn := Transform3D.IDENTITY
var _body_material: StandardMaterial3D

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body
@onready var health: Health = $Health
@onready var chi: Chi = $Chi
@onready var ability_root: Node = $Abilities


func _ready() -> void:
	add_to_group("benders")
	_spawn = global_transform
	_body_material = StandardMaterial3D.new()
	_body_material.roughness = 0.6
	_body_material.emission_enabled = true
	_body_material.emission = Color.BLACK
	body_mesh.material_override = _body_material
	health.died.connect(_on_died)


## Switches element: HP, speed and colour from balance.json, then one ability
## node per slot in the loadout (see Game.player_loadout / ai_loadout).
func apply_element(new_element: String, loadout: Dictionary) -> void:
	element = new_element
	var passive: Dictionary = loadout.get("passive", {})
	var base_speed := float(Balance.get_value("elements.%s.move_speed" % element, 6.0))
	move_speed = base_speed * float(passive.get("speed_mult", 1.0))
	sprint_speed = move_speed * 1.6
	var hp := float(Balance.get_value("elements.%s.hp" % element, 100.0))
	health.reset(hp * float(passive.get("hp_mult", 1.0)))
	chi.configure(passive)
	_body_material.albedo_color = Balance.element_color(element)
	_build_abilities(loadout)
	element_changed.emit(element)


func _build_abilities(loadout: Dictionary) -> void:
	for child in ability_root.get_children():
		ability_root.remove_child(child)
		child.queue_free()
	abilities.clear()
	for slot: String in loadout.get("slots", ["basic"]):
		var stats: Dictionary = Balance.get_value(
			"elements.%s.abilities.%s" % [element, slot], {}).duplicate(true)
		var type: String = stats.get("type", "")
		if not ABILITY_SCRIPTS.has(type):
			push_warning("%s %s: unknown ability type '%s'" % [element, slot, type])
			continue
		var ability: Ability = load(ABILITY_SCRIPTS[type]).new()
		ability.name = slot.capitalize()
		ability_root.add_child(ability)
		ability.setup(self, slot, stats, loadout.get("mods", []))
		abilities[slot] = ability
	loadout_changed.emit()


## Fires the ability in a slot if it is unlocked, ready and affordable.
func use_slot(slot: String) -> bool:
	var ability: Ability = abilities.get(slot)
	return ability != null and ability.try_activate()


func has_slot(slot: String) -> bool:
	return abilities.has(slot)


func is_alive() -> bool:
	return not health.is_dead()


func can_act() -> bool:
	return is_alive() and not frozen


## Shared movement: gravity, jump, acceleration, slows, dashes and knockback.
## direction is flat and at most length 1.
func move_with(direction: Vector3, sprint: bool, jump: bool, delta: float) -> void:
	_tick_status(delta)
	if not can_act():
		direction = Vector3.ZERO
		jump = false
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump:
		velocity.y = jump_velocity

	if _dash_time > 0.0:
		_walk = _dash_velocity
	else:
		var speed := (sprint_speed if sprint else move_speed) * (1.0 - _slow_amount)
		var accel := acceleration if is_on_floor() else acceleration * air_control
		_walk = _walk.move_toward(direction * speed, accel * delta)
	_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
	velocity.x = _walk.x + _knock.x
	velocity.z = _walk.z + _knock.z

	move_and_slide()

	# Turn the body toward the way you're moving. The model faces -Z.
	if direction.length_squared() > 0.0001 and _dash_time <= 0.0:
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)

	if global_position.y < kill_height:
		global_transform = _spawn
		velocity = Vector3.ZERO
		_walk = Vector3.ZERO


func _tick_status(delta: float) -> void:
	_slow_time = maxf(_slow_time - delta, 0.0)
	if _slow_time <= 0.0:
		_slow_amount = 0.0
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	if _dash_time > 0.0:
		_dash_time -= delta
		if _dash_time <= 0.0:
			_walk = _walk.limit_length(move_speed)
	if _heal_time > 0.0:
		_heal_time -= delta
		health.heal(_heal_per_second * delta)


## hit is a Dictionary: damage, direction, attacker, knockback, slow, slow_time.
func take_hit(hit: Dictionary) -> void:
	if not is_alive() or _invulnerable_time > 0.0:
		return
	var damage := float(hit.get("damage", 0.0))
	health.take_damage(damage)
	var slow := float(hit.get("slow", 0.0))
	if slow > 0.0:
		_slow_amount = clampf(maxf(_slow_amount, slow), 0.0, 0.9)
		_slow_time = maxf(_slow_time, float(hit.get("slow_time", 1.0)))
	var knockback := float(hit.get("knockback", 0.0))
	if knockback > 0.0:
		var direction: Vector3 = hit.get("direction", Vector3.ZERO)
		_knock += direction * knockback
		if is_on_floor():
			velocity.y = maxf(velocity.y, knockback * 0.3)
	_flash(Color(1.0, 0.25, 0.2) if slow <= 0.0 else Color(0.5, 0.8, 1.0))
	if damage > 0.0:
		Effects.number(get_parent(), global_position + Vector3.UP * 2.1,
			str(roundi(damage)), Color(1.0, 0.85, 0.3))
	hit_taken.emit(hit)


func heal_over_time(amount: float, seconds: float) -> void:
	_heal_time = maxf(seconds, 0.1)
	_heal_per_second = amount / _heal_time
	_flash(Color(0.3, 1.0, 0.7))
	Effects.number(get_parent(), global_position + Vector3.UP * 2.1, "+%d" % roundi(amount),
		Color(0.4, 1.0, 0.6))


func dash(direction: Vector3, speed: float, seconds: float, up: float, invulnerable: bool) -> void:
	_dash_velocity = direction.normalized() * speed
	_dash_time = seconds
	if up > 0.0:
		velocity.y = up
	if invulnerable:
		_invulnerable_time = seconds + 0.05
	face(direction)


func is_slowed() -> bool:
	return _slow_amount > 0.0


## Called by the round manager at the start of every round.
func reset_for_round() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	_walk = Vector3.ZERO
	_knock = Vector3.ZERO
	_slow_amount = 0.0
	_slow_time = 0.0
	_dash_time = 0.0
	_invulnerable_time = 0.0
	_heal_time = 0.0
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	health.reset()
	chi.refill()
	for ability: Ability in abilities.values():
		ability.reset_cooldown()


## Where the spawn point is; the round manager sets it before the first round.
func set_spawn(spawn: Transform3D) -> void:
	_spawn = spawn
	global_transform = spawn


## Direction the bender is facing, flat on the floor.
func facing() -> Vector3:
	return -model.global_transform.basis.z.normalized()


## Flat direction abilities fire in. Player and AI override this.
func aim_direction() -> Vector3:
	return facing()


## Direction a dash goes. Player and AI override this.
func dash_direction() -> Vector3:
	return facing()


## Snap the body to face a direction (used when firing).
func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		model.rotation.y = atan2(-direction.x, -direction.z)


func _flash(color: Color) -> void:
	_body_material.emission = color
	var tween := create_tween()
	tween.tween_property(_body_material, "emission", Color.BLACK, 0.25)


## Knocked out: tip over. reset_for_round() stands the bender back up.
func _on_died() -> void:
	_heal_time = 0.0
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", -PI * 0.5, 0.4)
	tween.parallel().tween_property(model, "position:y", 0.4, 0.4)
