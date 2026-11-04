extends RefCounted
## Единая тема интерфейса: пиксельная рамка, растровый шрифт, без скруглений.

const COL_BG := Color("#3b2a24")
const COL_BORDER := Color("#e8c27a")
const COL_TEXT := Color("#fff3d6")


static func box(bg: Color, border: Color = COL_BORDER, margin: float = 5.0, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	return s


static func build() -> Theme:
	var th := Theme.new()
	var font := load("res://assets/fonts/pixel.fnt") as Font
	if font != null:
		th.default_font = font
		th.default_font_size = 11
	th.set_stylebox("normal", "Button", box(Color("#5b3f33")))
	th.set_stylebox("hover", "Button", box(Color("#74503f")))
	th.set_stylebox("pressed", "Button", box(Color("#3b2a24"), COL_TEXT))
	th.set_stylebox("disabled", "Button", box(Color("#3b2a24"), Color("#7a6a55")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", COL_BORDER)
	th.set_color("font_disabled_color", "Button", Color("#8a7a65"))
	var panel := box(Color(0.2, 0.14, 0.12, 0.92), COL_BORDER, 6.0)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	th.set_color("font_color", "Label", COL_TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)
	return th
