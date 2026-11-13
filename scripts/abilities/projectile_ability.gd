class_name ProjectileAbility
extends Ability
## Any move made of projectiles: the four basics, Flame Fan, Ice Spike, Gust
## Spiral, Tidal Wave and Boulder Barrage. "count" and "spread_degrees" fan out
## several shots; everything else (speed, size, arc, pierce, slow, knockback)
## comes from the balance.json entry.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

## Height above the bender's feet where shots start (about chest height).
var muzzle_height := 1.2


func _activate() -> void:
	var direction: Vector3 = user.aim_direction()
	user.face(direction)
	var count: int = maxi(int(stats.get("count", 1)), 1)
	var spread := deg_to_rad(float(stats.get("spread_degrees", 0.0)))
	var origin := user.global_position + Vector3.UP * muzzle_height + direction * 0.7
	for i in count:
		var angle := 0.0
		if count > 1:
			angle = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var shot: Projectile = PROJECTILE_SCENE.instantiate()
		user.get_parent().add_child(shot)
		shot.setup(user, origin, direction.rotated(Vector3.UP, angle), stats)
