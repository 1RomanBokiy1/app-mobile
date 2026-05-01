extends Control
## Игровая сцена уровней: вступление (уровень 0), затем уровни 1..6 с выбором из 2 ответов и жизнями.

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _RunStateScript = preload("res://shared/run_state.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var level_select_scene_path: String = "res://scenes/main_menu.tscn"
@export_file("*.tscn") var settings_scene_path: String = "res://scenes/settings.tscn"
@export_file("*.tscn") var final_scene_path: String = "res://scenes/final_scene.tscn"
@export_file("*.txt") var levels_text_path: String = "res://levels.txt"
@export var city_stages: Array[Texture2D] = []
@export var correct_answer_background: Texture2D
@export var wrong_answer_background: Texture2D
@export var level_1_correct_answer_background: Texture2D
@export_range(0.3, 6.0, 0.05) var intro_reveal_duration: float = 1.1
@export_range(0.2, 3.0, 0.05) var answer_bg_fade_duration: float = 1.1
@export_range(0.1, 2.0, 0.05) var result_stage_delay: float = 0.28
@export_range(0.1, 2.0, 0.05) var ui_fade_duration: float = 0.36
@export_range(10, 200, 1) var intro_cloud_count: int = 60
@export_range(0.3, 3.0, 0.05) var intro_cloud_scatter_duration: float = 1.25

const _LEVEL_BG_BY_INDEX: Dictionary = {
	1: "res://assets/sprites/bg_level_1.jpg",
	# 2: "res://assets/sprites/bg_level_2.png",
	# 3: "res://assets/sprites/bg_level_3.png",
	# ...
}

const _INTRO_CLOUD_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/sprites/cloud_pink_1.png",
	"res://assets/sprites/cloud_pink_2.png",
	"res://assets/sprites/cloud_violet_1.png",
]
const _LEVEL_1_CORRECT_BG_PATHS: Array[String] = [
	"res://assets/sprites/bg_level_1_correct.jpg",
	"res://assets/sprites/bg_level_1_correct.jpeg",
	"res://assets/sprites/bg_level_1_correct.png",
]

const _LEVEL_SCENE_PATH: String = "res://scenes/level_scene.tscn"

@export_range(0.012, 0.08, 0.002) var typewriter_char_delay: float = 0.028

@onready var _btn_back: Button = %BtnBack
@onready var _btn_settings: Button = %BtnSettings
@onready var _bg_city: TextureRect = %BgCity
@onready var _bg_city_next: TextureRect = %BgCityNext
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
@onready var _ui_root: MarginContainer = $UiRoot
@onready var _upper_row: VBoxContainer = $"UiRoot/MainColumn/UpperRow"
@onready var _choices_col: VBoxContainer = $"UiRoot/MainColumn/ChoicesCol"
@onready var _result_spacer: Control = %ResultSpacer
@onready var _result_status_label: Label = %ResultStatusLabel
@onready var _btn_next_level: Button = %BtnNextLevelBottom
@onready var _intro_clouds: Control = %IntroClouds

enum Phase { INTRO, CHOICE, RESULT, GAME_OVER, FINISHED }

var _phase: int = Phase.INTRO
var _levels: Dictionary = {} # int -> Dictionary
var _intro_text: String = ""
var _current_level: int = 1
var _lives: int = 3
var _correct_answers: int = 0
var _typing: bool = false
var _line_plain: String = ""
var _type_timer: Timer
var _pending_result_text: String = ""
var _pending_next_level: int = -1
var _choices_unlocked: bool = false
var _restore_after_settings: bool = false
var _restored_scene_state: Dictionary = {}
var current_city_stage: int = 0
var _last_answer_correct: bool = false
var _leaving_scene: bool = false


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
	_btn_next_level.pressed.connect(_on_next_level_pressed)
	_MenuUi.bind_press_feedback(_choice_a)
	_MenuUi.bind_press_feedback(_choice_b)
	_MenuUi.bind_press_feedback(_btn_next_level)

	_type_timer = Timer.new()
	_type_timer.one_shot = false
	add_child(_type_timer)
	_type_timer.timeout.connect(_on_typewriter_tick)

	_load_levels_text()
	_reset_run_from_selection()
	_init_level_complete_ui()
	var mb = _MusicBusScript.new()
	mb.call("play_level")
	if _restore_after_settings:
		_restore_scene_state()
	else:
		_prepare_intro_visuals()
		await _play_intro_sequence()
		_show_intro()


