extends Node2D

var view_size: Vector2 = Vector2(360, 640)
const TILE := 24.0
const ISLAND_RADIUS := Vector2(760.0, 570.0)
const PLAYER_SPEED := 112.0
const SAVE_PATH := "user://piggyworld_save.cfg"

var player_pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var move_vector: Vector2 = Vector2.ZERO
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_touch: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var move_target: Vector2 = Vector2(-9999, -9999)
var animation_time: float = 0.0
var wood: int = 0
var stone: int = 0
var berries: int = 0
var coins: int = 0
var world_objects: Array[Dictionary] = []
var inventory_label: Label
var message_label: Label
var action_button: Button
var save_timer: float = 0.0
var atlas_texture: Texture2D
var game_state: String = "loading"
var game_ui_layer: CanvasLayer
var menu_layer: CanvasLayer
var pause_button: Button

func _ready() -> void:
    _configure_pixel_view()
    atlas_texture = load("res://assets/piggyworld_atlas.svg") as Texture2D
    _load_game()
    if world_objects.is_empty():
        _generate_world()
    _build_ui()
    _show_loading()
    queue_redraw()

func _configure_pixel_view() -> void:
    get_viewport().transparent_bg = false
    get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
    view_size = get_viewport_rect().size
    animation_time += delta
    if game_state != "playing":
        queue_redraw()
        return
    var keyboard: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    move_vector = joystick_vector if joystick_vector.length() > 0.12 else keyboard
    if move_vector.length() > 0.08:
        move_vector = move_vector.normalized()
        facing = move_vector
        player_pos += move_vector * PLAYER_SPEED * delta
        move_target = Vector2(-9999, -9999)
    elif move_target.x > -9000:
        var difference: Vector2 = move_target - player_pos
        if difference.length() > 5.0:
            facing = difference.normalized()
            player_pos += facing * min(PLAYER_SPEED * delta, difference.length())
        else:
            move_target = Vector2(-9999, -9999)
    var normalized_pos: Vector2 = Vector2(player_pos.x / ISLAND_RADIUS.x, player_pos.y / ISLAND_RADIUS.y)
    if normalized_pos.length() > 0.94:
        player_pos = normalized_pos.normalized() * Vector2(ISLAND_RADIUS.x * 0.94, ISLAND_RADIUS.y * 0.94)
    save_timer += delta
    if save_timer > 20.0:
        save_timer = 0.0
        _save_game()
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if game_state != "playing":
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        _interact()
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < 145.0 and event.position.y > 135.0:
                joystick_touch = event.index
                joystick_origin = event.position
                joystick_vector = Vector2.ZERO
            else:
                var camera_offset: Vector2 = player_pos - view_size * 0.5
                move_target = event.position + camera_offset
        elif event.index == joystick_touch:
            joystick_touch = -1
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        joystick_vector = ((event.position - joystick_origin) / 38.0).limit_length(1.0)

func _generate_world() -> void:
    world_objects.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 824671
    for i in range(105):
        var p := Vector2(rng.randf_range(-690.0, 690.0), rng.randf_range(-500.0, 500.0))
        if Vector2(p.x / ISLAND_RADIUS.x, p.y / ISLAND_RADIUS.y).length() > 0.83:
            continue
        if p.length() < 115.0:
            continue
        var kind: String = "tree"
        var roll: float = rng.randf()
        if roll < 0.22:
            kind = "rock"
        elif roll < 0.34:
            kind = "bush"
        world_objects.append({"kind": kind, "pos": p, "variant": rng.randi_range(0, 3)})
    world_objects.append({"kind": "house", "pos": Vector2(-85, -55), "variant": 0})
    world_objects.append({"kind": "house", "pos": Vector2(155, 105), "variant": 1})
    _save_game()

