extends SceneTree
## Дымовой тест для CI: godot --headless --path . -s scripts/dev/smoke_test.gd
## Запускает главную сцену, начинает новую игру и крутит игру ~200 кадров.

var _frames: int = 0
var _main: Node


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	elif _frames == 5:
		_main._start_game(false)
	elif _frames == 200:
		print("SMOKE_OK")
		quit(0)
	return false
