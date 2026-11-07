extends RefCounted
## Сборка текстуры этажа подземелья: тайлы 0x72 DungeonTileset II (CC0),
## биомные оттенки, тени, декор и печати-головоломки.
## Генератор отвечает только за раскладку, этот модуль — за картинку.

const TILE := 16
const WALL := 0
const WATER := 2
const CRYSTAL := 3
const MUSHROOM := 4
const ASH := 5

const SEAL_COLORS: Array[Color] = [Color("#f2d06a"), Color("#7fd0ea"), Color("#e8806a")]


static func build_texture(data: Dictionary, lit_seals: Array) -> Texture2D:
	var w: int = int(data["width"])
	var h: int = int(data["height"])
	var img := Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color("#17151c"))

	var floor_images: Array[Image] = []
	for i in range(1, 5):
		var floor_texture := load("res://assets/dungeon/0x72/floor_%d.png" % i) as Texture2D
		if floor_texture != null:
			floor_images.append(_texture_image_rgba(floor_texture))

	var wall_images: Dictionary = {}
	for wall_name in ["mid", "top_mid", "top_left", "top_right"]:
		var wall_texture := load("res://assets/dungeon/0x72/wall_%s.png" % wall_name) as Texture2D
		if wall_texture != null:
			wall_images[wall_name] = _texture_image_rgba(wall_texture)

	if floor_images.is_empty() or not wall_images.has("mid"):
		push_error("DungeonRenderer: dungeon tileset assets are missing")
		return ImageTexture.create_from_image(img)

	var grid: Array = data["grid"]
	var biome: Dictionary = data["biome"]
	var accent: Color = biome["accent"]
	var wall_tint: Color = biome["wall"]
	var floor_tint: Color = biome["floor"]
	var r := RandomNumberGenerator.new()
	r.seed = int(data["seed"])

	for y in range(h):
		for x in range(w):
			var tile := int(grid[y][x])
			var destination := Vector2i(x * TILE, y * TILE)
			if tile == WALL:
				img.blit_rect(wall_images["mid"], Rect2i(0, 0, TILE, TILE), destination)
				_tint_rect(img, destination, TILE, TILE, Color(0, 0, 0), 0.14)
				_tint_rect(img, destination, TILE, TILE, wall_tint, 0.50)
				var below_walkable := y + 1 < h and int(grid[y + 1][x]) != WALL
				if below_walkable:
					var left_walkable := x > 0 and int(grid[y][x - 1]) != WALL
					var right_walkable := x + 1 < w and int(grid[y][x + 1]) != WALL
					var cap_key := "top_mid"
					if left_walkable:
						cap_key = "top_left"
					elif right_walkable:
						cap_key = "top_right"
					img.blit_rect(wall_images[cap_key], Rect2i(0, 12, TILE, 4), destination + Vector2i(0, 12))
				continue

			var floor_image: Image = floor_images[r.randi_range(0, floor_images.size() - 1)]
			img.blit_rect(floor_image, Rect2i(0, 0, TILE, TILE), destination)
			_tint_rect(img, destination, TILE, TILE, floor_tint, 0.34)
			_tint_rect(img, destination, TILE, TILE, Color(1, 1, 1), 0.07)
			if y > 0 and int(grid[y - 1][x]) == WALL:
				for py in range(3):
					_tint_rect(img, destination + Vector2i(0, py), TILE, 1, Color(0, 0, 0), 0.34 - py * 0.08)
			match tile:
				WATER:
					_draw_puddle(img, destination, r)
				CRYSTAL:
					_draw_crystal(img, destination, r, accent)
				MUSHROOM:
					_draw_mushroom(img, destination, r)
				ASH:
					_draw_ash(img, destination, r)

	_draw_entrance_and_exit(img, data)
	_draw_columns_and_crates(img, data)
	_draw_wall_props(img, data)
	_draw_seals(img, data, lit_seals, accent)
	return ImageTexture.create_from_image(img)


static func _draw_entrance_and_exit(img: Image, data: Dictionary) -> void:
	var ladder := load("res://assets/dungeon/0x72/floor_ladder.png") as Texture2D
	var stairs := load("res://assets/dungeon/0x72/floor_stairs.png") as Texture2D
	if ladder != null:
		var start_cell: Vector2i = data["start"]
		img.blit_rect(_texture_image_rgba(ladder), Rect2i(0, 0, TILE, TILE), start_cell * TILE)
	if stairs != null:
		var exit_cell: Vector2i = data["exit"]
		img.blit_rect(_texture_image_rgba(stairs), Rect2i(0, 0, TILE, TILE), exit_cell * TILE)


