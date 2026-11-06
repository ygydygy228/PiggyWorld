extends Node
## Время суток, дни, сезоны и погода.

const DAY_SECONDS := 480.0
const DAYS_PER_SEASON := 7
const SEASON_NAMES: Array[String] = ["Весна", "Лето", "Осень", "Зима"]
const START_TIME := 0.30

const LIGHT_KEYS: Array = [
	[0.00, Color("#2a3558")], [0.20, Color("#2f3a63")], [0.27, Color("#f0a98a")],
	[0.35, Color("#fff4e0")], [0.50, Color("#ffffff")], [0.68, Color("#fff0d0")],
	[0.76, Color("#f2a06a")], [0.84, Color("#5a5a8a")], [0.92, Color("#2f3a63")],
	[1.00, Color("#2a3558")],
]

var day: int = 1
var time_of_day: float = START_TIME
var weather: String = "sunny"
var running: bool = false
var _last_slot: int = -1


func reset() -> void:
	day = 1
	time_of_day = START_TIME
	weather = "sunny"
	_last_slot = -1


func _process(delta: float) -> void:
	if not running:
		return
	time_of_day += delta / DAY_SECONDS
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		_roll_weather()
		EventBus.day_started.emit(day)
	var slot := int(time_of_day * 144.0)
	if slot != _last_slot:
		_last_slot = slot
		EventBus.clock_changed.emit(day, hour(), minute())


func hour() -> int:
	return int(time_of_day * 24.0) % 24


func minute() -> int:
	return int(fmod(time_of_day * 24.0, 1.0) * 6.0) * 10


func clock_text() -> String:
	return "%02d:%02d" % [hour(), minute()]


func season_index() -> int:
	return int(floor((day - 1) / float(DAYS_PER_SEASON))) % 4


func season_name() -> String:
	return SEASON_NAMES[season_index()]


func weather_name() -> String:
	match weather:
		"rain":
			return "Дождь"
		"snow":
			return "Снег"
	return "Солнечно"


func is_night() -> bool:
	return time_of_day < 0.22 or time_of_day > 0.86


func light_color() -> Color:
	var c := Color.WHITE
	for i in range(LIGHT_KEYS.size() - 1):
		var a: Array = LIGHT_KEYS[i]
		var b: Array = LIGHT_KEYS[i + 1]
		if time_of_day >= float(a[0]) and time_of_day <= float(b[0]):
			var f := inverse_lerp(float(a[0]), float(b[0]), time_of_day)
			c = (a[1] as Color).lerp(b[1] as Color, f)
			break
	if weather == "rain":
		c = c.lerp(Color(0.62, 0.68, 0.8), 0.4)
	elif weather == "snow":
		c = c.lerp(Color(0.85, 0.9, 1.0), 0.25)
	return c


func set_weather(kind: String) -> void:
	weather = kind
	EventBus.weather_changed.emit(kind)


func _roll_weather() -> void:
	var r := randf()
	var kind := "sunny"
	if season_index() == 3:
		if r < 0.45:
			kind = "snow"
	elif r < 0.25:
		kind = "rain"
	set_weather(kind)


## Сон: сразу следующее утро, погода перебрасывается, день начинается заново.
func sleep_until_morning() -> void:
	day += 1
	time_of_day = START_TIME
	_last_slot = -1
	_roll_weather()
	EventBus.day_started.emit(day)
	EventBus.clock_changed.emit(day, hour(), minute())


func to_dict() -> Dictionary:
	return {"day": day, "time": time_of_day, "weather": weather}


func from_dict(d: Dictionary) -> void:
	day = maxi(1, int(d.get("day", 1)))
	time_of_day = clampf(float(d.get("time", START_TIME)), 0.0, 0.999)
	weather = str(d.get("weather", "sunny"))
	_last_slot = -1
