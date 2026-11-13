class_name Ability
extends Node
## Base for every bending move: cooldown, chi cost and activation.
## The bender builds one of these per unlocked slot from balance.json
## (elements.<element>.abilities.<slot>) and applies skill-tree mods on top,
## so tuning never needs code. Subclasses override _activate().

signal used
signal failed(reason: String)

var user: Bender
## "basic", "special", "utility" or "ultimate".
var slot := ""
var stats: Dictionary = {}
var display_name := ""
var cooldown := 0.5
var chi_cost := 0.0
var _remaining := 0.0


## Called once by the bender right after the node is added.
func setup(p_user: Bender, p_slot: String, p_stats: Dictionary, mods: Array) -> void:
	user = p_user
	slot = p_slot
	stats = p_stats
	for mod: Dictionary in mods:
		if mod.get("slot", "") != slot:
			continue
		var stat: String = mod.get("stat", "")
		var value: float = float(stats.get(stat, 0.0))
		if mod.has("mult"):
			value *= float(mod["mult"])
		if mod.has("add"):
			value += float(mod["add"])
		stats[stat] = value
	display_name = str(stats.get("name", slot.capitalize()))
	cooldown = maxf(float(stats.get("cooldown", cooldown)), 0.05)
	chi_cost = float(stats.get("chi_cost", chi_cost))


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)


func is_ready() -> bool:
	return _remaining <= 0.0


## 0 when ready, 1 right after use. The HUD draws this.
func cooldown_ratio() -> float:
	return _remaining / cooldown if cooldown > 0.0 else 0.0


func seconds_left() -> float:
	return _remaining


## Checks cooldown, then chi, then fires. Returns true when it fired.
func try_activate() -> bool:
	if not is_ready() or not user.can_act():
		return false
	if not user.chi.spend(chi_cost):
		failed.emit("chi")
		return false
	_remaining = cooldown
	_activate()
	used.emit()
	return true


func reset_cooldown() -> void:
	_remaining = 0.0


## How far this move reaches, used by the AI to decide when to use it.
func reach() -> float:
	return float(stats.get("range", stats.get("radius", 6.0)))


func _activate() -> void:
	push_warning("%s has no _activate()" % name)