static func _draw_columns_and_crates(img: Image, data: Dictionary) -> void:
	var column_texture := load("res://assets/dungeon/0x72/column.png") as Texture2D
	var crate_texture := load("res://assets/dungeon/0x72/crate.png") as Texture2D
	if column_texture != null:
		var column_image := _texture_image_rgba(column_texture)
		for room in data["rooms"]:
			if str(room["type"]) != "boss":
				continue
			var room_rect: Rect2i = room["rect"]
			for cell in [
				Vector2i(room_rect.position.x + 1, room_rect.position.y + 2),
				Vector2i(room_rect.end.x - 2, room_rect.position.y + 2)
			]:
				var column_pos := Vector2i(cell.x * TILE, (cell.y + 1) * TILE - 48)
				if column_pos.y >= 0 and column_pos.y + 48 <= img.get_height():
					img.blit_rect(column_image, Rect2i(0, 0, 16, 48), column_pos)
	if crate_texture != null:
		var crate_image := _texture_image_rgba(crate_texture)
		for room in data["rooms"]:
			if str(room["type"]) != "treasure":
				continue
			var room_rect: Rect2i = room["rect"]
			var crate_cell := Vector2i(room_rect.position.x + 1, room_rect.position.y + 1)
			var crate_pos := Vector2i(crate_cell.x * TILE, crate_cell.y * TILE - 8)
			if crate_pos.y >= 0 and crate_pos.y + 24 <= img.get_height():
				img.blit_rect(crate_image, Rect2i(0, 0, 16, 24), crate_pos)


## Печати: три руны на полу, плюс подсказка на стене стартовой комнаты.


## Факелы, знамёна и мелкий декор: атмосфера и ориентиры в комнатах.
static func _draw_wall_props(img: Image, data: Dictionary) -> void:
	var atlas := load("res://assets/dungeon/0x72/atlas_walls_high-16x32.png") as Texture2D
	if atlas == null:
		return
	var atlas_img := _texture_image_rgba(atlas)
	var torch := _slice(atlas_img, Rect2i(13 * 16, 0, 16, 32))
	var banner_cols := [17, 18, 19, 20]
	var skull_tex := load("res://assets/dungeon/0x72/skull.png") as Texture2D
	var skull := _texture_image_rgba(skull_tex) if skull_tex != null else null
	var r := RandomNumberGenerator.new()
	r.seed = int(data["seed"]) + 77
	var grid: Array = data["grid"]
	var rooms: Array = data["rooms"]
	for idx in range(rooms.size()):
		var room: Dictionary = rooms[idx]
		var rect: Rect2i = room["rect"]
		var kind := str(room["type"])
		# факел на стене сверху комнаты
		var torch_cell := Vector2i(rect.position.x + 2, rect.position.y - 1)
		if kind == "boss":
			torch_cell = Vector2i(rect.get_center().x, rect.position.y - 1)
		if _is_wall(grid, torch_cell):
			img.blit_rect(torch, Rect2i(0, 0, 16, 32), Vector2i(torch_cell.x * 16, torch_cell.y * 16 - 16))
		# знамя в каждой третьей комнате
		if idx % 3 == 1:
			var banner_cell := Vector2i(rect.end.x - 3, rect.position.y - 1)
			if _is_wall(grid, banner_cell):
				var banner := _slice(atlas_img, Rect2i(banner_cols[idx % banner_cols.size()] * 16, 32, 16, 32))
				img.blit_rect(banner, Rect2i(0, 0, 16, 32), Vector2i(banner_cell.x * 16, banner_cell.y * 16 - 16))
		# черепа и кости у стен
		if skull != null and r.randf() < 0.5:
			var spot := Vector2i(rect.position.x + r.randi_range(1, maxi(1, rect.size.x - 2)), rect.end.y - 1)
			if not _is_wall(grid, spot):
				img.blit_rect(skull, Rect2i(0, 0, 16, 16), spot * 16)


static func _slice(src: Image, rect: Rect2i) -> Image:
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, rect, Vector2i.ZERO)
	return out


