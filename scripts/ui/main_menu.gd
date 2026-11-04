extends Control
## Главное меню: трава, деревья, танцующая свинка и кнопки.

signal start_requested(continue_game: bool)

const PigMeta := preload("res://scripts/art/pig_meta.gd")
const PigFrames := preload("res://scripts/art/pig_frames.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _pig: AnimatedSprite2D
var _menu_box: VBoxContainer
var _settings: PanelContainer
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var grass := AtlasTexture.new()
	grass.atlas = load("res://assets/tiles/tileset.png")
	grass.region = Rect2(32, 64, 16, 16)
	bg.texture = grass
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_decor("tree_oak_big", Control.PRESET_BOTTOM_LEFT, 6)
	_decor("tree_pine", Control.PRESET_BOTTOM_RIGHT, 6)
	_decor("house", Control.PRESET_CENTER_BOTTOM, 0)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	add_child(_menu_box)
	var title := Label.new()
	title.text = "PiggyWorld"
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color("#ffd0d9"))
	_menu_box.add_child(title)
	var sub := Label.new()
	sub.text = "Уютная ферма свинки"
	_menu_box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_menu_box.add_child(spacer)
	var cont := _button("Продолжить", func() -> void: start_requested.emit(true))
	cont.disabled = not SaveSystem.has_save()
	_button("Новая игра", func() -> void: start_requested.emit(false))
	_button("Настройки", _open_settings)
	_menu_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 36)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	_pig = AnimatedSprite2D.new()
	_pig.sprite_frames = PigFrames.build()
	_pig.centered = false
	_pig.offset = Vector2(-PigMeta.FRAME_W / 2.0, -PigMeta.GROUND_Y)
	_pig.scale = Vector2(4, 4)
	add_child(_pig)
	_pig.play("idle_down")


func _decor(tex_name: String, preset: int, margin: int) -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/objects/%s.png" % tex_name)
	add_child(tr)
	tr.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 26)
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		cb.call())
	_menu_box.add_child(b)
	return b


func _open_settings() -> void:
	_menu_box.visible = false
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_menu_box.visible = true


func _process(delta: float) -> void:
	_t += delta
	_pig.position = Vector2(size.x * 0.74, size.y * 0.62)
	# каждые ~4 с свинка радуется
	var phase := fmod(_t, 6.0)
	var want := "happy_down" if phase > 4.0 else "idle_down"
	if _pig.animation != want:
		_pig.play(want)
		if want == "happy_down":
			AudioManager.play("oink_happy", 0.05, 0.8)
