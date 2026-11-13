class_name AiBender
extends Bender
## The computer opponent. AiBrain decides; this script just feeds its choices
## into the shared Bender movement and abilities.

var brain: AiBrain

@onready var name_label: Label3D = $NameLabel


func _ready() -> void:
	super._ready()
	brain = AiBrain.new(self, "normal")


## Set up for a match: element, difficulty and who to fight.
func configure(new_element: String, level: String, opponent: Node3D) -> void:
	brain.configure(level)
	brain.target = opponent
	apply_element(new_element, Game.ai_loadout(new_element, level))
	display_name = "%s (%s)" % [Balance.element_title(new_element), level.capitalize()]
	name_label.text = display_name
	name_label.modulate = Balance.element_color(new_element).lightened(0.3)


func _physics_process(delta: float) -> void:
	brain.update(delta)
	move_with(brain.move, brain.sprint, brain.jump, delta)
	brain.take_actions()


func aim_direction() -> Vector3:
	return brain.aim


func aim_point(max_range: float) -> Vector3:
	return brain.aim_point(max_range)


func dash_direction() -> Vector3:
	return brain.move if brain.move.length_squared() > 0.01 else flat_aim()