func _draw() -> void:
    if game_state != "playing" and game_state != "paused":
        _draw_menu_background()
        return
    var camera_offset: Vector2 = player_pos - view_size * 0.5
    draw_rect(Rect2(Vector2.ZERO, view_size), Color("#397fa0"))
    _draw_water(camera_offset)
    var min_x: int = floori(camera_offset.x / TILE) - 1
    var max_x: int = ceili((camera_offset.x + view_size.x) / TILE) + 1
    var min_y: int = floori(camera_offset.y / TILE) - 1
    var max_y: int = ceili((camera_offset.y + view_size.y) / TILE) + 1
    for ty in range(min_y, max_y):
        for tx in range(min_x, max_x):
            var world: Vector2 = Vector2(tx * TILE, ty * TILE)
            var center: Vector2 = world + Vector2(TILE * 0.5, TILE * 0.5)
            var normalized: Vector2 = Vector2(center.x / ISLAND_RADIUS.x, center.y / ISLAND_RADIUS.y)
            var distance: float = normalized.length()
            var screen: Vector2 = world - camera_offset
            if distance <= 1.035:
                var color: Color
                var variation: int = absi(tx * 92821 + ty * 68917) % 5
                if distance > 0.965:
                    color = Color("#d8bd79")
                else:
                    var greens: Array[Color] = [Color("#65ad55"), Color("#6db65b"), Color("#5fa44e"), Color("#74ba60"), Color("#68ae55")]
                    color = greens[variation]
                if atlas_texture != null:
                    var source_x: int = 32 if distance > 0.965 else (240 if variation == 4 else (16 if variation == 1 else 0))
                    draw_texture_rect_region(atlas_texture, Rect2(screen, Vector2(TILE + 1, TILE + 1)), Rect2(Vector2(source_x, 0), Vector2(16, 16)))
                else:
                    draw_rect(Rect2(screen, Vector2(TILE + 1, TILE + 1)), color)
                if distance < 0.95:
                    _draw_ground_detail(screen, tx, ty)
    _draw_path(camera_offset)
    _draw_farm_patch(camera_offset)
    _draw_fence(camera_offset)
    for i in range(world_objects.size()):
        var item: Dictionary = world_objects[i]
        var screen_pos: Vector2 = item["pos"] - camera_offset
        if screen_pos.x < -45 or screen_pos.x > view_size.x + 45 or screen_pos.y < -60 or screen_pos.y > view_size.y + 60:
            continue
        match String(item["kind"]):
            "tree":
                _draw_tree(screen_pos, int(item["variant"]))
            "rock":
                _draw_rock(screen_pos, int(item["variant"]))
            "bush":
                _draw_bush(screen_pos)
            "house":
                _draw_house(screen_pos, int(item["variant"]))
    _draw_pig(view_size * 0.5)
    _draw_joystick()

func _draw_water(camera_offset: Vector2) -> void:
    var start_x: int = floori(camera_offset.x * 0.12 / 32.0) - 1
    var end_x: int = ceili((camera_offset.x * 0.12 + view_size.x) / 32.0) + 1
    var start_y: int = floori(camera_offset.y * 0.12 / 32.0) - 1
    var end_y: int = ceili((camera_offset.y * 0.12 + view_size.y) / 32.0) + 1
    for y in range(start_y, end_y):
        for x in range(start_x, end_x):
            var p: Vector2 = Vector2(x * 32.0, y * 32.0)
            var n: int = absi(x * 73129 + y * 19391) % 4
            var blues: Array[Color] = [Color("#397fa0"), Color("#3c85a5"), Color("#36799a"), Color("#4289a8")]
            if atlas_texture != null:
                draw_texture_rect_region(atlas_texture, Rect2(p - camera_offset * 0.12, Vector2(32, 32)), Rect2(Vector2(64, 0), Vector2(16, 16)))
            else:
                draw_rect(Rect2(p - camera_offset * 0.12, Vector2(32, 32)), blues[n])
            if n == 1:
                draw_rect(Rect2(p + Vector2(9, 12) - camera_offset * 0.12, Vector2(7, 2)), Color("#72b5c3"))

func _draw_ground_detail(screen: Vector2, tx: int, ty: int) -> void:
    var seed_value: int = absi(tx * 19349663 + ty * 83492791)
    if seed_value % 7 == 0:
        draw_rect(Rect2(screen + Vector2(5 + seed_value % 11, 6 + seed_value % 9), Vector2(3, 3)), Color("#a2ce72"))
    elif seed_value % 13 == 0:
        draw_rect(Rect2(screen + Vector2(8, 15), Vector2(2, 5)), Color("#e8d78a"))
        draw_rect(Rect2(screen + Vector2(6, 16), Vector2(6, 2)), Color("#e8d78a"))

