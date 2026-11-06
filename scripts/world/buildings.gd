extends RefCounted
## Каталог построек: название, стоимость, текстура. Логика размещения — в world.gd.

const DEFS := {
	"fence_built": {"name": "Забор", "cost": {"wood": 2}, "tex": "fence", "where": "out"},
	"bench": {"name": "Скамейка", "cost": {"wood": 5}, "tex": "bench", "where": "out"},
	"lamp": {"name": "Фонарь", "cost": {"wood": 3, "stone": 2}, "tex": "lamp", "where": "both"},
	"scarecrow": {"name": "Пугало", "cost": {"wood": 6}, "tex": "scarecrow", "where": "out"},
	"campfire": {"name": "Костёр", "cost": {"wood": 3, "stone": 1}, "tex": "campfire", "frames": 4, "where": "out"},
	"armchair": {"name": "Кресло", "cost": {"wood": 5}, "tex": "armchair", "where": "in"},
	"bookshelf": {"name": "Книжный шкаф", "cost": {"wood": 8}, "tex": "bookshelf", "where": "in"},
	"plant_pot": {"name": "Цветок в горшке", "cost": {"flower": 3}, "tex": "plant_pot", "where": "in"},
}


static func allowed(kind: String, indoors: bool) -> bool:
	var w := str(DEFS[kind].get("where", "out"))
	return w == "both" or (w == "in" and indoors) or (w == "out" and not indoors)


static func available(indoors: bool) -> Array:
	var out: Array = []
	for k in DEFS:
		if allowed(str(k), indoors):
			out.append(str(k))
	return out


static func can_afford(kind: String) -> bool:
	var cost: Dictionary = DEFS[kind]["cost"]
	for item in cost:
		if GameState.count(str(item)) < int(cost[item]):
			return false
	return true


static func pay(kind: String) -> void:
	var cost: Dictionary = DEFS[kind]["cost"]
	for item in cost:
		GameState.remove_item(str(item), int(cost[item]))


static func cost_text(kind: String) -> String:
	var cost: Dictionary = DEFS[kind]["cost"]
	var parts: Array[String] = []
	for item in cost:
		parts.append("%s x%d" % [GameState.item_name(str(item)), int(cost[item])])
	return ", ".join(parts)
