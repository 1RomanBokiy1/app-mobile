extends Control
## Игровая сцена уровней: вступление (уровень 0), затем уровни 1..6 с выбором из 2 ответов и жизнями.

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _RunStateScript = preload("res://shared/run_state.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var level_select_scene_path: String = "res://scenes/level_select.tscn"
@export_file("*.tscn") var settings_scene_path: String = "res://scenes/settings.tscn"
@export_file("*.tscn") var final_scene_path: String = "res://scenes/final_scene.tscn"
@export_file("*.txt") var levels_text_path: String = "res://levels.txt"

const _LEVEL_SCENE_PATH: String = "res://scenes/level_scene.tscn"

@export_range(0.012, 0.08, 0.002) var typewriter_char_delay: float = 0.028

@onready var _btn_back: Button = %BtnBack
@onready var _btn_settings: Button = %BtnSettings
@onready var _portrait: TextureRect = %PortraitNarrator
@onready var _name_label: Label = %NameLabel
@onready var _dialogue_label: RichTextLabel = %DialogueText
@onready var _hint_label: Label = %HintLabel
@onready var _heart1: TextureRect = %Heart1
@onready var _heart2: TextureRect = %Heart2
@onready var _heart3: TextureRect = %Heart3

@onready var _choice_a: Button = %ChoiceA
@onready var _choice_b: Button = %ChoiceB
@onready var _choice_a_txt: Label = %ChoiceATxt
@onready var _choice_b_txt: Label = %ChoiceBTxt

enum Phase { INTRO, CHOICE, RESULT, GAME_OVER, FINISHED }

var _phase: int = Phase.INTRO
var _levels: Dictionary = {} # int -> Dictionary
var _intro_text: String = ""
var _current_level: int = 1
var _lives: int = 3
var _typing: bool = false
var _line_plain: String = ""
var _type_timer: Timer
var _pending_result_text: String = ""
var _pending_next_level: int = -1
var _choices_unlocked: bool = false


func _ready() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)

	_MenuUi.bind_press_feedback(_btn_back)
	_btn_back.pressed.connect(_on_back_pressed)
	_MenuUi.bind_press_feedback(_btn_settings)
	_btn_settings.pressed.connect(_on_settings_pressed)

	_choice_a.pressed.connect(_on_choice_pressed.bind(0))
	_choice_b.pressed.connect(_on_choice_pressed.bind(1))
	_MenuUi.bind_press_feedback(_choice_a)
	_MenuUi.bind_press_feedback(_choice_b)

	_type_timer = Timer.new()
	_type_timer.one_shot = false
	add_child(_type_timer)
	_type_timer.timeout.connect(_on_typewriter_tick)

	_load_levels_text()
	_reset_run_from_selection()
	var mb = _MusicBusScript.new()
	mb.call("play_level")
	_prepare_intro_visuals()
	await _play_intro_sequence()
	_show_intro()


func _prepare_intro_visuals() -> void:
	_set_choices_visible(false)
	_choice_a.disabled = true
	_choice_b.disabled = true
	# Жизни всегда видны (интро в levels.txt не упоминает «сердца» — раньше они не появлялись).
	_update_lives_ui()
	_heart1.modulate = Color(1, 1, 1, 1)
	_heart2.modulate = Color(1, 1, 1, 1)
	_heart3.modulate = Color(1, 1, 1, 1)
	# Текст и подсказка сразу читаемы; печать не должна быть с alpha=0.
	_name_label.modulate = Color(1, 1, 1, 1)
	_dialogue_label.modulate = Color(1, 1, 1, 1)
	_hint_label.modulate = Color(1, 1, 1, 1)
	_portrait.modulate = Color(1, 1, 1, 0.0)


func _play_intro_sequence() -> void:
	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_portrait, "modulate", Color(1, 1, 1, 1), 0.28)
	await tw.finished


func _exit_tree() -> void:
	if _type_timer != null:
		_type_timer.stop()
		if _type_timer.timeout.is_connected(_on_typewriter_tick):
			_type_timer.timeout.disconnect(_on_typewriter_tick)
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _gui_input(event: InputEvent) -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr != null and mgr.is_paused():
		return
	if event is InputEventScreenTouch and event.pressed:
		var e_touch := event as InputEventScreenTouch
		if _is_over_interactive_ui(e_touch.position):
			return
		accept_event()
		_on_tap()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var e_mouse := event as InputEventMouseButton
		if _is_over_interactive_ui(e_mouse.position):
			return
		accept_event()
		_on_tap()


