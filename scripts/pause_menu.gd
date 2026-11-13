extends CanvasLayer
## Esc (or P) pauses the fight: Resume, Restart, Skill Trees, Main Menu, Quit.
## Runs while the tree is paused (process_mode = Always in main.tscn).

@export var round_manager: Node
@export var hud: CanvasLayer

var _panel: Control


func _ready() -> void:
	_panel = UI.panel(Color(0.05, 0.05, 0.05, 0.9), 28)
	UI.place(_panel, Vector2(0.5, 0.5), Vector2.ZERO)
	add_child(_panel)
	var box := UI.vbox(12)
	_panel.add_child(box)
	var title := UI.label("Paused", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UI.button("Resume", resume))
	box.add_child(UI.button("Restart Match", _restart))
	box.add_child(UI.button("Main Menu", _to_menu))
	box.add_child(UI.button("Quit Game", func() -> void: get_tree().quit()))
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if hud != null and hud.results_visible():
			return
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	get_tree().paused = true
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	get_tree().paused = false
	_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _panel.visible


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
