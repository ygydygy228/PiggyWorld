extends RefCounted
## Рецепты крафта (рюкзак → вкладка «Крафт»). Костёр и фонарь — в меню стройки.

const RECIPES: Array = [
	{"id": "spear", "name": "Копьё", "desc": "Урон 4, хватает на 30 ударов", "icon": "spear", "cost": {"wood": 2, "stone": 1}},
	{"id": "salve", "name": "Лечебная мазь", "desc": "Лечит 30 здоровья", "icon": "salve", "cost": {"flower": 2, "berries": 2}},
	{"id": "vest", "name": "Шерстяной жилет", "desc": "Холод бьёт в 3 раза слабее", "icon": "vest", "cost": {"wool": 4}},
]


static func can_craft(r: Dictionary) -> bool:
	for item in r["cost"]:
		if GameState.count(str(item)) < int(r["cost"][item]):
			return false
	return true


static func cost_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	for item in r["cost"]:
		parts.append("%s x%d" % [GameState.item_name(str(item)), int(r["cost"][item])])
	return ", ".join(parts)


static func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		return false
	var id := str(r["id"])
	if id == "vest" and GameState.has_vest:
		EventBus.message.emit("Жилет уже надет")
		return false
	for item in r["cost"]:
		GameState.remove_item(str(item), int(r["cost"][item]))
	match id:
		"spear":
			GameState.spear_uses = 30
			if GameState.count("spear") == 0:
				GameState.add_item("spear", 1)
		"salve":
			GameState.add_item("salve", 1)
		"vest":
			GameState.has_vest = true
			EventBus.stats_changed.emit()
	EventBus.message.emit("Готово: %s" % str(r["name"]))
	return true
