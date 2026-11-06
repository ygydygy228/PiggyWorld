# Ассеты

Все ассеты оригинальные, сгенерированы кодом (папка `tools/`), лицензия — как у проекта.
Шрифт растеризован из DejaVu Sans (свободная лицензия Bitstream Vera/DejaVu).

| Файл | Генератор |
|---|---|
| assets/sprites/pig_sheet.png (+ scripts/art/pig_meta.gd) | tools/gen_pig.py |
| assets/tiles/tileset.png, assets/objects/* | tools/gen_world.py, tools/gen_extra.py |
| assets/icons/* | tools/gen_icons.py |
| assets/fonts/pixel.fnt/.png | tools/gen_font.py |
| assets/audio/*.wav | tools/gen_audio.py |

Запуск: `python3 tools/gen_pig.py` (нужны Pillow, numpy для звука).
После `gen_pig.py` обновить `scripts/art/pig_meta.gd` из `assets/sprites/pig_sheet.json` (формат — см. текущий файл).

Анимации свинки: idle, walk, run, eat, happy, sad, interact — в ракурсах down/side/up (влево — flip_h), sleep — side.
Кадр 32x40 px, земля на y=36.

Тайлсет (16x16): строка 0 — вода (4 кадра анимации); строки 1/2/3 — наложения трава/песок/дорожка по 16 вариантов (маска соседей N=1,E=2,S=4,W=8); строка 4 — грядки (сухая, мокрая) и 4 варианта травы.

| assets/sprites/animals/*.png (кадр 32x32; строки idle/walk/eat/sleep) и assets/sprites/npc/*.png (24x32; ходьба down/up/side, idle, talk) | tools/gen_npc.py, tools/gen_animals.py |
| новые иконки, культуры репа/тыква | tools/gen_items.py |
| голоса животных | tools/gen_audio_animals.py |

| assets/objects/bench.png, lamp.png, scarecrow.png | tools/gen_build.py |

| assets/interior/room.png, мебель (bed, table, bookshelf, armchair, plant_pot, clock) | tools/gen_interior.py |

| assets/sprites/animals/wolf.png, assets/objects/campfire.png, иконки еды/копья/жилета/мази/гнили | tools/gen_hardcore.py |
| howl, bite, hurt, eat | tools/gen_audio_hardcore.py |
