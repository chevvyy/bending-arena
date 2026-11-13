extends CanvasLayer
## Everything drawn over the 3D view: your HP and chi, the four ability slots
## with cooldowns, the opponent's HP, round info, banners, crosshair and the
## end-of-match results. Built in code in _ready(); bind() hooks it to a fight.

const SLOT_KEYS := {"basic": "LMB", "special": "RMB", "utility": "Q", "ultimate": "R"}
const HELP_TEXT := "WASD move   Shift sprint   Space jump   Mouse aim\n" \
		+ "LMB basic   RMB special   Q utility   R ultimate\n" \
		+ "Esc pause   H hide this help"
const TRAINING_HELP := "\n1 2 3 4 switch element (training)"

var player: Bender
var target: Node3D

var _root: Control
var _fps: Label
var _help: Label
var _element_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _chi_bar: ProgressBar
var _target_name: Label
var _target_bar: ProgressBar
var _round_label: Label
var _banner: Label
var _slots_box: HBoxContainer
var _slot_widgets: Dictionary = {}
var _results: Control


func _ready() -> void:
	_build()


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(_root)
	add_child(_root)

	_help = UI.label(HELP_TEXT, 15, UI.MUTED_COLOR)
	UI.place(_help, Vector2(0, 0), Vector2(16, 12), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_root.add_child(_help)

	_fps = UI.label("", 14, UI.MUTED_COLOR)
	UI.place(_fps, Vector2(1, 0), Vector2(-16, 12), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_root.add_child(_fps)

	# Top centre: round info and the opponent's HP.
	var top := UI.vbox(4)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.place(top, Vector2(0.5, 0), Vector2(0, 12), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_root.add_child(top)
	_round_label = UI.label("", 20)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_round_label)
	_target_name = UI.label("", 16)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_target_name)
	_target_bar = UI.bar(Color(0.85, 0.22, 0.2), Vector2(380, 18))
	top.add_child(_target_bar)

	# Bottom left: your element, HP and chi.
	var bars := UI.vbox(6)
	UI.place(bars, Vector2(0, 1), Vector2(18, -18), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	_root.add_child(bars)
	_element_label = UI.label("", 22)
	bars.add_child(_element_label)
	var hp_row := UI.hbox(8)
	bars.add_child(hp_row)
	_hp_bar = UI.bar(Color(0.3, 0.8, 0.35), Vector2(280, 22))
	hp_row.add_child(_hp_bar)
	_hp_text = UI.label("", 16)
	hp_row.add_child(_hp_text)
	_chi_bar = UI.bar(Color(0.45, 0.55, 1.0), Vector2(280, 14))
	bars.add_child(_chi_bar)

	# Bottom centre: ability slots.
	_slots_box = UI.hbox(10)
	UI.place(_slots_box, Vector2(0.5, 1), Vector2(0, -18), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_root.add_child(_slots_box)

	var crosshair := UI.label("+", 28)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.place(crosshair, Vector2(0.5, 0.5), Vector2.ZERO)
	_root.add_child(crosshair)

	_banner = UI.label("", 54)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_banner, Vector2(0.5, 0.22), Vector2.ZERO)
	_banner.visible = false
	_root.add_child(_banner)


## Hooks the HUD to the player and their opponent (an AI bender or the dummy).
func bind(p_player: Bender, p_target: Node3D, training: bool) -> void:
	player = p_player
	target = p_target
	_help.text = HELP_TEXT + (TRAINING_HELP if training else "")
	_watch(player.health.changed, _hp_bar, player.health.current, player.health.max_hp)
	player.health.changed.connect(_on_hp_changed)
	_on_hp_changed(player.health.current, player.health.max_hp)
	_watch(player.chi.changed, _chi_bar, player.chi.current, player.chi.max_chi)
	var target_health: Health = target.get("health")
	_watch(target_health.changed, _target_bar, target_health.current, target_health.max_hp)
	player.element_changed.connect(_on_element_changed)
	player.loadout_changed.connect(_rebuild_slots)
	_on_element_changed(player.element)
	_rebuild_slots()
	refresh_target_name()


func refresh_target_name() -> void:
	if target != null:
		_target_name.text = str(target.get("display_name"))


func _process(_delta: float) -> void:
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if Input.is_action_just_pressed("toggle_help"):
		_help.visible = not _help.visible
	if player == null:
		return
	for slot: String in _slot_widgets:
		var widget: Dictionary = _slot_widgets[slot]
		var ability: Ability = player.abilities.get(slot)
		if ability == null:
			continue
		var cd_bar: ProgressBar = widget["bar"]
		cd_bar.value = 1.0 - ability.cooldown_ratio()
		var card: Control = widget["card"]
		var affordable := player.chi.has(ability.chi_cost)
		card.modulate = Color.WHITE if ability.is_ready() and affordable else Color(0.65, 0.65, 0.65)
		var timer: Label = widget["timer"]
		timer.text = "%.1f" % ability.seconds_left() if not ability.is_ready() else ""


func set_round_info(text: String) -> void:
	_round_label.text = text


func show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	_banner.visible = true
	await get_tree().create_timer(seconds, true, false, true).timeout
	if _banner.text == text:
		_banner.visible = false


## End-of-match panel with buttons. buttons is an Array of [label, Callable].
func show_results(title: String, lines: PackedStringArray, buttons: Array) -> void:
	hide_results()
	_results = UI.panel(Color(0.06, 0.05, 0.05, 0.92), 28)
	UI.place(_results, Vector2(0.5, 0.5), Vector2.ZERO)
	_root.add_child(_results)
	var box := UI.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_results.add_child(box)
	var heading := UI.label(title, 44)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	for line in lines:
		var l := UI.label(line, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	for entry: Array in buttons:
		box.add_child(UI.button(entry[0], entry[1]))
	_banner.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_results() -> void:
	if _results != null:
		_results.queue_free()
		_results = null


func results_visible() -> bool:
	return _results != null


func _rebuild_slots() -> void:
	for child in _slots_box.get_children():
		child.queue_free()
	_slot_widgets.clear()
	for slot: String in Game.SLOTS:
		var card := UI.panel(Color(0.08, 0.07, 0.06, 0.78), 8)
		card.custom_minimum_size = Vector2(150, 0)
		_slots_box.add_child(card)
		var box := UI.vbox(3)
		card.add_child(box)
		var top_row := UI.hbox(6)
		box.add_child(top_row)
		var key := UI.label(SLOT_KEYS[slot], 14, Color(1.0, 0.8, 0.45))
		top_row.add_child(key)
		var timer := UI.label("", 14, UI.MUTED_COLOR)
		timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_row.add_child(timer)
		var ability: Ability = player.abilities.get(slot)
		var name_text := ability.display_name if ability != null else "Locked"
		var name_label := UI.label(name_text, 16, UI.TEXT_COLOR if ability != null else UI.MUTED_COLOR)
		box.add_child(name_label)
		var cost_text := ""
		if ability != null:
			cost_text = "%d chi" % roundi(ability.chi_cost) if ability.chi_cost > 0.0 else "free"
		else:
			cost_text = "unlock in skill tree"
		box.add_child(UI.label(cost_text, 12, UI.MUTED_COLOR))
		var cd_bar := UI.bar(Balance.element_color(player.element).lightened(0.2), Vector2(134, 6))
		box.add_child(cd_bar)
		if ability == null:
			card.modulate = Color(0.5, 0.5, 0.5, 0.7)
			cd_bar.value = 0.0
			continue
		ability.failed.connect(_on_ability_failed)
		_slot_widgets[slot] = {"card": card, "bar": cd_bar, "timer": timer}


func _watch(sig: Signal, progress: ProgressBar, current: float, maximum: float) -> void:
	var update := func(now: float, top: float) -> void:
		progress.max_value = top
		progress.value = now
	update.call(current, maximum)
	sig.connect(update)


func _on_hp_changed(now: float, top: float) -> void:
	_hp_text.text = "%d / %d" % [ceili(now), roundi(top)]


func _on_element_changed(element: String) -> void:
	_element_label.text = Balance.element_title(element)
	_element_label.add_theme_color_override("font_color", Balance.element_color(element).lightened(0.35))


func _on_ability_failed(_reason: String) -> void:
	_chi_bar.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(_chi_bar, "modulate", Color.WHITE, 0.3)