func _prepare_intro_visuals() -> void:
	_set_choices_visible(false)
	_choice_a.disabled = true
	_choice_b.disabled = true
	# Жизни всегда видны (интро в levels.txt не упоминает «сердца» — раньше они не появлялись).
	_update_lives_ui()
	_heart1.modulate = Color(1, 1, 1, 0.0)
	_heart2.modulate = Color(1, 1, 1, 0.0)
	_heart3.modulate = Color(1, 1, 1, 0.0)
	# Текст и подсказка сразу читаемы; печать не должна быть с alpha=0.
	_name_label.modulate = Color(1, 1, 1, 1)
	_dialogue_label.modulate = Color(1, 1, 1, 1)
	_hint_label.modulate = Color(1, 1, 1, 1)
	_portrait.modulate = Color(1, 1, 1, 0.0)
	_ui_root.modulate = Color(1, 1, 1, 0.0)


func _init_level_complete_ui() -> void:
	_result_status_label.visible = false
	_result_status_label.modulate = Color(1, 1, 1, 1)
	_btn_next_level.modulate = Color(1, 1, 1, 0.0)
	_btn_next_level.visible = false
	_btn_next_level.disabled = true
	_result_spacer.custom_minimum_size.y = 0.0
	_apply_city_stage_visual()


func _play_intro_sequence() -> void:
	if _leaving_scene:
		return
	_apply_level_background(_current_level)
	_bg_city.modulate = Color(1, 1, 1, 1.0)
	_intro_clouds.visible = true
	_intro_clouds.modulate = Color(1, 1, 1, 1)
	_build_intro_clouds()

	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	var cloud_idx: int = 0
	for child in _intro_clouds.get_children():
		if child is TextureRect:
			var cloud := child as TextureRect
			var from_center: Vector2 = (cloud.global_position + (cloud.size * 0.5)) - (get_viewport_rect().size * 0.5)
			if from_center.length() < 1.0:
				from_center = Vector2(1.0 if cloud_idx % 2 == 0 else -1.0, 0.25)
			var dir := from_center.normalized()
			var distance := 760.0 + float(cloud_idx % 10) * 22.0
			var delay := minf(0.35, float(cloud_idx) * 0.006)
			tw.parallel().tween_property(cloud, "position", dir * distance, intro_cloud_scatter_duration).set_delay(delay)
			cloud_idx += 1
	tw.parallel().tween_property(_intro_clouds, "modulate", Color(1, 1, 1, 0), intro_reveal_duration)
	await tw.finished
	if _leaving_scene:
		return
	_intro_clouds.visible = false

	var tw_ui := get_tree().create_tween()
	tw_ui.set_trans(Tween.TRANS_QUAD)
	tw_ui.set_ease(Tween.EASE_OUT)
	tw_ui.tween_property(_ui_root, "modulate", Color(1, 1, 1, 1), 0.72)
	tw_ui.parallel().tween_property(_portrait, "modulate", Color(1, 1, 1, 1), 0.62)
	tw_ui.parallel().tween_property(_heart1, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.14)
	tw_ui.parallel().tween_property(_heart2, "modulate", Color(1, 1, 1, 1), 0.56).set_delay(0.2)
	tw_ui.parallel().tween_property(_heart3, "modulate", Color(1, 1, 1, 1), 0.62).set_delay(0.26)
	await tw_ui.finished


