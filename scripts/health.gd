class_name Health
extends Node
## Hit points for anything that can be hurt. The HUD and the round manager
## listen to its signals, so nothing else has to poll HP.

signal changed(current: float, maximum: float)
signal died

@export var max_hp := 100.0

var current := 0.0


func _ready() -> void:
	reset()


## Refill to full. Pass a new maximum to change it (an element switch does).
func reset(new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_hp = new_max
	current = max_hp
	changed.emit(current, max_hp)


func is_dead() -> bool:
	return current <= 0.0


func ratio() -> float:
	return current / max_hp if max_hp > 0.0 else 0.0


func take_damage(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	changed.emit(current, max_hp)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0 or current >= max_hp:
		return
	current = minf(current + amount, max_hp)
	changed.emit(current, max_hp)