func _is_over_interactive_ui(pos: Vector2) -> bool:
	var buttons: Array[Button] = [_choice_a, _choice_b, _btn_back, _btn_settings]
	for b in buttons:
		if b == null or not b.visible:
			continue
		if b.get_global_rect().has_point(pos):
			return true
	return false


func _on_tap() -> void:
	match _phase:
		Phase.INTRO:
			if _typing:
				_finish_line_typing()
			else:
				_start_level(_current_level)
		Phase.CHOICE:
			if _typing:
				_finish_line_typing()
		Phase.RESULT:
			if _typing:
				_finish_line_typing()
			else:
				_continue_after_result()
		Phase.GAME_OVER:
			if _typing:
				_finish_line_typing()
			else:
				_go_level_select()
		Phase.FINISHED:
			_go_level_select()
		_:
			pass


func _reset_run_from_selection() -> void:
	var lp := get_tree().root.get_node_or_null("LevelProgress")
	var run := get_tree().root.get_node_or_null("RunState")
	if lp:
		_current_level = int(lp.call("take_pending_level_index", 0)) + 1
	_current_level = clampi(_current_level, 1, 6)
	if run != null and run is _RunStateScript and (run as _RunStateScript).consume_restore():
		_lives = int((run as _RunStateScript).lives)
	else:
		_lives = 3
		if run != null and run is _RunStateScript:
			(run as _RunStateScript).start_new_run(_current_level - 1, _lives)
	_update_lives_ui()
	_choices_unlocked = false


func _show_intro() -> void:
	_phase = Phase.INTRO
	_hint_label.visible = true
	_hint_label.text = "Нажмите для продолжения"
	_name_label.text = "Вицемэрио"
	_set_choices_visible(false)
	_start_typewriter(_intro_text)


func _start_level(level_idx: int) -> void:
	level_idx = clampi(level_idx, 1, 6)
	_current_level = level_idx
	_phase = Phase.CHOICE
	_hint_label.visible = false
	_choices_unlocked = false

	var lv: Dictionary = _levels.get(level_idx, {})
	_name_label.text = "Вицемэрио"
	var prompt := str(lv.get("prompt", ""))
	_set_choices_visible(false)

	var opts: Array = lv.get("options", [])
	_choice_a_txt.text = str(opts[0]) if opts.size() > 0 else "Вариант 1"
	_choice_b_txt.text = str(opts[1]) if opts.size() > 1 else "Вариант 2"

	_choice_a.disabled = true
	_choice_b.disabled = true

	_update_lives_ui()
	_heart1.modulate = Color(1, 1, 1, 1)
	_heart2.modulate = Color(1, 1, 1, 1)
	_heart3.modulate = Color(1, 1, 1, 1)
	_name_label.modulate = Color(1, 1, 1, 1)
	_dialogue_label.modulate = Color(1, 1, 1, 1)

	_start_typewriter(prompt)


func _on_choice_pressed(choice_idx: int) -> void:
	if _phase != Phase.CHOICE:
		return
	if _typing:
		_finish_line_typing()
		return

	var lv: Dictionary = _levels.get(_current_level, {})
	var res: Dictionary = {}
	if choice_idx == 0:
		res = lv.get("result_1", {})
	else:
		res = lv.get("result_2", {})

	var correct: bool = bool(res.get("correct", false))
	var lp_set := get_tree().root.get_node_or_null("LevelProgress")
	if lp_set:
		lp_set.call("set_level_result", _current_level - 1, correct)
	if not correct:
		_lives = maxi(0, _lives - 1)
		_update_lives_ui()

	_choice_a.disabled = true
	_choice_b.disabled = true

	var result_text := str(res.get("text", ""))
	_pending_result_text = result_text
	_phase = Phase.RESULT
	_hint_label.visible = true
	_hint_label.text = "Нажмите для продолжения"

	_set_choices_visible(false)
	_start_typewriter(_pending_result_text)

	if _lives <= 0:
		_pending_next_level = -1
	else:
		_pending_next_level = _current_level + 1
		_mark_level_completed(_current_level)