static func _is_wall(grid: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
		return false
	return int(grid[cell.y][cell.x]) == WALL

static func _draw_seals(img: Image, data: Dictionary, lit: Array, accent: Color) -> void:
	var seals: Array = data.get("seals", [])
	if seals.is_empty():
		return
	var order: Array = data.get("seal_order", [0, 1, 2])
	for i in range(seals.size()):
		var cell: Vector2i = seals[i]
		var base := Vector2i(cell.x * TILE, cell.y * TILE)
		var color: Color = SEAL_COLORS[i % SEAL_COLORS.size()]
		var is_lit := lit.has(i)
		_draw_rune(img, base, color, is_lit)
	# подсказка: три точки нужного порядка на стене над лестницей входа
	var start_cell: Vector2i = data["start"]
	var hint_y := start_cell.y - 1
	for step in range(order.size()):
		var color: Color = SEAL_COLORS[int(order[step]) % SEAL_COLORS.size()]
		var px := start_cell.x * TILE - 8 + step * 6
		var py := hint_y * TILE + 10
		for dy in range(3):
			for dx in range(3):
				_set_safe(img, px + dx, py + dy, color.darkened(0.15) if dy == 2 else color)


static func _draw_rune(img: Image, base: Vector2i, color: Color, lit: bool) -> void:
	var cx := base.x + 8
	var cy := base.y + 8
	var glow := color.lightened(0.25) if lit else color.darkened(0.35)
	for dy in range(-4, 5):
		var span := 4 - absi(dy)
		for dx in range(-span, span + 1):
			_set_safe(img, cx + dx, cy + dy, glow if absi(dx) + absi(dy) <= 3 else color)
	_set_safe(img, cx, cy, Color.WHITE if lit else color.lightened(0.1))
	if lit:
		for dy in range(-5, 6):
			var span := 5 - absi(dy)
			_set_safe(img, cx - span, cy + dy, color)
			_set_safe(img, cx + span, cy + dy, color)


static func _set_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


static func _tint_rect(img: Image, origin: Vector2i, w: int, h: int, color: Color, strength: float) -> void:
	for py in range(h):
		for px in range(w):
			var x := origin.x + px
			var y := origin.y + py
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var pixel := img.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			img.set_pixel(x, y, pixel.lerp(Color(color.r, color.g, color.b, pixel.a), strength))


static func _draw_puddle(img: Image, o: Vector2i, r: RandomNumberGenerator) -> void:
	var water := Color("#3f7f96")
	for i in range(3):
		var px := o.x + r.randi_range(3, 11)
		var py := o.y + r.randi_range(4, 11)
		_set_safe(img, px, py, water)
		_set_safe(img, px + 1, py, water.lightened(0.2))
		_set_safe(img, px, py + 1, water.darkened(0.15))


static func _draw_crystal(img: Image, o: Vector2i, r: RandomNumberGenerator, accent: Color) -> void:
	var b := o + Vector2i(r.randi_range(5, 9), r.randi_range(4, 9))
	for i in range(4):
		_set_safe(img, b.x + i, b.y, accent)
	_set_safe(img, b.x + 1, b.y - 1, accent.lightened(0.35))
	_set_safe(img, b.x + 2, b.y - 2, accent.lightened(0.5))
	_set_safe(img, b.x + 3, b.y + 1, accent.darkened(0.2))


static func _draw_mushroom(img: Image, o: Vector2i, r: RandomNumberGenerator) -> void:
	var b := o + Vector2i(r.randi_range(4, 11), r.randi_range(6, 11))
	var cap := Color("#c98a9b") if r.randf() < 0.5 else Color("#d8b46a")
	_set_safe(img, b.x, b.y, Color("#e8ddc8"))
	_set_safe(img, b.x + 1, b.y, Color("#d8cbb2"))
	_set_safe(img, b.x - 1, b.y - 1, cap)
	_set_safe(img, b.x, b.y - 1, cap.lightened(0.2))
	_set_safe(img, b.x + 1, b.y - 1, cap)


static func _draw_ash(img: Image, o: Vector2i, r: RandomNumberGenerator) -> void:
	var b := o + Vector2i(r.randi_range(3, 10), r.randi_range(4, 11))
	var ash := Color("#8a6a63")
	for i in range(4):
		var px := b.x + r.randi_range(-2, 3)
		var py := b.y + r.randi_range(-1, 2)
		_set_safe(img, px, py, ash if i % 2 == 0 else ash.lightened(0.15))
	_set_safe(img, b.x, b.y, Color("#d98a5a"))


static func _texture_image_rgba(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image
