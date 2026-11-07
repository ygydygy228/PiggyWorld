extends Node
## Деньги, инвентарь, выбранный инструмент, показатели выживания. Данные предметов — таблица ITEMS.

const TOOLS: Array[String] = ["axe", "pickaxe", "hoe", "can", "carrot_seed", "turnip_seed", "pumpkin_seed"]

## sell — цена продажи; buy — цена покупки; food — эффект еды; perish — доля свежести, теряемая за день (хардкор).
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
	"berries": {"name": "Ягоды", "icon": "berries", "sell": 5, "food": {"hunger": 9, "health": 0, "sanity": 0}, "perish": 0.3},
	"flower": {"name": "Цветок", "icon": "flower", "sell": 2, "food": {"hunger": 1, "health": 0, "sanity": 10}, "perish": 0.25},
	"carrot": {"name": "Морковь", "icon": "carrot", "sell": 12, "food": {"hunger": 13, "health": 1, "sanity": 0}, "perish": 0.12},
	"turnip": {"name": "Репа", "icon": "turnip", "sell": 18, "food": {"hunger": 13, "health": 1, "sanity": 0}, "perish": 0.1},
	"pumpkin": {"name": "Тыква", "icon": "pumpkin", "sell": 45, "food": {"hunger": 28, "health": 2, "sanity": 0}, "perish": 0.07},
	"egg": {"name": "Яйцо", "icon": "egg", "sell": 10, "food": {"hunger": 6, "health": 0, "sanity": -2}, "perish": 0.2},
	"milk": {"name": "Молоко", "icon": "milk", "sell": 18, "food": {"hunger": 11, "health": 2, "sanity": 3}, "perish": 0.35},
	"wool": {"name": "Шерсть", "icon": "wool", "sell": 15},
	"meat": {"name": "Мясо", "icon": "meat", "sell": 8, "food": {"hunger": 12, "health": 0, "sanity": -6}, "perish": 0.45},
	"cooked_meat": {"name": "Жареное мясо", "icon": "cooked_meat", "sell": 16, "food": {"hunger": 32, "health": 4, "sanity": 3}, "perish": 0.2},
	"fried_egg": {"name": "Яичница", "icon": "fried_egg", "sell": 16, "food": {"hunger": 22, "health": 2, "sanity": 4}, "perish": 0.25},
	"roasted_carrot": {"name": "Печёная морковь", "icon": "roasted_carrot", "sell": 18, "food": {"hunger": 24, "health": 2, "sanity": 3}, "perish": 0.18},
	"roasted_turnip": {"name": "Печёная репа", "icon": "roasted_turnip", "sell": 24, "food": {"hunger": 24, "health": 2, "sanity": 3}, "perish": 0.16},
	"rot": {"name": "Гниль", "icon": "rot", "sell": 1},
	"salve": {"name": "Лечебная мазь", "icon": "salve", "sell": 25, "heal": 30},
	"spear": {"name": "Копьё", "icon": "spear"},
}

const SHOP_STOCK: Array[String] = ["carrot_seed", "turnip_seed", "pumpkin_seed"]

const START_MONEY := 50
const MAX_STAT := 100.0

var money: int = START_MONEY
var inventory: Dictionary = {}
var selected_tool: int = 0
var hardcore: bool = false
var health: float = MAX_STAT
var hunger: float = MAX_STAT
var sanity: float = MAX_STAT
var has_vest: bool = false
var spear_uses: int = 0
var fresh: Dictionary = {}
var hearts: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_setup_input()
	reset()


func reset() -> void:
	money = START_MONEY
	inventory = {"carrot_seed": 8, "turnip_seed": 4, "pumpkin_seed": 2}
	selected_tool = 0
	hardcore = false
	health = MAX_STAT
	hunger = MAX_STAT
	sanity = MAX_STAT
	has_vest = false
	spear_uses = 0
	fresh = {}
	hearts = {}
	EventBus.money_changed.emit(money)
	EventBus.inventory_changed.emit()
	EventBus.tool_changed.emit(selected_tool)
	EventBus.stats_changed.emit()


## Слоты хотбара: базовые инструменты плюс созданные предметы, которые можно держать в руках.
func slots() -> Array[String]:
	var out: Array[String] = []
	out.append_array(TOOLS)
	for id in ["spear", "salve"]:
		if count(id) > 0:
			out.append(id)
	return out


func current_tool() -> String:
	var list := slots()
	return list[clampi(selected_tool, 0, list.size() - 1)]


func select_tool(index: int) -> void:
	var list := slots()
	selected_tool = clampi(index, 0, list.size() - 1)
	EventBus.tool_changed.emit(selected_tool)
	AudioManager.play("ui_click", 0.0, 0.6)


func cycle_tool() -> void:
	var list := slots()
	select_tool((selected_tool + 1) % list.size())


