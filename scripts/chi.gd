class_name Chi
extends Node
## The bender's chi pool. Regenerates every frame; abilities call spend().
## Max and regen come from balance.json ("chi"), adjusted by skill-tree passives.

signal changed(current: float, maximum: float)

var max_chi := 100.0
var regen_per_second := 10.0
var current := 0.0


func _ready() -> void:
	configure({})


## Reads balance.json and applies passives like chi_regen_mult and chi_max_add.
func configure(passive: Dictionary) -> void:
	max_chi = float(Balance.get_value("chi.max", 100.0)) + float(passive.get("chi_max_add", 0.0))
	regen_per_second = float(Balance.get_value("chi.regen_per_second", 10.0)) \
			* float(passive.get("chi_regen_mult", 1.0))
	refill()


func _process(delta: float) -> void:
	if current < max_chi:
		current = minf(current + regen_per_second * delta, max_chi)
		changed.emit(current, max_chi)


func refill() -> void:
	current = max_chi
	changed.emit(current, max_chi)


func has(amount: float) -> bool:
	return current >= amount


## Takes the chi and returns true, or returns false and takes nothing.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current < amount:
		return false
	current -= amount
	changed.emit(current, max_chi)
	return true
