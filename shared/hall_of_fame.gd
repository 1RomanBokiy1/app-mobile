extends Node
## Хранит и сохраняет таблицу зала славы между сессиями приложения.

const _CONFIG_PATH := "user://hall_of_fame.cfg"
const _SECTION := "hall_of_fame"
const _KEY_ENTRIES := "entries"
const _MAX_NAME_LENGTH: int = 18
const _MAX_ENTRIES: int = 200

var _entries: Array[Dictionary] = []
var _pending_correct_answers: int = 0


func _ready() -> void:
	_load_entries()


func add_entry(player_name: String, correct_answers: int) -> void:
	var safe_name := _sanitize_name(player_name)
	if safe_name.is_empty():
		return
	var entry := {
		"name": safe_name,
		"correct_answers": maxi(0, correct_answers),
		"created_at_unix": Time.get_unix_time_from_system()
	}
	_entries.append(entry)
	_sort_entries()
	if _entries.size() > _MAX_ENTRIES:
		_entries.resize(_MAX_ENTRIES)
	_save_entries()


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func set_pending_correct_answers(value: int) -> void:
	_pending_correct_answers = maxi(0, value)


func get_pending_correct_answers() -> int:
	return _pending_correct_answers


func clear_pending_correct_answers() -> void:
	_pending_correct_answers = 0


func _load_entries() -> void:
	_entries.clear()
	var cf := ConfigFile.new()
	if cf.load(_CONFIG_PATH) != OK:
		return
	var raw: Variant = cf.get_value(_SECTION, _KEY_ENTRIES, [])
	if not (raw is Array):
		return
	for item in raw:
		if not (item is Dictionary):
			continue
		var player_name := _sanitize_name(str((item as Dictionary).get("name", "")))
		if player_name.is_empty():
			continue
		var score := maxi(0, int((item as Dictionary).get("correct_answers", 0)))
		var created_at := int((item as Dictionary).get("created_at_unix", 0))
		_entries.append({
			"name": player_name,
			"correct_answers": score,
			"created_at_unix": created_at
		})
	_sort_entries()
	if _entries.size() > _MAX_ENTRIES:
		_entries.resize(_MAX_ENTRIES)


func _save_entries() -> void:
	var cf := ConfigFile.new()
	cf.set_value(_SECTION, _KEY_ENTRIES, _entries)
	cf.save(_CONFIG_PATH)


func _sort_entries() -> void:
	_entries.sort_custom(_compare_entries)


func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("correct_answers", 0))
	var score_b := int(b.get("correct_answers", 0))
	if score_a != score_b:
		return score_a > score_b
	var time_a := int(a.get("created_at_unix", 0))
	var time_b := int(b.get("created_at_unix", 0))
	return time_a < time_b


func _sanitize_name(raw_name: String) -> String:
	var out := raw_name.strip_edges()
	if out.length() > _MAX_NAME_LENGTH:
		out = out.substr(0, _MAX_NAME_LENGTH)
	return out