func _apply_level_background(level_idx: int) -> void:
	var p := str(_LEVEL_BG_BY_INDEX.get(level_idx, ""))
	var tex := _load_first_existing_texture([
		p,
		p.replace(".jpg", ".png"),
		p.replace(".png", ".jpg"),
	])
	if tex != null:
		_bg_city.texture = tex


func _build_intro_clouds() -> void:
	# Пересобираем облака на интро: много, разный масштаб/прозрачность.
	for c in _intro_clouds.get_children():
		c.queue_free()

	var textures: Array[Texture2D] = []
	for p in _INTRO_CLOUD_TEXTURE_PATHS:
		if ResourceLoader.exists(p):
			var t := load(p)
			if t is Texture2D:
				textures.append(t)
	if textures.is_empty():
		return

	var vp := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(intro_cloud_count):
		var cloud_rect := TextureRect.new()
		cloud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud_rect.texture = textures[rng.randi_range(0, textures.size() - 1)]
		cloud_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		cloud_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cloud_rect.size = (cloud_rect.texture.get_size() if cloud_rect.texture != null else Vector2(256, 256))
		cloud_rect.pivot_offset = cloud_rect.size * 0.5
		var sc := rng.randf_range(0.8, 1.85)
		cloud_rect.scale = Vector2(sc, sc)
		var a := rng.randf_range(0.55, 0.95)
		cloud_rect.modulate = Color(1, 1, 1, a)
		# По всему экрану + небольшой запас за края.
		cloud_rect.position = Vector2(rng.randf_range(-vp.x * 0.2, vp.x * 1.2), rng.randf_range(-vp.y * 0.2, vp.y * 1.2))
		cloud_rect.z_index = i
		_intro_clouds.add_child(cloud_rect)


func _load_first_existing_texture(paths: Array[String]) -> Texture2D:
	for p in paths:
		var path := str(p)
		if path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path)
		if tex is Texture2D:
			return tex
	return null


func _exit_tree() -> void:
	_leaving_scene = true
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
	if _btn_next_level.visible:
		buttons.append(_btn_next_level)
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
	_restore_after_settings = false
	_restored_scene_state.clear()
	if run != null and run is _RunStateScript and (run as _RunStateScript).consume_restore():
		_current_level = int((run as _RunStateScript).current_level_index) + 1
		_lives = int((run as _RunStateScript).lives)
		_correct_answers = int((run as _RunStateScript).correct_answers)
		_restored_scene_state = (run as _RunStateScript).take_level_scene_state()
		_restore_after_settings = true
	else:
		if lp:
			_current_level = int(lp.call("take_pending_level_index", 0)) + 1
		_current_level = clampi(_current_level, 1, 6)
		_lives = 3
		_correct_answers = 0
		if run != null and run is _RunStateScript:
			(run as _RunStateScript).start_new_run(_current_level - 1, _lives, _correct_answers)
	_current_level = clampi(_current_level, 1, 6)
	_update_lives_ui()
	_choices_unlocked = false