func _draw_path(camera_offset: Vector2) -> void:
    for x in range(-34, 35):
        var world_x: float = float(x) * 24.0
        var world_y: float = sin(world_x / 155.0) * 82.0 + 58.0
        var screen := Vector2(world_x, world_y) - camera_offset
        if screen.x > -24 and screen.x < view_size.x + 24 and screen.y > -24 and screen.y < view_size.y + 24:
            if atlas_texture != null:
                draw_texture_rect_region(atlas_texture, Rect2(screen, Vector2(24, 24)), Rect2(Vector2(48, 0), Vector2(16, 16)))
            else:
                draw_rect(Rect2(screen, Vector2(24, 24)), Color("#bd9861"))

func _draw_tree(p: Vector2, variant: int) -> void:
    if atlas_texture != null:
        var source := Rect2(Vector2(48, 40), Vector2(48, 64)) if variant % 3 == 0 else Rect2(Vector2(0, 40), Vector2(48, 64))
        var scale := 1.0 if variant % 2 == 0 else 0.88
        var size := Vector2(72, 96) * scale
        draw_texture_rect_region(atlas_texture, Rect2(p + Vector2(-size.x * 0.5, -size.y + 10), size), source)
        return
    draw_rect(Rect2(p + Vector2(-12, -28), Vector2(24, 34)), Color("#397e49"))

func _draw_rock(p: Vector2, variant: int) -> void:
    if atlas_texture != null:
        var size := Vector2(36, 36) if variant % 2 == 0 else Vector2(30, 30)
        draw_texture_rect_region(atlas_texture, Rect2(p + Vector2(-size.x * 0.5, -size.y + 5), size), Rect2(Vector2(128, 40), Vector2(24, 24)))
        return
    draw_rect(Rect2(p + Vector2(-14, -12), Vector2(28, 20)), Color("#91a69a"))

func _draw_bush(p: Vector2) -> void:
    if atlas_texture != null:
        draw_texture_rect_region(atlas_texture, Rect2(p + Vector2(-24, -28), Vector2(48, 42)), Rect2(Vector2(96, 40), Vector2(32, 28)))
        return
    draw_rect(Rect2(p + Vector2(-12, -10), Vector2(24, 18)), Color("#4a9b50"))

func _draw_house(p: Vector2, variant: int) -> void:
    if atlas_texture != null:
        draw_ellipse_shadow(p + Vector2(0, 27), Vector2(39, 7))
        var source := Rect2(Vector2(64, 112), Vector2(64, 64)) if variant % 2 == 1 else Rect2(Vector2(0, 112), Vector2(64, 64))
        draw_texture_rect_region(atlas_texture, Rect2(p + Vector2(-48, -67), Vector2(96, 96)), source)
        return
    draw_rect(Rect2(p + Vector2(-28, -19), Vector2(56, 42)), Color("#e7c58c"))

func draw_ellipse_shadow(center: Vector2, size: Vector2) -> void:
    draw_set_transform(center, 0.0, Vector2(1.0, size.y / size.x))
    draw_circle(Vector2.ZERO, size.x, Color(0.12, 0.2, 0.14, 0.22))
    draw_set_transform(Vector2.ZERO)

func _draw_pig(center: Vector2) -> void:
    if atlas_texture != null:
        var moving := move_vector.length() > 0.08 or move_target.x > -9000
        var frame_x := 176.0 if moving and int(animation_time * 7.0) % 2 == 1 else 144.0
        var bob := sin(animation_time * 12.0) * 1.5 if moving else sin(animation_time * 2.2) * 0.7
        var destination := Rect2(center + Vector2(-27, -28 + bob), Vector2(54, 54))
        draw_texture_rect_region(atlas_texture, destination, Rect2(Vector2(frame_x, 112), Vector2(32, 32)))
        return
    draw_rect(Rect2(center + Vector2(-14, -10), Vector2(28, 24)), Color("#e58d9b"))

