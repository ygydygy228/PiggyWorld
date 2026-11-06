extends Control
## Магазин: покупка семян и продажа добычи.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var npc_id: String = ""
var _mode: String = "buy"
var _list: VBoxContainer
var _money: Label
var _buy_tab: Button
var _sell_tab: Button


func setup(p_npc_id: String) -> void:
	npc_id = p_npc_id


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	theme = UiTheme.shared()
	var body := UiTheme.window(self, 344, 216, "")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	body.add_child(head)
	var title := UiTheme.label("Лавка Милы", UiTheme.GOLD, 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.icon("coin", 14))
	_money = UiTheme.label("0", UiTheme.GOLD, 11)
	head.add_child(_money)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	_buy_tab = _tab(tabs, "Купить", "buy")
	_sell_tab = _tab(tabs, "Продать", "sell")

	var sc := UiTheme.scroll_list(Vector2(316, 140))
	body.add_child(sc[0])
	_list = sc[1]

	var close := UiTheme.close_button()
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	body.add_child(close)
	_refresh()


func _tab(parent: Node, text: String, mode: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 20)
	b.pressed.connect(func() -> void:
		_mode = mode
		AudioManager.play("ui_click", 0.0)
		_refresh())
	parent.add_child(b)
	return b


func _refresh() -> void:
	_money.text = str(GameState.money)
	_buy_tab.button_pressed = _mode == "buy"
	_sell_tab.button_pressed = _mode == "sell"
	for c in _list.get_children():
		c.queue_free()
	if _mode == "buy":
		for id in GameState.SHOP_STOCK:
			_row(id, GameState.buy_price(id), "Купить", false)
	else:
		var any := false
		for id in GameState.ITEMS:
			if GameState.count(id) > 0 and GameState.sell_price(id) > 0:
				_row(id, GameState.sell_price(id), "Продать", true)
				any = true
		if not any:
			_list.add_child(UiTheme.label("Нечего продавать", UiTheme.MUTED, 10))


func _row(id: String, price: int, verb: String, sell: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_list.add_child(row)
	row.add_child(UiTheme.icon(id, 16))
	var name_label := UiTheme.label(GameState.item_name(id) + (" x%d" % GameState.count(id) if sell else ""), UiTheme.TEXT, 10)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var price_label := UiTheme.label(str(price), UiTheme.GOLD, 10)
	price_label.custom_minimum_size = Vector2(24, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)
	var b := Button.new()
	b.text = verb
	b.custom_minimum_size = Vector2(62, 18)
	b.disabled = (not sell) and GameState.money < price
	b.pressed.connect(_trade.bind(id, price, sell, false))
	row.add_child(b)
	if sell and GameState.count(id) > 1:
		var all := Button.new()
		all.text = "Все"
		all.custom_minimum_size = Vector2(32, 18)
		all.pressed.connect(_trade.bind(id, price, sell, true))
		row.add_child(all)


func _trade(id: String, price: int, sell: bool, all: bool) -> void:
	if sell:
		var n := GameState.count(id) if all else 1
		if n > 0 and GameState.remove_item(id, n):
			GameState.add_money(price * n)
			AudioManager.play("coin", 0.03)
			EventBus.message.emit("+%d монет" % (price * n))
	elif GameState.spend_money(price):
		GameState.add_item(id, 1)
		AudioManager.play("coin", 0.03)
	else:
		AudioManager.play("error", 0.0)
	_refresh()