func _restore_scene_state() -> void:
	_intro_clouds.visible = false
	_intro_clouds.modulate = Color(1, 1, 1, 0)
	_ui_root.modulate = Color(1, 1, 1, 1)
	_portrait.modulate = Color(1, 1, 1, 1)
	if _restored_scene_state.is_empty():
		_start_level(_current_level)
		return
	_phase = int(_restored_scene_state.get("phase", Phase.CHOICE))
	_current_level = clampi(int(_restored_scene_state.get("current_level", _current_level)), 1, 6)
	_lives = clampi(int(_restored_scene_state.get("lives", _lives)), 0, 3)
	_correct_answers = maxi(0, int(_restored_scene_state.get("correct_answers", _correct_answers)))
	_pending_result_text = str(_restored_scene_state.get("pending_result_text", _pending_result_text))
	_pending_next_level = int(_restored_scene_state.get("pending_next_level", _pending_next_level))
	_choices_unlocked = bool(_restored_scene_state.get("choices_unlocked", _choices_unlocked))
	current_city_stage = clampi(int(_restored_scene_state.get("current_city_stage", current_city_stage)), 0, 3)
	_last_answer_correct = bool(_restored_scene_state.get("last_answer_correct", false))
	_name_label.text = str(_restored_scene_state.get("name_text", "Вицемэрио"))
	_hint_label.visible = bool(_restored_scene_state.get("hint_visible", _hint_label.visible))
	_hint_label.text = str(_restored_scene_state.get("hint_text", _hint_label.text))
	_dialogue_label.text = str(_restored_scene_state.get("dialogue_text", ""))
	_dialogue_label.visible_characters = int(_restored_scene_state.get("visible_characters", -1))
	_line_plain = str(_restored_scene_state.get("line_plain", _dialogue_label.text))
	_typing = bool(_restored_scene_state.get("typing", false))
	if _phase == Phase.RESULT and not _restored_scene_state.has("last_answer_correct") and not _pending_result_text.is_empty():
		# Фолбэк для старых/неполных сохранений: пытаемся восстановить признак правильного ответа из текста результата.
		_last_answer_correct = _guess_correct(_pending_result_text)
	_choice_a_txt.text = str(_restored_scene_state.get("choice_a_text", _choice_a_txt.text))
	_choice_b_txt.text = str(_restored_scene_state.get("choice_b_text", _choice_b_txt.text))
	_choice_a.visible = bool(_restored_scene_state.get("choice_a_visible", _choice_a.visible))
	_choice_b.visible = bool(_restored_scene_state.get("choice_b_visible", _choice_b.visible))
	_choice_a.disabled = bool(_restored_scene_state.get("choice_a_disabled", _choice_a.disabled))
	_choice_b.disabled = bool(_restored_scene_state.get("choice_b_disabled", _choice_b.disabled))
	_update_lives_ui()
	if _typing:
		if _dialogue_label.visible_characters < 0:
			_dialogue_label.visible_characters = 0
		_type_timer.wait_time = typewriter_char_delay
		_type_timer.start()
		_narrator_speak()
	else:
		_type_timer.stop()
		_narrator_idle()
	if _phase == Phase.RESULT:
		# Если ушли в настройки в промежутке между анимацией результата и запуском печати,
		# в сохранении мог остаться старый текст вопроса. Жёстко восстанавливаем текст результата.
		if not _pending_result_text.is_empty() and _line_plain != _pending_result_text:
			_line_plain = _pending_result_text
			_dialogue_label.text = _pending_result_text
			if _typing:
				_dialogue_label.visible_characters = maxi(0, _dialogue_label.visible_characters)
			else:
				_dialogue_label.visible_characters = -1
		_show_result_controls(_last_answer_correct)
		_apply_answer_background(_last_answer_correct)
		_restore_saved_background_if_any()
		if not _typing:
			_btn_next_level.modulate = Color(1, 1, 1, 1)
			_btn_next_level.visible = true
			_btn_next_level.disabled = false
	else:
		_result_status_label.visible = false
		_btn_next_level.visible = false
		_btn_next_level.disabled = true
		_apply_city_stage_visual()
		_show_question_ui(true)


func _show_intro() -> void:
	_phase = Phase.INTRO
	_show_question_ui(true)
	_result_status_label.visible = false
	_btn_next_level.visible = false
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
	_show_question_ui(true)
	_upper_row.modulate = Color(1, 1, 1, 1)
	_choices_col.modulate = Color(1, 1, 1, 1)
	_result_spacer.custom_minimum_size.y = 0.0
	_result_status_label.visible = false
	_btn_next_level.visible = false

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
	_last_answer_correct = correct
	var lp_set := get_tree().root.get_node_or_null("LevelProgress")
	if lp_set:
		lp_set.call("set_level_result", _current_level - 1, correct)
	if not correct:
		_lives = maxi(0, _lives - 1)
		_update_lives_ui()
	else:
		_correct_answers += 1

	_choice_a.disabled = true
	_choice_b.disabled = true

	var result_text := str(res.get("text", ""))
	_pending_result_text = result_text
	if correct:
		_pending_next_level = _current_level + 1
		_mark_level_completed(_current_level)
		current_city_stage = mini(current_city_stage + 1, 3)
	else:
		_pending_next_level = -1 if _lives <= 0 else _current_level + 1
	_phase = Phase.RESULT
	_set_choices_visible(false)
	await _show_result_flow(correct)
	_start_typewriter(_pending_result_text)


