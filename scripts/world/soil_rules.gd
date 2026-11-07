extends RefCounted
## Deterministic crop rotation and soil fertility rules.
const MIN_FERTILITY := 20
const MAX_FERTILITY := 100
const SAME_CROP_PENALTY := 18
const ROTATION_BONUS := 12

static func after_harvest(current: int, previous_crop: String, next_crop: String) -> int:
	var value := clampi(current, MIN_FERTILITY, MAX_FERTILITY)
	if previous_crop != "" and previous_crop == next_crop:
		value -= SAME_CROP_PENALTY
	elif previous_crop != "" and previous_crop != next_crop:
		value += ROTATION_BONUS
	return clampi(value, MIN_FERTILITY, MAX_FERTILITY)

static func yield_bonus(fertility: int) -> int:
	if fertility >= 85:
		return 1
	if fertility <= 35:
		return -1
	return 0
