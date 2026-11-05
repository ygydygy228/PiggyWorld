extends Node
## Глобальная шина событий: системы общаются сигналами, а не прямыми ссылками.

signal inventory_changed
signal money_changed(amount: int)
signal tool_changed(index: int)
signal message(text: String)
signal clock_changed(day: int, hour: int, minute: int)
signal day_started(day: int)
signal weather_changed(kind: String)
signal item_collected(id: String, amount: int)
signal dialog_requested(speaker: String, lines: Array, action: String)
