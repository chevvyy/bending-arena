class_name ShieldAbility
extends Ability
## Defensive moves: Air Shield, Fire Ring and Rock Armor. Depending on the
## balance.json entry it blocks enemy shots within "radius", pushes enemies
## out ("push"), cuts damage taken ("reduce") and hits everyone nearby when
## cast ("cast_damage" within "cast_radius").

const ShieldScript := preload("res://scripts/shield.gd")


func _activate() -> void:
	user.animate(str(stats.get("anim", "guard")), float(stats.get("anim_time", -1.0)))
	var duration := float(stats.get("duration", 2.0))
	var reduce := float(stats.get("reduce", 0.0))
	if reduce > 0.0:
		user.armor_up(reduce, duration, float(stats.get("speed_mult", 1.0)))
	var cast_radius := float(stats.get("cast_radius", 0.0))
	if cast_radius > 0.0:
		Effects.area_hit(user, user.global_position, cast_radius, {
			"damage": float(stats.get("cast_damage", 0.0)),
			"knockback": float(stats.get("knockback", 0.0)),
			"slow": float(stats.get("slow", 0.0)),
			"slow_time": float(stats.get("slow_time", 0.0)),
		})
	var shield: Node3D = ShieldScript.new()
	user.add_child(shield)
	shield.setup(user, stats)


func reach() -> float:
	return maxf(float(stats.get("cast_radius", 0.0)), float(stats.get("radius", 0.0)))