func _continue_after_result() -> void:
	if _lives <= 0:
		_phase = Phase.GAME_OVER
		_hint_label.visible = true
		_hint_label.text = "Нажмите для продолжения"
		_start_typewriter("Ты потерял все жизни. Пока что это проигрыш (финал добавим позже).")
		return

	if _pending_next_level <= 6:
		_start_level(_pending_next_level)
	else:
		_phase = Phase.FINISHED
		_hint_label.visible = false
		_set_choices_visible(false)
		# Финальная сцена.
		var mgr := _UIManagerScript.get_instance()
		if mgr != null and not mgr.is_paused() and not final_scene_path.is_empty():
			await mgr.transition_to_scene(final_scene_path)
		else:
			_go_level_select()


func _mark_level_completed(level_idx: int) -> void:
	var lp := get_tree().root.get_node_or_null("LevelProgress")
	if lp == null:
		return
	lp.call("notify_level_completed", level_idx - 1)


func _set_choices_visible(v: bool) -> void:
	_choice_a.visible = v
	_choice_b.visible = v


func _on_typewriter_complete() -> void:
	# Показываем кнопки выбора только после полного текста диктора.
	if _phase != Phase.CHOICE:
		return
	if _choices_unlocked:
		return
	_choices_unlocked = true

	_set_choices_visible(true)
	_choice_a.disabled = false
	_choice_b.disabled = false

	# Лёгкая анимация появления.
	var base_a := _choice_a.modulate
	var base_b := _choice_b.modulate
	_choice_a.modulate = Color(base_a.r, base_a.g, base_a.b, 0.0)
	_choice_b.modulate = Color(base_b.r, base_b.g, base_b.b, 0.0)
	_choice_a.scale = Vector2(0.98, 0.98)
	_choice_b.scale = Vector2(0.98, 0.98)

	var tw := get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(_choice_a, "modulate", Color(base_a.r, base_a.g, base_a.b, 1.0), 0.18)
	tw.tween_property(_choice_b, "modulate", Color(base_b.r, base_b.g, base_b.b, 1.0), 0.18)
	tw.tween_property(_choice_a, "scale", Vector2.ONE, 0.18)
	tw.tween_property(_choice_b, "scale", Vector2.ONE, 0.18)


func _update_lives_ui() -> void:
	_heart1.visible = _lives >= 1
	_heart2.visible = _lives >= 2
	_heart3.visible = _lives >= 3


func _go_level_select() -> void:
	if level_select_scene_path.is_empty():
		return
	var run := get_tree().root.get_node_or_null("RunState")
	if run != null and run is _RunStateScript:
		(run as _RunStateScript).clear_run()
	var lp := get_tree().root.get_node_or_null("LevelProgress")
	if lp:
		lp.call("begin_play_level", _current_level - 1)
	get_tree().change_scene_to_file(level_select_scene_path)


func _on_back_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	_go_level_select()


func _on_settings_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if settings_scene_path.is_empty():
		return
	var run := get_tree().root.get_node_or_null("RunState")
	if run != null and run is _RunStateScript:
		(run as _RunStateScript).mark_return_from_settings(_current_level - 1, _lives)
	var nav := get_tree().root.get_node_or_null("NavigationState")
	if nav:
		nav.call("set_return_scene", _LEVEL_SCENE_PATH)
	var lp := get_tree().root.get_node_or_null("LevelProgress")
	if lp:
		lp.call("begin_play_level", _current_level - 1)
	get_tree().change_scene_to_file(settings_scene_path)


func _start_typewriter(full: String) -> void:
	_line_plain = full
	_dialogue_label.text = full
	_dialogue_label.visible_characters = 0
	_typing = true
	_type_timer.wait_time = typewriter_char_delay
	_type_timer.start()
	_narrator_speak()


func _finish_line_typing() -> void:
	_type_timer.stop()
	_typing = false
	_dialogue_label.visible_characters = -1
	_dialogue_label.text = _line_plain
	_narrator_idle()
	_on_typewriter_complete()


func _on_typewriter_tick() -> void:
	var shown: int = _dialogue_label.visible_characters
	if shown < 0:
		shown = 0
	shown += 1
	var n: int = _line_plain.length()
	if n <= 0:
		_type_timer.stop()
		_typing = false
		_narrator_idle()
		_on_typewriter_complete()
		return
	if shown >= n:
		_dialogue_label.visible_characters = -1
		_type_timer.stop()
		_typing = false
		_narrator_idle()
		_on_typewriter_complete()
	else:
		_dialogue_label.visible_characters = shown


