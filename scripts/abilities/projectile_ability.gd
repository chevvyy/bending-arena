class_name ProjectileAbility
extends Ability
## Any move made of projectiles: fire jabs, the fireball, ice daggers, rocks,
## air blasts, blades and the tidal wave. "count" and "spread_degrees" fan out
## several shots; everything else (speed, size, arc, pierce, slow, knockback,
## look) comes from the balance.json entry.
##
## A "combo" list turns the move into a chain: each use within combo_window
## seconds of the last takes the next step, whose entries override the base
## stats ("damage_mult" multiplies, anything else replaces). Fire Jabs go
## jab, jab, flame kick this way.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

var _combo_step := 0
var _since_use := 99.0


func _process(delta: float) -> void:
	super._process(delta)
	_since_use += delta


func _activate() -> void:
	var shot_stats := stats
	var combo: Array = stats.get("combo", [])
	if not combo.is_empty():
		if _since_use > float(stats.get("combo_window", 0.9)):
			_combo_step = 0
		shot_stats = _merge(stats, combo[_combo_step % combo.size()])
		_combo_step = (_combo_step + 1) % combo.size()
	_since_use = 0.0
	fire(shot_stats)


## Fires the shots described by `shot_stats` along the user's aim.
func fire(shot_stats: Dictionary) -> void:
	var direction: Vector3 = user.aim_direction()
	user.face_aim(direction)
	user.animate(str(shot_stats.get("anim", "punch")))
	var count: int = maxi(int(shot_stats.get("count", 1)), 1)
	var spread := deg_to_rad(float(shot_stats.get("spread_degrees", 0.0)))
	var origin := user.muzzle() + Vector3(direction.x, 0.0, direction.z).normalized() * 0.6
	for i in count:
		var angle := 0.0
		if count > 1:
			angle = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var shot: Projectile = PROJECTILE_SCENE.instantiate()
		user.get_parent().add_child(shot)
		var offset := Vector3.ZERO
		if count > 1 and float(shot_stats.get("rise_time", 0.0)) > 0.0:
			# Rocks pulled from the ground come up side by side.
			offset = Vector3(-direction.z, 0.0, direction.x).normalized() * lerpf(-1.0, 1.0, float(i) / float(count - 1))
		shot.setup(user, origin + offset, direction.rotated(Vector3.UP, angle), shot_stats)


static func _merge(base: Dictionary, step: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	merged.erase("combo")
	for key: String in step:
		if key.ends_with("_mult"):
			var stat := key.trim_suffix("_mult")
			merged[stat] = float(merged.get(stat, 0.0)) * float(step[key])
		else:
			merged[key] = step[key]
	return merged