func _draw_farm_patch(camera_offset: Vector2) -> void:
    var origin := Vector2(-18, 132) - camera_offset
    draw_rect(Rect2(origin + Vector2(-10, -10), Vector2(116, 88)), Color("#d9bd7d"))
    for row in range(3):
        for col in range(4):
            var cell := origin + Vector2(float(col) * 25.0, float(row) * 24.0)
            if atlas_texture != null:
                draw_texture_rect_region(atlas_texture, Rect2(cell, Vector2(24, 24)), Rect2(Vector2(80, 0), Vector2(16, 16)))
                var crop_x := 96.0 if (row + col) % 2 == 0 else 112.0
                draw_texture_rect_region(atlas_texture, Rect2(cell + Vector2(2, -8), Vector2(20, 22)), Rect2(Vector2(crop_x, 0), Vector2(16, 16)))
            else:
                draw_rect(Rect2(cell, Vector2(20, 17)), Color("#96613f"))

func _draw_fence(camera_offset: Vector2) -> void:
    for i in range(15):
        var p := Vector2(-270.0 + float(i) * 32.0, -178.0) - camera_offset
        if p.x < -36 or p.x > view_size.x + 36:
            continue
        if atlas_texture != null:
            draw_texture_rect_region(atlas_texture, Rect2(p, Vector2(48, 24)), Rect2(Vector2(208, 112), Vector2(32, 16)))
        else:
            draw_rect(Rect2(p, Vector2(32, 5)), Color("#9a6945"))

func _draw_joystick() -> void:
    var base: Vector2 = Vector2(68, view_size.y - 78)
    draw_circle(base, 31, Color(0.08, 0.16, 0.17, 0.48))
    draw_circle(base, 25, Color(0.78, 0.9, 0.75, 0.3))
    var knob: Vector2 = base + joystick_vector * 15.0
    draw_circle(knob, 10, Color("#f2e7c7"))

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    game_ui_layer = layer
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(10, 10)
    panel.add_theme_stylebox_override("panel", _style(Color("#263f39"), 8))
    layer.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 1)
    panel.add_child(column)
    var title := Label.new()
    title.text = "PIGGY ISLAND"
    title.add_theme_color_override("font_color", Color("#f6e8b8"))
    title.add_theme_font_size_override("font_size", 15)
    column.add_child(title)
    inventory_label = Label.new()
    inventory_label.add_theme_color_override("font_color", Color.WHITE)
    inventory_label.add_theme_font_size_override("font_size", 12)
    column.add_child(inventory_label)
    message_label = Label.new()
    message_label.text = "Собирай ресурсы и обустрой остров!"
    message_label.position = Vector2(10, 82)
    message_label.add_theme_color_override("font_color", Color("#fff3c8"))
    message_label.add_theme_font_size_override("font_size", 12)
    layer.add_child(message_label)
    action_button = _make_button("СОБРАТЬ", Vector2(view_size.x - 116, view_size.y - 76), Vector2(106, 34))
    action_button.pressed.connect(_interact)
    layer.add_child(action_button)
    var build_button := _make_button("ПОСТРОИТЬ", Vector2(view_size.x - 116, view_size.y - 119), Vector2(106, 34))
    build_button.pressed.connect(_build_small_house)
    layer.add_child(build_button)
    var help := Label.new()
    help.text = "WASD / джойстик • E — действие"
    help.position = Vector2(10, view_size.y - 22)
    help.add_theme_font_size_override("font_size", 8)
    help.add_theme_color_override("font_color", Color("#f8f1d9"))
    layer.add_child(help)
    pause_button = _make_button("Ⅱ", Vector2(view_size.x - 46, 10), Vector2(36, 34))
    pause_button.pressed.connect(_toggle_pause)
    layer.add_child(pause_button)
    game_ui_layer.visible = false
    _refresh_inventory()