func _narrator_speak() -> void:
	if _portrait and _portrait.has_method("play_looping"):
		_portrait.call("play_looping")


func _narrator_idle() -> void:
	if _portrait and _portrait.has_method("stop_idle"):
		_portrait.call("stop_idle")


func _load_levels_text() -> void:
	_levels.clear()
	_intro_text = "Добро пожаловать!"
	if levels_text_path.is_empty():
		push_error("levels_text_path is empty. Set it to res://levels.txt")
		return
	if not FileAccess.file_exists(levels_text_path):
		push_error("Levels file not found in export: %s" % levels_text_path)
		return
	var raw := FileAccess.get_file_as_string(levels_text_path)
	if raw.is_empty():
		push_error("Levels file is empty or failed to read: %s" % levels_text_path)
		return
	var lines := raw.split("\n", false)

	var cur_level: int = -1
	var buf: PackedStringArray = []
	for ln in lines:
		var line := ln.strip_edges()
		if line.begins_with("Уровень "):
			if cur_level >= 0:
				_parse_level_block(cur_level, buf)
			buf.clear()
			cur_level = _parse_level_index(line)
			buf.append(line)
			continue
		if cur_level >= 0:
			buf.append(line)
		# intro:
		if line.begins_with("Слова диктора:"):
			_intro_text = _strip_quotes(line.replace("Слова диктора:", "").strip_edges())
	if cur_level >= 0:
		_parse_level_block(cur_level, buf)


func _parse_level_index(header_line: String) -> int:
	# "Уровень 3 – ..." or "Уровень 3 - ..."
	var parts := header_line.split(" ", false)
	if parts.size() < 2:
		return -1
	return int(parts[1])


func _parse_level_block(level_idx: int, block_lines: PackedStringArray) -> void:
	if level_idx <= 0:
		return
	if level_idx > 6:
		return

	var prompt := ""
	var options: Array[String] = ["", ""]
	var r1 := {"text": "", "correct": false}
	var r2 := {"text": "", "correct": false}

	var i := 0
	while i < block_lines.size():
		var l := str(block_lines[i]).strip_edges()
		if l.begins_with("Объяснение диктора:") and prompt.is_empty():
			prompt = _strip_quotes(l.replace("Объяснение диктора:", "").strip_edges())
		elif l.begins_with("1)"):
			options[0] = l.replace("1)", "").strip_edges().trim_suffix(";")
		elif l.begins_with("2)"):
			options[1] = l.replace("2)", "").strip_edges().trim_suffix(";")
		elif l.begins_with("Если игрок выбирает 1"):
			var parsed := _parse_result_block(block_lines, i + 1)
			r1 = parsed
		elif l.begins_with("Если игрок выбирает 2"):
			var parsed := _parse_result_block(block_lines, i + 1)
			r2 = parsed
		i += 1

	_levels[level_idx] = {
		"prompt": prompt,
		"options": options,
		"result_1": r1,
		"result_2": r2,
	}


func _parse_result_block(lines: PackedStringArray, start_idx: int) -> Dictionary:
	var out := {"text": "", "correct": false}
	var chunks: PackedStringArray = []
	var i := start_idx
	while i < lines.size():
		var l := str(lines[i]).strip_edges()
		if l.begins_with("Если игрок выбирает"):
			break
		if l.begins_with("Уровень "):
			break
		if l.begins_with("________________________________"):
			break
		if not l.is_empty():
			if l.begins_with("Объяснение диктора:"):
				l = l.replace("Объяснение диктора:", "").strip_edges()
			chunks.append(_strip_quotes(l))
		i += 1

	var text := "\n".join(chunks)
	out["text"] = text
	out["correct"] = _guess_correct(text)
	return out


func _guess_correct(text: String) -> bool:
	var t := text.to_lower()
	return t.find("победа") >= 0 or t.find("успех") >= 0 or t.find("отлично") >= 0 or t.find("правильно") >= 0 or t.find("успеш") >= 0


func _strip_quotes(s: String) -> String:
	var out := s.strip_edges()
	out = out.trim_prefix("“").trim_suffix("”")
	out = out.trim_prefix("\"").trim_suffix("\"")
	return out
