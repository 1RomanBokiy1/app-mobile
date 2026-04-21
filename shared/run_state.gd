extends Node
## Временное состояние активного прохождения (нужно, чтобы при выходе в настройки и возврате
## не сбрасывались жизни/прогресс текущего уровня).

var has_active_run: bool = false
var restore_on_next_enter: bool = false

var current_level_index: int = 0
var lives: int = 3
var correct_answers: int = 0


func start_new_run(level_index: int, start_lives: int = 3, start_correct_answers: int = 0) -> void:
	has_active_run = true
	restore_on_next_enter = false
	current_level_index = maxi(0, level_index)
	lives = clampi(start_lives, 0, 3)
	correct_answers = maxi(0, start_correct_answers)


func mark_return_from_settings(level_index: int, current_lives: int, current_correct_answers: int = 0) -> void:
	has_active_run = true
	restore_on_next_enter = true
	current_level_index = maxi(0, level_index)
	lives = clampi(current_lives, 0, 3)
	correct_answers = maxi(0, current_correct_answers)


func consume_restore() -> bool:
	if not restore_on_next_enter:
		return false
	restore_on_next_enter = false
	return true


func clear_run() -> void:
	has_active_run = false
	restore_on_next_enter = false
	current_level_index = 0
	lives = 3
	correct_answers = 0

