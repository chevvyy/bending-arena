extends Control
## Skill tree screen: one tab per element, nodes laid out by tier. Click a node
## to buy it with skill points (earned by winning rounds). "Reset" refunds every
## point in that element's tree. Unlocks are saved to user://save.json.

const STATE_COLORS := {
	"owned": Color(0.35, 0.75, 0.4),
	"available": Color(1.0, 0.75, 0.3),
	"expensive": Color(0.6, 0.5, 0.35),
	"locked": Color(0.4, 0.4, 0.4),
}
const STATE_TEXT := {
	"owned": "Learned",
	"available": "Click to learn",
	"expensive": "Need more points",
	"locked": "Locked",
}

var element := "fire"
var _tabs: HBoxContainer
var _tree_box: VBoxContainer
var _points_label: Label
var _detail: Label
var _reset_button: Button
var _node_buttons: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	element = Game.player_element
	_build_ui()
	Game.points_changed.connect(_on_points_changed)
	Game.tree_changed.connect(_on_tree_changed)
	_show_element(element)


func _build_ui() -> void:
	UI.full_rect(self)
	var background := ColorRect.new()
	background.color = Color(0.09, 0.08, 0.07)
	UI.full_rect(background)
	add_child(background)

	var margin := MarginContainer.new()
	UI.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var box := UI.vbox(14)
	margin.add_child(box)

	var header := UI.hbox(20)
	box.add_child(header)
	var title := UI.label("Skill Trees", 40, Color(1.0, 0.86, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_points_label = UI.label("", 22, Color(1.0, 0.8, 0.45))
	header.add_child(_points_label)

	_tabs = UI.hbox(8)
	box.add_child(_tabs)
	for el in Game.ELEMENTS:
		var tab := UI.button(Balance.element_title(el), _show_element.bind(el),
			Balance.element_color(el), Vector2(180, 44))
		tab.toggle_mode = true
		tab.name = el
		_tabs.add_child(tab)

	var hint := UI.label("Each element has its own tree. Earn points by winning rounds (+1) and matches (+2). "
		+ "Training mode lets you try every move before you buy it.", 15, UI.MUTED_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	_tree_box = UI.vbox(18)
	_tree_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tree_box)

	_detail = UI.label("", 18)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 52)
	box.add_child(_detail)

	var footer := UI.hbox(12)
	box.add_child(footer)
	footer.add_child(UI.button("Back", _back, Color(0.6, 0.6, 0.6), Vector2(180, 44)))
	_reset_button = UI.button("Reset tree", _reset, Color(0.85, 0.35, 0.3), Vector2(240, 44))
	footer.add_child(_reset_button)
	footer.add_child(UI.button("Training", _train, Color(0.5, 0.7, 0.9), Vector2(180, 44)))
	footer.add_child(UI.button("Fight", _fight, Color(0.9, 0.45, 0.2), Vector2(180, 44)))


func _show_element(el: String) -> void:
	element = el
	for tab: Button in _tabs.get_children():
		tab.set_pressed_no_signal(tab.name == el)
	for child in _tree_box.get_children():
		child.queue_free()
	_node_buttons.clear()

	var basic_name := str(Balance.get_value("elements.%s.abilities.basic.name" % el, "Basic"))
	var base_row := UI.hbox(16)
	base_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tree_box.add_child(base_row)
	base_row.add_child(UI.label("%s: %s (LMB) is always yours" % [Balance.element_title(el), basic_name],
		18, Balance.element_color(el).lightened(0.4)))

	var tiers: Dictionary = {}
	for node: Dictionary in Game.tree_nodes(el):
		var tier := int(node.get("tier", 1))
		if not tiers.has(tier):
			tiers[tier] = []
		tiers[tier].append(node)
	var tier_keys := tiers.keys()
	tier_keys.sort()
	for tier: int in tier_keys:
		var row := UI.hbox(24)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_tree_box.add_child(row)
		for node: Dictionary in tiers[tier]:
			var id: String = node.get("id", "")
			var b := UI.button("", _buy.bind(id), Balance.element_color(el), Vector2(300, 84))
			b.mouse_entered.connect(_describe.bind(node))
			b.focus_entered.connect(_describe.bind(node))
			row.add_child(b)
			_node_buttons[id] = b
	_refresh()


func _refresh() -> void:
	_points_label.text = "Skill points: %d" % Game.skill_points
	for id: String in _node_buttons:
		var node := Game.find_node_def(element, id)
		var state := Game.node_state(element, id)
		var b: Button = _node_buttons[id]
		var cost := int(node.get("cost", 1))
		b.text = "%s\n%s  (%d pt%s)" % [node.get("name", id), STATE_TEXT[state], cost, "" if cost == 1 else "s"]
		b.modulate = STATE_COLORS[state].lightened(0.35)
		b.disabled = state == "locked" or state == "expensive"
		b.tooltip_text = str(node.get("desc", ""))
	var spent := Game.spent_in(element)
	_reset_button.text = "Reset tree (+%d)" % spent
	_reset_button.disabled = spent == 0


func _on_points_changed(_points: int) -> void:
	_refresh()


func _on_tree_changed(_element: String) -> void:
	_refresh()


func _describe(node: Dictionary) -> void:
	var reqs: Array = node.get("requires", [])
	var req_names := PackedStringArray()
	for id: String in reqs:
		req_names.append(str(Game.find_node_def(element, id).get("name", id)))
	var needs := ""
	if not reqs.is_empty():
		needs = "   Needs %s %s." % [" or ".join(req_names) if node.get("requires_any", false)
			else " and ".join(req_names), "first"]
	_detail.text = "%s: %s%s" % [node.get("name", ""), node.get("desc", ""), needs]


func _buy(id: String) -> void:
	if Game.buy(element, id):
		_describe(Game.find_node_def(element, id))


func _reset() -> void:
	Game.reset_tree(element)


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _train() -> void:
	Game.player_element = element
	Game.mode = "training"
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _fight() -> void:
	Game.player_element = element
	Game.mode = "match"
	Game.save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
