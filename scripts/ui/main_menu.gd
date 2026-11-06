extends Control
## Главное меню: поле, деревья, дом, танцующая свинка и кнопки.

signal start_requested(continue_game: bool, hardcore: bool)

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const PigMeta := preload("res://scripts/art/pig_meta.gd")
const PigFrames := preload("res://scripts/art/pig_frames.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _pig: AnimatedSprite2D
var _menu_box: VBoxContainer
var _settings: PanelContainer
var _settings_layer: CenterContainer
var _t: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	theme = UiTheme.shared()
	_build_background()
	_build_title()
	_build_buttons()
	_build_pig()
	_build_footer()
	_build_settings()


func _build_background() -> void:
	var bg := TextureRect.new()
	var grass := AtlasTexture.new()
	grass.atlas = load("res://assets/tiles/tileset.png")
	grass.region = Rect2(32, 64, 16, 16)
	bg.texture = grass
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# затемнение сверху и снизу, чтобы текст читался
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.03, 0.02, 0.65))
	g.set_color(1, Color(0.05, 0.03, 0.02, 0.55))
	g.add_point(0.45, Color(0.05, 0.03, 0.02, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	var shade := TextureRect.new()
	shade.texture = tex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_decor("tree_oak_big", Vector2(6, 112), 3.0)
	_decor("tree_pine", Vector2(404, 92), 3.0)
	_decor("tree_oak", Vector2(54, 188), 2.0)
	_decor("bush_berries", Vector2(390, 198), 2.0)
	_decor("house", Vector2(204, 118), 2.5)


func _decor(tex_name: String, pos: Vector2, scale_k: float) -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/objects/%s.png" % tex_name)
	tr.position = pos
	tr.scale = Vector2(scale_k, scale_k)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _build_title() -> void:
	var title := UiTheme.label("PiggyWorld", Color("#ffd0d9"), 34)
	title.position = Vector2(26, 20)
	title.add_theme_color_override("font_shadow_color", Color(0.15, 0.05, 0.08, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)
	var sub := UiTheme.label("уютная ферма свинки", UiTheme.MUTED, 11)
	sub.position = Vector2(31, 66)
	add_child(sub)


func _build_buttons() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(26, 84)
	panel.custom_minimum_size = Vector2(158, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.13, 0.08, 0.07, 0.85), UiTheme.BORDER, 7.0, 2))
	add_child(panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 5)
	panel.add_child(_menu_box)

	var cont := _button("Продолжить", func() -> void: start_requested.emit(true, false))
	cont.disabled = not SaveSystem.has_save()
	_button("Новая игра", func() -> void: start_requested.emit(false, false))
	_button("Хардкор", func() -> void: start_requested.emit(false, true))
	_button("Настройки", _open_settings)


func _build_pig() -> void:
	_pig = AnimatedSprite2D.new()
	_pig.sprite_frames = PigFrames.build()
	_pig.centered = false
	_pig.offset = Vector2(-PigMeta.FRAME_W / 2.0, -PigMeta.GROUND_Y)
	_pig.scale = Vector2(2.8, 2.8)
	_pig.position = Vector2(252, 248)
	add_child(_pig)
	_pig.play("idle_down")


func _build_footer() -> void:
	var strip := ColorRect.new()
	strip.color = Color(0.06, 0.04, 0.03, 0.5)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -17
	strip.offset_bottom = 0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var hint := UiTheme.label("WASD — движение, пробел — действие, тач — на телефоне", UiTheme.MUTED, 9)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	add_child(hint)
	var save_info := UiTheme.label(_save_text(), UiTheme.MUTED, 9)
	save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	save_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	save_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(save_info)


func _save_text() -> String:
	if not SaveSystem.has_save():
		return "новое хозяйство"
	return "есть сохранение — нажми «Продолжить»"


func _build_settings() -> void:
	_settings_layer = CenterContainer.new()
	_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.visible = false
	add_child(_settings_layer)
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	_settings_layer.add_child(_settings)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(144, 24)
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		cb.call())
	_menu_box.add_child(b)
	return b


func _open_settings() -> void:
	_menu_box.get_parent().visible = false
	_settings_layer.visible = true


func _close_settings() -> void:
	_settings_layer.visible = false
	_menu_box.get_parent().visible = true


func _process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t, 6.0)
	var want := "happy_down" if phase > 4.0 else "idle_down"
	if _pig.animation != want:
		_pig.play(want)
		if want == "happy_down":
			AudioManager.play("oink_happy", 0.05, 0.8)
