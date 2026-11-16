extends Node3D
## Title screen: the arena turns slowly behind a menu where you pick your
## element, the opponent and the difficulty, then fight, train or open the
## skill trees. Picks are saved with the rest of the game.

const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const OPPONENTS: Array[String] = ["random", "fire", "water", "earth", "air"]

@export var orbit_speed := 0.08

var _element_buttons: Dictionary = {}
var _points_label: Label
var _element_info: Label
var _opponent_option: OptionButton
var _difficulty_option: OptionButton
var _record_label: Label

@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	camera_pivot.rotate_y(orbit_speed * delta)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	UI.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := UI.panel(Color(0.06, 0.05, 0.05, 0.85), 28)
	UI.place(panel, Vector2(0.5, 0.5), Vector2.ZERO)
	root.add_child(panel)
	var box := UI.vbox(12)
	panel.add_child(box)

	var title := UI.label("BENDING ARENA", 56, Color(1.0, 0.86, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UI.label("Pick an element. Master its tree. Win the duel.", 18, UI.MUTED_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(UI.label("Your element", 18))
	var row := UI.hbox(8)
	box.add_child(row)
	for element in Game.ELEMENTS:
		var b := UI.button(Balance.element_title(element), _pick_element.bind(element),
			Balance.element_color(element), Vector2(150, 48))
		b.toggle_mode = true
		row.add_child(b)
		_element_buttons[element] = b
	_element_info = UI.label("", 15, UI.MUTED_COLOR)
	box.add_child(_element_info)

	var options := UI.hbox(16)
	box.add_child(options)
	options.add_child(UI.label("Opponent", 18))
	_opponent_option = OptionButton.new()
	for choice in OPPONENTS:
		_opponent_option.add_item(choice.capitalize() if choice == "random" else Balance.element_title(choice))
	_opponent_option.item_selected.connect(_on_opponent_selected)
	options.add_child(_opponent_option)
	options.add_child(UI.label("Difficulty", 18))
	_difficulty_option = OptionButton.new()
	for level in DIFFICULTIES:
		_difficulty_option.add_item(level.capitalize())
	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	options.add_child(_difficulty_option)

	_points_label = UI.label("", 18, Color(1.0, 0.8, 0.45))
	box.add_child(_points_label)

	box.add_child(UI.button("Fight", _start.bind("match"), Color(0.9, 0.45, 0.2), Vector2(620, 52)))
	box.add_child(UI.button("Training", _start.bind("training"), Color(0.5, 0.7, 0.9), Vector2(620, 44)))
	box.add_child(UI.button("Skill Trees", _open_trees, Color(0.6, 0.8, 0.4), Vector2(620, 44)))
	box.add_child(UI.button("Quit", func() -> void: get_tree().quit(), Color(0.6, 0.6, 0.6), Vector2(620, 40)))

	_record_label = UI.label("", 14, UI.MUTED_COLOR)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_record_label)


func _refresh() -> void:
	for element: String in _element_buttons:
		var b: Button = _element_buttons[element]
		b.set_pressed_no_signal(element == Game.player_element)
	var el := Game.player_element
	var loadout := Game.player_loadout(el)
	var names := PackedStringArray()
	for slot: String in loadout["slots"]:
		names.append(str(Balance.get_value("elements.%s.abilities.%s.name" % [el, slot], slot)))
	_element_info.text = "%d HP, speed %.1f. Unlocked: %s" % [
		int(Balance.get_value("elements.%s.hp" % el, 100)),
		float(Balance.get_value("elements.%s.move_speed" % el, 6.0)),
		", ".join(names)]
	_opponent_option.select(maxi(OPPONENTS.find(Game.opponent_choice), 0))
	_difficulty_option.select(maxi(DIFFICULTIES.find(Game.difficulty), 1))
	_points_label.text = "Skill points to spend: %d" % Game.skill_points
	_record_label.text = "Matches won: %d of %d" % [Game.matches_won, Game.matches_played]


func _pick_element(element: String) -> void:
	Game.player_element = element
	Game.save_game()
	_refresh()


func _on_opponent_selected(index: int) -> void:
	Game.opponent_choice = OPPONENTS[index]
	Game.save_game()


func _on_difficulty_selected(index: int) -> void:
	Game.difficulty = DIFFICULTIES[index]
	Game.save_game()


func _start(mode: String) -> void:
	Game.mode = mode
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _open_trees() -> void:
	get_tree().change_scene_to_file("res://scenes/skill_tree.tscn")
