extends RefCounted
## Строит SpriteFrames свинки из спрайт-листа и таблицы pig_meta.gd.

const PigMeta := preload("res://scripts/art/pig_meta.gd")


static func build() -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/sprites/pig_sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for r in PigMeta.ROWS:
		var anim: String = r["name"]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(r["fps"]))
		sf.set_animation_loop(anim, bool(r["loop"]))
		for i in range(int(r["frames"])):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * PigMeta.FRAME_W, int(r["row"]) * PigMeta.FRAME_H, PigMeta.FRAME_W, PigMeta.FRAME_H)
			sf.add_frame(anim, at)
	return sf
