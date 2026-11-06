extends Node
## Autoload that registers the game's input actions at startup, so the project
## runs without touching Project Settings. An action you have already defined in
## Project Settings > Input Map is left as you set it.

const KEY_ACTIONS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"release_mouse": [KEY_ESCAPE],
}

const MOUSE_ACTIONS := {
	"attack_basic": [MOUSE_BUTTON_LEFT],
	"attack_special": [MOUSE_BUTTON_RIGHT],
}


func _ready() -> void:
	for action: String in KEY_ACTIONS:
		if _add_action(action):
			for keycode: int in KEY_ACTIONS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action, ev)
	for action: String in MOUSE_ACTIONS:
		if _add_action(action):
			for button: int in MOUSE_ACTIONS[action]:
				var ev := InputEventMouseButton.new()
				ev.button_index = button
				InputMap.action_add_event(action, ev)


## Returns true when the action was missing and has just been created.
func _add_action(action: String) -> bool:
	if InputMap.has_action(action):
		return false
	InputMap.add_action(action)
	return true
