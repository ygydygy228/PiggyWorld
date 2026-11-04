# PiggyWorld — памятка для разработки

Игра: уютный 2D pixel-art фермер про свинку. Godot 4.4, GDScript, GL Compatibility, цель — Android.

## Правила
- Все сцены строятся кодом, скрипты подключаются через `preload("res://...")` (без `class_name`, чтобы не зависеть от кэша классов при первом импорте).
- Системы общаются через `autoload/event_bus.gd`. Данные предметов — `autoload/game_state.gd` (ITEMS), объектов мира — `scripts/world/world_object.gd` (DEFS).
- Графика генерируется скриптами `tools/*.py` (PIL, numpy): `gen_pig.py`, `gen_world.py`, `gen_extra.py`, `gen_icons.py`, `gen_font.py`, `gen_audio.py`. После правки генератора запустить его и закоммитить PNG/WAV. `scripts/art/pig_meta.gd` обновляется при изменении `gen_pig.py` (см. docs/ASSETS.md).
- Проверка перед коммитом: `godot --headless --path . --import`, затем `godot --headless --path . -s scripts/dev/smoke_test.gd` (должно печатать SMOKE_OK без SCRIPT ERROR).
- Не удалять старые файлы прототипа (`game.gd`, `main.tscn` в корне) без причины: они не используются новой версией.

## Структура
autoload/ — EventBus, GameState, SaveSystem, TimeSystem, AudioManager
scripts/world — world.gd (рельеф, слои TileMapLayer, ферма, сезоны), world_object.gd
scripts/player — player.gd (движение, анимации, действия)
scripts/ui — hud, touch_controls, main_menu, pause_menu, settings_panel, ui_theme
scripts/fx — частицы (fx.gd, weather_fx.gd)

## Что сделано / что дальше
Сделано: свинка (8 анимаций, 3 ракурса + флип), мир 96x72 на 5 TileMapLayer с автопереходами, озеро, речка, мостики, лес, ферма, деревня (дома), вход в пещеру, рубка, добыча, ягоды, посадка/полив/урожай моркови, сезоны, дождь/снег/листья, день/ночь, HUD, сенсорное управление, меню, пауза, сохранение, звук.
Дальше: животные (6 видов) и их поведение; NPC и диалоги; магазин (покупка/продажа); меню строительства и размещение предметов; пещера (интерьер) и секретные места; больше культур; сон в доме; тонкая полировка арта.