## Индекс выбранного предмета не должен уезжать, когда список слотов меняется.
func keep_selection(id: String) -> void:
	var list := slots()
	var i := list.find(id)
	selected_tool = i if i >= 0 else clampi(selected_tool, 0, list.size() - 1)
	EventBus.tool_changed.emit(selected_tool)


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func is_perishable(id: String) -> bool:
	return ITEMS.get(id, {}).has("perish")


func add_item(id: String, amount: int = 1) -> void:
	if amount <= 0 or not ITEMS.has(id):
		return
	var old := count(id)
	inventory[id] = old + amount
	if is_perishable(id):
		fresh[id] = (float(fresh.get(id, 1.0)) * old + 1.0 * amount) / float(old + amount)
	EventBus.inventory_changed.emit()
	EventBus.item_collected.emit(id, amount)


func remove_item(id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	inventory[id] = count(id) - amount
	if inventory[id] <= 0:
		fresh.erase(id)
	EventBus.inventory_changed.emit()
	return true


func freshness(id: String) -> float:
	return float(fresh.get(id, 1.0))


## Раз в день (хардкор): еда теряет свежесть, совсем несвежая превращается в гниль.
func decay_food() -> void:
	if not hardcore:
		return
	for id in inventory.keys():
		var n := count(str(id))
		if n <= 0 or not is_perishable(str(id)):
			continue
		var f := freshness(str(id)) - float(ITEMS[id]["perish"])
		if f <= 0.0:
			inventory[id] = 0
			fresh.erase(id)
			add_item("rot", n)
			EventBus.message.emit("Испортилось: %s" % item_name(str(id)))
		else:
			fresh[id] = f
	EventBus.inventory_changed.emit()


## Съесть предмет. Несвежая еда (<50%) даёт вдвое меньше.
func eat(id: String) -> bool:
	var food: Dictionary = ITEMS.get(id, {}).get("food", {})
	if food.is_empty() or count(id) <= 0:
		return false
	var mult := 1.0
	if is_perishable(id) and freshness(id) <= 0.5:
		mult = 0.5
	remove_item(id, 1)
	hunger = clampf(hunger + float(food.get("hunger", 0)) * mult, 0.0, MAX_STAT)
	health = clampf(health + float(food.get("health", 0)) * mult, 0.0, MAX_STAT)
	sanity = clampf(sanity + float(food.get("sanity", 0)), 0.0, MAX_STAT)
	EventBus.stats_changed.emit()
	return true


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, MAX_STAT)
	EventBus.stats_changed.emit()


func attack_damage(tool_id: String) -> int:
	if tool_id == "spear":
		return 4 if spear_uses > 0 else 1
	return 2 if tool_id == "axe" else 1


func use_weapon() -> void:
	if spear_uses > 0:
		spear_uses -= 1
		if spear_uses == 0:
			remove_item("spear", count("spear"))
			EventBus.message.emit("Копьё сломалось!")


func npc_hearts(id: String) -> int:
	return int(hearts.get(id, 0))


## Каждый разговор немного сближает; максимум 5 сердец.
func add_heart(id: String) -> int:
	hearts[id] = mini(5, npc_hearts(id) + 1)
	EventBus.stats_changed.emit()
	return int(hearts[id])


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money = maxi(0, money + amount)
	EventBus.money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if amount <= 0 or money < amount:
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
	return {
		"money": money, "inventory": inventory, "selected_tool": selected_tool,
		"hardcore": hardcore, "health": health, "hunger": hunger, "sanity": sanity,
		"has_vest": has_vest, "spear_uses": spear_uses, "fresh": fresh, "hearts": hearts,
	}


func from_dict(d: Dictionary) -> void:
	money = int(d.get("money", START_MONEY))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[str(k)] = int(inv[k])
	var list := slots()
	selected_tool = clampi(int(d.get("selected_tool", 0)), 0, list.size() - 1)
	hardcore = bool(d.get("hardcore", false))
	health = clampf(float(d.get("health", MAX_STAT)), 0.0, MAX_STAT)
	hunger = clampf(float(d.get("hunger", MAX_STAT)), 0.0, MAX_STAT)
	sanity = clampf(float(d.get("sanity", MAX_STAT)), 0.0, MAX_STAT)
	has_vest = bool(d.get("has_vest", false))
	spear_uses = int(d.get("spear_uses", 0))
	hearts = d.get("hearts", {})
	fresh = {}
	var fr: Dictionary = d.get("fresh", {})
	for k in fr:
		fresh[str(k)] = float(fr[k])
	if health <= 0.0:
		health = 50.0
	EventBus.money_changed.emit(money)
	EventBus.inventory_changed.emit()
	EventBus.tool_changed.emit(selected_tool)
	EventBus.stats_changed.emit()


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
