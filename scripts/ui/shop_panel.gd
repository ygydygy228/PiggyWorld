extends Control
## Магазин: покупка семян и продажа добычи.

signal closed

var _mode: String = "buy"
var _list: VBoxContainer
var _money: Label
var _buy_tab: Button
var _sell_tab: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	var title := Label.new()
	title.text = "Лавка Милы"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var coin := TextureRect.new()
	coin.texture = GameState.item_icon("coin")
	coin.custom_minimum_size = Vector2(16, 16)
	head.add_child(coin)
	_money = Label.new()
	head.add_child(_money)
	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	_buy_tab = _tab(tabs, "Купить", "buy")
	_sell_tab = _tab(tabs, "Продать", "sell")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	root.add_child(close)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_refresh()


func _tab(parent: Node, text: String, mode: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
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
			var l := Label.new()
			l.text = "Нечего продавать"
			_list.add_child(l)


func _row(id: String, price: int, verb: String, sell: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_list.add_child(row)
	var icon := TextureRect.new()
	icon.texture = GameState.item_icon(id)
	icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = GameState.item_name(id) + (" x%d" % GameState.count(id) if sell else "")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var price_label := Label.new()
	price_label.text = str(price)
	price_label.custom_minimum_size = Vector2(26, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)
	var b := Button.new()
	b.text = verb
	b.custom_minimum_size = Vector2(64, 20)
	b.disabled = (not sell) and GameState.money < price
	b.pressed.connect(_trade.bind(id, price, sell, false))
	row.add_child(b)
	if sell and GameState.count(id) > 1:
		var all := Button.new()
		all.text = "Все"
		all.custom_minimum_size = Vector2(34, 20)
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
