extends RefCounted
## Единая тема интерфейса: палитра, рамки, шрифт и мелкие помощники для окон.

const BG := Color("#2b1d18")
const BG_SOFT := Color("#3b2a24")
const BORDER := Color("#e8c27a")
const BORDER_DIM := Color("#8a6a3a")
const TEXT := Color("#fff3d6")
const MUTED := Color("#b89c78")
const GOLD := Color("#ffd26a")
const GOOD := Color("#9fd78a")
const BAD := Color("#e07a6a")
const VIOLET := Color("#c0a0f0")
const DIM := Color(0, 0, 0, 0.55)


static var _shared: Theme


## Одна и та же тема для всех окон: навешивается на корень окна.
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func box(bg: Color, border: Color = BORDER, margin: float = 5.0, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	return s


static func soft_box(bg: Color, border: Color, margin: float = 5.0, bw: int = 1) -> StyleBoxFlat:
	var s := box(bg, border, margin, bw)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 2
	s.shadow_offset = Vector2(1, 2)
	return s


static func build() -> Theme:
	var th := Theme.new()
	var font := load("res://assets/fonts/pixel.fnt") as Font
	if font != null:
		th.default_font = font
		th.default_font_size = 11
	th.set_stylebox("normal", "Button", soft_box(Color("#5b3f33"), BORDER_DIM, 5.0, 1))
	th.set_stylebox("hover", "Button", soft_box(Color("#74503f"), BORDER, 5.0, 1))
	th.set_stylebox("pressed", "Button", box(Color("#3b2a24"), GOLD, 5.0, 1))
	th.set_stylebox("disabled", "Button", box(Color("#33241e"), Color("#6a5a48"), 5.0, 1))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", Color("#8a7a65"))
	var panel := box(Color("#2b1d18"), BORDER, 6.0, 2)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 3
	panel.shadow_offset = Vector2(2, 3)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)
	th.set_stylebox("panel", "ProgressBar", box(Color("#1d1310"), Color("#6a5a48"), 0.0, 1))
	th.set_stylebox("fill", "ProgressBar", box(Color("#9fd78a"), Color("#9fd78a"), 0.0, 0))
	return th


static func label(text: String, color: Color = TEXT, px: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", px)
	return l


static func icon(id: String, px: int = 16) -> TextureRect:
	var t := TextureRect.new()
	t.texture = GameState.item_icon(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func icon_button(id: String, px: int = 26, tip: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.icon = GameState.item_icon(id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	if tip != "":
		b.tooltip_text = tip
	return b


static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = BORDER_DIM
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Затемнение фона и центрированное окно. Возвращает контейнер для содержимого.
static func window(host: Control, w: float, h: float, title_text: String = "") -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	panel.add_child(body)
	if title_text != "":
		var t := label(title_text, GOLD, 13)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(t)
		body.add_child(rule())
	return body


static func scroll_list(min_size: Vector2) -> Array:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = min_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return [scroll, list]


static func close_button(text: String = "Закрыть") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 22)
	return b