func _continue_after_result() -> void:
	if _lives <= 0:
		_phase = Phase.FINISHED
		_hint_label.visible = false
		_set_choices_visible(false)
		_store_hall_of_fame_result()
		var mgr_game_over := _UIManagerScript.get_instance()
		if mgr_game_over != null and not mgr_game_over.is_paused() and not final_scene_path.is_empty():
			await mgr_game_over.transition_to_scene(final_scene_path)
		else:
			_go_level_select()
		return

	if _pending_next_level <= 6:
		_start_level(_pending_next_level)
	else:
		_phase = Phase.FINISHED
		_hint_label.visible = false
		_set_choices_visible(false)
		_store_hall_of_fame_result()
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


func _show_result_controls(correct: bool) -> void:
	_show_question_ui(true)
	_choices_col.visible = false
	_hint_label.visible = false
	_result_status_label.text = "Уровень пройден!" if correct else "Уровень не пройден"
	_result_status_label.visible = true
	_result_status_label.modulate = Color(1, 1, 1, 0.0)
	_btn_next_level.visible = true
	_btn_next_level.modulate = Color(1, 1, 1, 0.0) # Кнопку покажем только после объяснения.
	_btn_next_level.disabled = true

	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_result_status_label, "modulate", Color(1, 1, 1, 1), ui_fade_duration)
	await tw.finished


func _show_result_flow(correct: bool) -> void:
	if _leaving_scene:
		return
	var tw_hide := get_tree().create_tween()
	tw_hide.set_trans(Tween.TRANS_QUAD)
	tw_hide.set_ease(Tween.EASE_IN_OUT)
	tw_hide.tween_property(_upper_row, "modulate", Color(1, 1, 1, 0.0), ui_fade_duration)
	tw_hide.parallel().tween_property(_choices_col, "modulate", Color(1, 1, 1, 0.0), ui_fade_duration)
	await tw_hide.finished
	if _leaving_scene:
		return
	_show_question_ui(false)
	_hint_label.visible = false
	_result_status_label.visible = false
	_btn_next_level.visible = false
	_btn_next_level.disabled = true
	_result_spacer.custom_minimum_size.y = 0.0
	await _animate_answer_background(correct)
	if _leaving_scene:
		return
	await get_tree().create_timer(result_stage_delay).timeout
	if _leaving_scene:
		return
	_show_result_controls(correct)
	_show_question_ui(true)
	_choices_col.visible = false
	_result_spacer.custom_minimum_size.y = 94.0
	_upper_row.modulate = Color(1, 1, 1, 0.0)
	var tw_show := get_tree().create_tween()
	tw_show.set_trans(Tween.TRANS_QUAD)
	tw_show.set_ease(Tween.EASE_OUT)
	tw_show.tween_property(_upper_row, "modulate", Color(1, 1, 1, 1), ui_fade_duration)
	await tw_show.finished


