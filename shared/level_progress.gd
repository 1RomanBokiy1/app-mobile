extends Node
## Прогресс уровней: открытие по порядку; после прохождения всех — всё открыто для повтора.

const LEVEL_COUNT: int = 6
const _CONFIG_PATH := "user://level_progress.cfg"

const RESULT_NONE: int = 0
const RESULT_CORRECT: int = 1
const RESULT_INCORRECT: int = 2


func get_level_count() -> int:
	return LEVEL_COUNT

var max_unlocked_index: int = 0
var all_levels_completed: bool = false
var pending_play_index: int = -1
var level_results: Array[int] = []


func _ready() -> void:
	_load()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(_CONFIG_PATH) != OK:
		max_unlocked_index = 0
		all_levels_completed = false
		level_results = []
		for i in range(LEVEL_COUNT):
			level_results.append(RESULT_NONE)
		return
	max_unlocked_index = int(cf.get_value("levels", "max_unlocked_index", 0))
	all_levels_completed = bool(cf.get_value("levels", "all_completed", false))
	max_unlocked_index = clampi(max_unlocked_index, 0, LEVEL_COUNT - 1)

	level_results = []
	for i in range(LEVEL_COUNT):
		level_results.append(int(cf.get_value("levels", "result_%d" % i, RESULT_NONE)))


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("levels", "max_unlocked_index", max_unlocked_index)
	cf.set_value("levels", "all_completed", all_levels_completed)
	for i in range(LEVEL_COUNT):
		var v := RESULT_NONE
		if i >= 0 and i < level_results.size():
			v = int(level_results[i])
		cf.set_value("levels", "result_%d" % i, v)
	cf.save(_CONFIG_PATH)


func is_level_unlocked(idx: int) -> bool:
	if idx < 0 or idx >= LEVEL_COUNT:
		return false
	if all_levels_completed:
		return true
	return idx <= max_unlocked_index


func begin_play_level(idx: int) -> void:
	pending_play_index = clampi(idx, 0, LEVEL_COUNT - 1)


func take_pending_level_index(fallback_index: int = 0) -> int:
	var v := pending_play_index
	pending_play_index = -1
	if v < 0:
		return clampi(fallback_index, 0, LEVEL_COUNT - 1)
	return clampi(v, 0, LEVEL_COUNT - 1)


func notify_level_completed(idx: int) -> void:
	if all_levels_completed:
		return
	idx = clampi(idx, 0, LEVEL_COUNT - 1)
	if idx != max_unlocked_index:
		return
	if idx >= LEVEL_COUNT - 1:
		all_levels_completed = true
		_save()
		return
	max_unlocked_index = idx + 1
	_save()


func get_level_result(idx: int) -> int:
	if idx < 0 or idx >= LEVEL_COUNT:
		return RESULT_NONE
	if idx >= level_results.size():
		return RESULT_NONE
	return int(level_results[idx])


func set_level_result(idx: int, correct: bool) -> void:
	if idx < 0 or idx >= LEVEL_COUNT:
		return
	if level_results.is_empty():
		level_results = []
		for i in range(LEVEL_COUNT):
			level_results.append(RESULT_NONE)
	level_results[idx] = RESULT_CORRECT if correct else RESULT_INCORRECT
	_save()
