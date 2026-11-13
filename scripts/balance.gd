extends Node
## Autoload "Balance": reads data/balance.json once so every script uses the
## same numbers. Ask for a value with a dotted path: Balance.get_value("chi.max").

const PATH := "res://data/balance.json"

var data: Dictionary = {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Could not read %s" % PATH)


## Walks a path like "elements.fire.hp". Returns fallback when any key is missing.
func get_value(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = data
	for key in path.split("."):
		if node is Dictionary and node.has(key):
			node = node[key]
		else:
			return fallback
	return node


## Element colour from balance.json as a Color.
func element_color(element: String) -> Color:
	return Color(str(get_value("elements.%s.color" % element, "#ffffff")))


## "Firebender", "Waterbender" and so on.
func element_title(element: String) -> String:
	return str(get_value("elements.%s.display" % element, element.capitalize()))