func _make_button(text_value: String, pos: Vector2, button_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = button_size
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", Color("#fff4d6"))
    button.add_theme_stylebox_override("normal", _style(Color("#527b55"), 7))
    button.add_theme_stylebox_override("hover", _style(Color("#68965e"), 7))
    button.add_theme_stylebox_override("pressed", _style(Color("#365c45"), 7))
    return button

func _style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    style.border_width_bottom = 2
    style.border_color = color.darkened(0.28)
    return style

func _interact() -> void:
    var nearest_index: int = -1
    var nearest_distance: float = 58.0
    for i in range(world_objects.size()):
        var item: Dictionary = world_objects[i]
        var kind: String = String(item["kind"])
        if kind == "house":
            continue
        var distance: float = player_pos.distance_to(item["pos"])
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = i
    if nearest_index == -1:
        _show_message("Подойди ближе к дереву, камню или кусту")
        return
    var target: Dictionary = world_objects[nearest_index]
    match String(target["kind"]):
        "tree":
            wood += 3
            _show_message("+3 дерева")
        "rock":
            stone += 2
            _show_message("+2 камня")
        "bush":
            berries += 2
            _show_message("+2 ягоды")
    world_objects.remove_at(nearest_index)
    _refresh_inventory()
    _save_game()
    queue_redraw()

func _build_small_house() -> void:
    if wood < 12 or stone < 5:
        _show_message("Нужно 12 дерева и 5 камня")
        return
    wood -= 12
    stone -= 5
    world_objects.append({"kind": "house", "pos": player_pos + Vector2(42, 8), "variant": 1})
    _refresh_inventory()
    _show_message("Новый дом построен!")
    _save_game()
    queue_redraw()

func _show_message(value: String) -> void:
    if is_instance_valid(message_label):
        message_label.text = value

func _refresh_inventory() -> void:
    if is_instance_valid(inventory_label):
        inventory_label.text = "🪵 %d   камень %d\n🍓 %d   🪙 %d" % [wood, stone, berries, coins]

func _save_game() -> void:
    var config := ConfigFile.new()
    config.set_value("player", "position", player_pos)
    config.set_value("inventory", "wood", wood)
    config.set_value("inventory", "stone", stone)
    config.set_value("inventory", "berries", berries)
    config.set_value("inventory", "coins", coins)
    config.set_value("world", "objects", world_objects)
    config.save(SAVE_PATH)

func _load_game() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    player_pos = config.get_value("player", "position", Vector2.ZERO)
    wood = int(config.get_value("inventory", "wood", 0))
    stone = int(config.get_value("inventory", "stone", 0))
    berries = int(config.get_value("inventory", "berries", 0))
    coins = int(config.get_value("inventory", "coins", 0))
    var saved_objects = config.get_value("world", "objects", [])
    if saved_objects is Array:
        world_objects.assign(saved_objects)

func _draw_menu_background() -> void:
    draw_rect(Rect2(Vector2.ZERO, view_size), Color("#315f70"))
    for i in range(8):
        var y: float = float(i) * 42.0 + fmod(animation_time * 5.0, 42.0)
        draw_line(Vector2(0, y), Vector2(view_size.x, y + 12.0), Color(0.65, 0.86, 0.86, 0.10), 2.0)
    var center: Vector2 = Vector2(view_size.x * 0.5, view_size.y * 0.54)
    var sand := PackedVector2Array()
    var grass := PackedVector2Array()
    for i in range(48):
        var angle: float = TAU * float(i) / 48.0
        sand.append(center + Vector2(cos(angle) * view_size.x * 0.48, sin(angle) * view_size.y * 0.235))
        grass.append(center + Vector2(cos(angle) * view_size.x * 0.445, sin(angle) * view_size.y * 0.205))
    draw_colored_polygon(sand, Color("#d7b875"))
    draw_colored_polygon(grass, Color("#70ad59"))
    for i in range(24):
        var px: float = center.x + sin(float(i) * 9.7) * view_size.x * 0.34
        var py: float = center.y + cos(float(i) * 4.3) * view_size.y * 0.13
        draw_circle(Vector2(px, py), 2.0, Color("#91c875"))
    _draw_tree(center + Vector2(-view_size.x * 0.27, -view_size.y * 0.07), 0)
    _draw_tree(center + Vector2(view_size.x * 0.27, view_size.y * 0.04), 1)
    _draw_house(center + Vector2(view_size.x * 0.12, -view_size.y * 0.075), 0)
    _draw_pig(center + Vector2(-view_size.x * 0.04, view_size.y * 0.09))

func _create_menu_page(title_text: String, subtitle_text: String) -> VBoxContainer:
    _clear_menu()
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(root)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.08, 0.15, 0.16, 0.48)
    root.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(minf(view_size.x - 34.0, 330.0), 0)
    panel.add_theme_stylebox_override("panel", _style(Color("#294b40"), 16))
    center.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    column.add_theme_constant_override("margin_top", 12)
    panel.add_child(column)
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("#ffe7a8"))
    title.add_theme_font_size_override("font_size", 30)
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = subtitle_text
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#e1e9c9"))
    subtitle.add_theme_font_size_override("font_size", 13)
    column.add_child(subtitle)
    var spacer := Control.new()
    spacer.custom_minimum_size.y = 5
    column.add_child(spacer)
    return column