func _animate_answer_background(correct: bool) -> void:
	if _leaving_scene:
		return
	var target_texture: Texture2D = null
	if correct and _current_level == 1:
		target_texture = _get_level_1_correct_answer_background()
	elif correct and correct_answer_background != null:
		target_texture = correct_answer_background
	elif not correct and wrong_answer_background != null:
		target_texture = wrong_answer_background
	elif correct and current_city_stage >= 0 and current_city_stage < city_stages.size():
		target_texture = city_stages[current_city_stage]
	elif not correct and current_city_stage > 0 and current_city_stage - 1 < city_stages.size():
		target_texture = city_stages[current_city_stage - 1]
	if target_texture == null:
		_apply_city_stage_visual()
		return

	# Кроссфейд без "щелчка": второй слой нарастает поверх первого.
	if _bg_city_next != null:
		_bg_city_next.texture = target_texture
		_bg_city_next.modulate = Color(1, 1, 1, 0.0)
		var tw := get_tree().create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_bg_city, "modulate", Color(1, 1, 1, 0.0), answer_bg_fade_duration)
		tw.parallel().tween_property(_bg_city_next, "modulate", Color(1, 1, 1, 1.0), answer_bg_fade_duration)
		await tw.finished
		if _leaving_scene:
			return
		_bg_city.texture = target_texture
		_bg_city.modulate = Color(1, 1, 1, 1.0)
		_bg_city_next.texture = null
		_bg_city_next.modulate = Color(1, 1, 1, 0.0)
	else:
		var tw_out := get_tree().create_tween()
		tw_out.set_trans(Tween.TRANS_QUAD)
		tw_out.set_ease(Tween.EASE_IN_OUT)
		tw_out.tween_property(_bg_city, "modulate", Color(1, 1, 1, 0.0), answer_bg_fade_duration * 0.5)
		await tw_out.finished
		_bg_city.texture = target_texture
		var tw_in := get_tree().create_tween()
		tw_in.set_trans(Tween.TRANS_QUAD)
		tw_in.set_ease(Tween.EASE_IN_OUT)
		tw_in.tween_property(_bg_city, "modulate", Color(1, 1, 1, 1.0), answer_bg_fade_duration * 0.5)
		await tw_in.finished


func _apply_city_stage_visual() -> void:
	if current_city_stage >= 0 and current_city_stage < city_stages.size() and city_stages[current_city_stage] != null:
		_bg_city.texture = city_stages[current_city_stage]
		_bg_city.modulate = Color(1, 1, 1, 1)
	else:
		var alpha_by_stage := [0.42, 0.28, 0.16, 0.0]
		var idx := clampi(current_city_stage, 0, alpha_by_stage.size() - 1)
		var alpha: float = alpha_by_stage[idx]
		_bg_city.modulate = Color(1, 1, 1, 1.0 - alpha)


func _apply_answer_background(correct: bool) -> void:
	var level_1_correct_bg := _get_level_1_correct_answer_background()
	if correct and _current_level == 1 and level_1_correct_bg != null:
		_bg_city.texture = level_1_correct_bg
		_bg_city.modulate = Color(1, 1, 1, 1)
		return
	if correct and correct_answer_background != null:
		_bg_city.texture = correct_answer_background
		_bg_city.modulate = Color(1, 1, 1, 1)
		return
	if not correct and wrong_answer_background != null:
		_bg_city.texture = wrong_answer_background
		_bg_city.modulate = Color(1, 1, 1, 1)
		return
	_apply_city_stage_visual()


func _on_next_level_pressed() -> void:
	if _phase != Phase.RESULT:
		return
	_result_status_label.visible = false
	_btn_next_level.visible = false
	_btn_next_level.disabled = true
	_continue_after_result()


func _show_question_ui(show_ui: bool) -> void:
	_upper_row.visible = show_ui
	_choices_col.visible = show_ui


func _set_choices_visible(v: bool) -> void:
	_choice_a.visible = v
	_choice_b.visible = v


