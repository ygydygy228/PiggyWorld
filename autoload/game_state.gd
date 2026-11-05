extends Node
## Деньги, инвентарь, выбранный инструмент. Данные предметов описаны таблицей ITEMS.

const TOOLS: Array[String] = ["axe", "pickaxe", "hoe", "can", "carrot_seed", "turnip_seed", "pumpkin_seed"]

## sell — цена продажи; buy — цена покупки в лавке (0 = не продаётся/не покупается).
const ITEMS := {
	"axe": {"name": "Топор", "icon": "axe"},
	"pickaxe": {"name": "Кирка", "icon": "pickaxe"},
	"hoe": {"name": "Мотыга", "icon": "hoe"},
	"can": {"name": "Лейка", "icon": "can"},
	"carrot_seed": {"name": "Семена моркови", "icon": "seeds", "buy": 6, "sell": 3},
	"turnip_seed": {"name": "Семена репы", "icon": "seeds_turnip", "buy": 8, "sell": 4},
	"pumpkin_seed": {"name": "Семена тыквы", "icon": "seeds_pumpkin", "buy": 20, "sell": 10},
	"wood": {"name": "Дерево", "icon": "wood", "sell": 3},
	"stone": {"name": "Камень", "icon": "stone", "sell": 4},
	"berries": {"name": "Ягоды", "icon": "berries", "sell": 5},
	"flower": {"name": "Цветок", "icon": "flower", "sell": 2},
	"carrot": {"name": "Морковь", "icon": "carrot", "sell": 12},
	"turnip": {"name": "Репа", "icon": "turnip", "sell": 18},
	"pumpkin": {"name": "Тыква", "icon": "pumpkin", "sell": 45},
	"egg": {"name": "Яйцо", "icon": "egg", "sell": 10},
	"milk": {"name": "Молоко", "icon": "milk", "sell": 18},
	"wool": {"name": "Шерсть", "icon": "wool", "sell": 15},
}

const SHOP_STOCK: Array[String] = ["carrot_seed", "turnip_seed", "pumpkin_seed"]

const START_MONEY := 50

var money: int = START_MONEY
var inventory: Dictionary = {}
var selected_tool: int = 0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_setup_input()
	reset()


func reset() -> void:
	money = START_MONEY
	inventory = {"carrot_seed": 8, "turnip_seed": 4, "pumpkin_seed": 2}
	selected_tool = 0
	EventBus.money_changed.emit(money)
	EventBus.inventory_changed.emit()
	EventBus.tool_changed.emit(selected_tool)


func current_tool() -> String:
	return TOOLS[selected_tool]


func select_tool(index: int) -> void:
	selected_tool = clampi(index, 0, TOOLS.size() - 1)
	EventBus.tool_changed.emit(selected_tool)
	AudioManager.play("ui_click", 0.0, 0.6)


func cycle_tool() -> void:
	select_tool((selected_tool + 1) % TOOLS.size())


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, amount: int = 1) -> void:
	inventory[id] = count(id) + amount
	EventBus.inventory_changed.emit()
	EventBus.item_collected.emit(id, amount)


func remove_item(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	inventory[id] = count(id) - amount
	EventBus.inventory_changed.emit()
	return true


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true


func buy_price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("buy", 0))


func sell_price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("sell", 0))


func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id))


func item_icon(id: String) -> Texture2D:
	var icon_name: String = str(ITEMS.get(id, {}).get("icon", id))
	if not _icon_cache.has(icon_name):
		_icon_cache[icon_name] = load("res://assets/icons/%s.png" % icon_name)
	return _icon_cache[icon_name]


func to_dict() -> Dictionary:
	return {"money": money, "inventory": inventory, "selected_tool": selected_tool}


func from_dict(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[str(k)] = int(inv[k])
	selected_tool = clampi(int(d.get("selected_tool", 0)), 0, TOOLS.size() - 1)
	EventBus.money_changed.emit(money)
	EventBus.inventory_changed.emit()
	EventBus.tool_changed.emit(selected_tool)


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("run", [KEY_SHIFT])
	_add_action("act", [KEY_SPACE, KEY_E])
	_add_action("tool_next", [KEY_R, KEY_TAB])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
