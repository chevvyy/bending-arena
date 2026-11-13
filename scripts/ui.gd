class_name UI
extends RefCounted
## Helpers for building the menus and HUD in code, so every screen shares the
## same look without a theme file.

const PANEL_COLOR := Color(0.08, 0.07, 0.06, 0.82)
const TEXT_COLOR := Color(0.96, 0.93, 0.86)
const MUTED_COLOR := Color(0.7, 0.66, 0.6)


## Pins a control to a point of its parent (anchor 0..1 on each axis) and lets
## it grow away from that point as its contents need.
static func place(node: Control, anchor: Vector2, offset: Vector2,
		grow_h := Control.GROW_DIRECTION_BOTH, grow_v := Control.GROW_DIRECTION_BOTH) -> void:
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = offset.x
	node.offset_right = offset.x
	node.offset_top = offset.y
	node.offset_bottom = offset.y
	node.grow_horizontal = grow_h
	node.grow_vertical = grow_v


static func full_rect(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func label(text: String, size := 18, color := TEXT_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6 if size >= 20 else 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func bar(color: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	b.value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(3)
	back.set_border_width_all(1)
	back.border_color = Color(1, 1, 1, 0.15)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func panel(color := PANEL_COLOR, padding := 12) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(padding)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, on_press: Callable, accent := Color(0.85, 0.55, 0.25),
		min_size := Vector2(240, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		match state:
			"normal":
				style.bg_color = Color(0.16, 0.14, 0.12, 0.92)
				style.set_border_width_all(2)
				style.border_color = accent.darkened(0.3)
			"hover":
				style.bg_color = accent.darkened(0.45)
				style.set_border_width_all(2)
				style.border_color = accent
			"pressed":
				style.bg_color = accent.darkened(0.2)
			"disabled":
				style.bg_color = Color(0.12, 0.12, 0.12, 0.7)
			"focus":
				style.draw_center = false
				style.set_border_width_all(2)
				style.border_color = Color(1, 1, 1, 0.6)
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(on_press)
	return b


static func vbox(separation := 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func hbox(separation := 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box