func _add_menu_button(column: VBoxContainer, caption: String, action: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(250, 48)
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color("#fff2d1"))
    button.add_theme_stylebox_override("normal", _style(Color("#628d58"), 10))
    button.add_theme_stylebox_override("hover", _style(Color("#79a966"), 10))
    button.add_theme_stylebox_override("pressed", _style(Color("#456d4c"), 10))
    button.pressed.connect(action)
    column.add_child(button)

func _clear_menu() -> void:
    if is_instance_valid(menu_layer):
        menu_layer.queue_free()
    menu_layer = null

func _show_loading() -> void:
    game_state = "loading"
    var column := _create_menu_page("PIGGYWORLD", "Твой маленький уютный остров")
    var loading := Label.new()
    loading.text = "Подготавливаем ферму..."
    loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading.add_theme_color_override("font_color", Color("#fff2d1"))
    column.add_child(loading)
    var progress := ProgressBar.new()
    progress.custom_minimum_size = Vector2(245, 18)
    progress.show_percentage = false
    column.add_child(progress)
    var tween := create_tween()
    tween.tween_property(progress, "value", 100.0, 1.25)
    get_tree().create_timer(1.35).timeout.connect(_show_main_menu)

func _show_main_menu() -> void:
    game_state = "menu"
    if is_instance_valid(game_ui_layer):
        game_ui_layer.visible = false
    var column := _create_menu_page("PIGGYWORLD", "Уютная жизнь на зелёном острове")
    _add_menu_button(column, "ПРОДОЛЖИТЬ", _start_game)
    _add_menu_button(column, "НОВАЯ ИГРА", _new_game)
    _add_menu_button(column, "НАСТРОЙКИ", _show_settings)
    var footer := Label.new()
    footer.text = "Собирай ресурсы • строй • исследуй"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_color_override("font_color", Color("#c8d9b9"))
    footer.add_theme_font_size_override("font_size", 10)
    column.add_child(footer)
    queue_redraw()

func _show_settings() -> void:
    game_state = "menu"
    var column := _create_menu_page("НАСТРОЙКИ", "Как играть")
    var info := Label.new()
    info.text = "Джойстик слева — движение\nНажми на землю — пройти к месту\nКнопка «Собрать» — ресурсы\nКнопка «Построить» — новый дом"
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_color_override("font_color", Color("#f5edcf"))
    info.add_theme_font_size_override("font_size", 14)
    column.add_child(info)
    _add_menu_button(column, "НАЗАД", _show_main_menu)

func _show_pause_menu() -> void:
    var column := _create_menu_page("ПАУЗА", "Остров подождёт")
    _add_menu_button(column, "ПРОДОЛЖИТЬ", _start_game)
    _add_menu_button(column, "СОХРАНИТЬ И В МЕНЮ", _return_to_menu)

func _start_game() -> void:
    game_state = "playing"
    _clear_menu()
    if is_instance_valid(game_ui_layer):
        game_ui_layer.visible = true
    queue_redraw()

func _new_game() -> void:
    player_pos = Vector2.ZERO
    wood = 0
    stone = 0
    berries = 0
    coins = 0
    _generate_world()
    _refresh_inventory()
    _start_game()

func _return_to_menu() -> void:
    _save_game()
    _show_main_menu()

func _toggle_pause() -> void:
    if game_state == "playing":
        game_state = "paused"
        if is_instance_valid(game_ui_layer):
            game_ui_layer.visible = false
        _show_pause_menu()
    elif game_state == "paused":
        _start_game()