func _on_typewriter_complete() -> void:
	# Показываем кнопки выбора только после полного текста диктора.
	if _phase == Phase.CHOICE:
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
	elif _phase == Phase.RESULT and _btn_next_level.visible:
		var tw_btn := get_tree().create_tween()
		tw_btn.set_trans(Tween.TRANS_QUAD)
		tw_btn.set_ease(Tween.EASE_OUT)
		tw_btn.tween_property(_btn_next_level, "modulate", Color(1, 1, 1, 1), ui_fade_duration)
		await tw_btn.finished
		_btn_next_level.disabled = false


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
	_leaving_scene = true
	var run := get_tree().root.get_node_or_null("RunState")
	if run != null and run is _RunStateScript:
		var saved_dialogue_text: String = _dialogue_label.text
		var saved_line_plain: String = _line_plain
		var saved_visible_chars: int = _dialogue_label.visible_characters
		var saved_typing: bool = _typing
		var saved_bg_city_path: String = _get_texture_resource_path(_bg_city.texture)
		var saved_bg_city_next_path: String = _get_texture_resource_path(_bg_city_next.texture)
		# Защита от "битого" промежуточного стейта результата:
		# если уже в RESULT, но текст результата ещё не начал печататься,
		# сохраняем именно pending_result_text и считаем, что печать должна продолжиться.
		if _phase == Phase.RESULT and not _pending_result_text.is_empty() and saved_line_plain != _pending_result_text:
			saved_dialogue_text = _pending_result_text
			saved_line_plain = _pending_result_text
			saved_visible_chars = 0
			saved_typing = true
		(run as _RunStateScript).mark_return_from_settings(_current_level - 1, _lives, _correct_answers)
		(run as _RunStateScript).set_level_scene_state({
			"phase": _phase,
			"current_level": _current_level,
			"lives": _lives,
			"correct_answers": _correct_answers,
			"pending_result_text": _pending_result_text,
			"pending_next_level": _pending_next_level,
			"choices_unlocked": _choices_unlocked,
			"current_city_stage": current_city_stage,
			"last_answer_correct": _last_answer_correct,
			"name_text": _name_label.text,
			"hint_visible": _hint_label.visible,
			"hint_text": _hint_label.text,
			"dialogue_text": saved_dialogue_text,
			"visible_characters": saved_visible_chars,
			"line_plain": saved_line_plain,
			"typing": saved_typing,
			"bg_city_texture_path": saved_bg_city_path,
			"bg_city_modulate": _bg_city.modulate,
			"bg_city_next_texture_path": saved_bg_city_next_path,
			"bg_city_next_modulate": _bg_city_next.modulate,
			"choice_a_text": _choice_a_txt.text,
			"choice_b_text": _choice_b_txt.text,
			"choice_a_visible": _choice_a.visible,
			"choice_b_visible": _choice_b.visible,
			"choice_a_disabled": _choice_a.disabled,
			"choice_b_disabled": _choice_b.disabled
		})
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


func _store_hall_of_fame_result() -> void:
	var hall := get_tree().root.get_node_or_null("HallOfFame")
	if hall != null and hall.has_method("set_pending_correct_answers"):
		hall.call("set_pending_correct_answers", _correct_answers)


func _get_level_1_correct_answer_background() -> Texture2D:
	if level_1_correct_answer_background != null:
		return level_1_correct_answer_background
	return _load_first_existing_texture(_LEVEL_1_CORRECT_BG_PATHS)


func _restore_saved_background_if_any() -> void:
	var bg_path := str(_restored_scene_state.get("bg_city_texture_path", ""))
	if not bg_path.is_empty():
		var bg_tex := _load_first_existing_texture([bg_path])
		if bg_tex != null:
			_bg_city.texture = bg_tex
	if _restored_scene_state.has("bg_city_modulate"):
		_bg_city.modulate = _restored_scene_state.get("bg_city_modulate", _bg_city.modulate)
	var bg_next_path := str(_restored_scene_state.get("bg_city_next_texture_path", ""))
	if not bg_next_path.is_empty():
		var bg_next_tex := _load_first_existing_texture([bg_next_path])
		_bg_city_next.texture = bg_next_tex
	elif _restored_scene_state.has("bg_city_next_texture_path"):
		_bg_city_next.texture = null
	if _restored_scene_state.has("bg_city_next_modulate"):
		_bg_city_next.modulate = _restored_scene_state.get("bg_city_next_modulate", _bg_city_next.modulate)


func _get_texture_resource_path(tex: Texture2D) -> String:
	if tex == null:
		return ""
	return tex.resource_path
