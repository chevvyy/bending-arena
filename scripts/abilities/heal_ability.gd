class_name HealAbility
extends Ability
## Healing Tide: heals "amount" HP spread over "duration" seconds.


func _activate() -> void:
	user.heal_over_time(float(stats.get("amount", 30.0)), float(stats.get("duration", 4.0)))
	Effects.ring(user.get_parent(), user.global_position + Vector3.UP * 0.1, 1.6,
		Color(str(stats.get("color", "#5fe0c8"))), 0.6)


func reach() -> float:
	return 0.0
