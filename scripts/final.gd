extends Control

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

@onready var _panel_entry: PanelContainer = %EntryPanel
@onready var _entry_layout: VBoxContainer = %EntryLayout
@onready var _panel_hall: PanelContainer = %HallPanel
@onready var _name_input: LineEdit = %NameInput
@onready var _btn_save: Button = %BtnSave
@onready var _btn_home: Button = %BtnHome
@onready var _result_text: Label = %ResultText
@onready var _entries_root: VBoxContainer = %EntriesRoot
@onready var _entry_template: PanelContainer = %EntryTemplate
@onready var _fireworks_layer: Control = %FireworksLayer
@onready var _ui_full: Control = $UiLayer/UiFull

var _is_saved: bool = false
var _last_score: int = 0
const _KEYBOARD_RETRY_DELAYS := [0.0, 0.08, 0.2, 0.4]
const _TOTAL_LEVELS: int = 6
const _TOP_1_COLOR := Color(1.0, 0.9, 0.45, 1.0)
const _TOP_2_COLOR := Color(0.8, 0.88, 1.0, 1.0)
const _TOP_3_COLOR := Color(0.98, 0.78, 0.58, 1.0)
const _DEFAULT_RANK_COLOR := Color(0.84, 0.91, 1.0, 1.0)
const _FIREWORK_COLORS := [
	Color(1.0, 0.86, 0.35, 1.0),
	Color(0.58, 0.86, 1.0, 1.0),
	Color(1.0, 0.62, 0.72, 1.0),
	Color(0.65, 1.0, 0.78, 1.0)
]


func _ready() -> void:
	if not get_viewport().size_changed.is_connected(_ensure_ui_layer_geometry):
		get_viewport().size_changed.connect(_ensure_ui_layer_geometry)
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.reset_fade_blocking()
		mgr.register_game_ui(self)
	await get_tree().process_frame
	_ensure_ui_layer_geometry()
	var mb = _MusicBusScript.new()
	mb.call("play_menu")
	_MenuUi.bind_press_feedback(_btn_save)
	_MenuUi.bind_press_feedback(_btn_home)
	_btn_save.pressed.connect(_on_save_pressed)
	_btn_home.pressed.connect(_on_home_pressed)
	_name_input.text_submitted.connect(_on_name_submitted)
	_name_input.focus_entered.connect(_on_name_input_focus_entered)

	_last_score = _get_run_correct_answers()
	_result_text.text = "Ваш результат: %d правильных ответов" % _last_score
	_name_input.text = ""
	_show_entry_screen()
	_play_enter_anim()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_ensure_ui_layer_geometry):
		get_viewport().size_changed.disconnect(_ensure_ui_layer_geometry)
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _ensure_ui_layer_geometry() -> void:
	if _ui_full == null:
		return
	var r := get_viewport().get_visible_rect()
	_ui_full.set_position(r.position)
	_ui_full.set_size(r.size)


func _show_entry_screen() -> void:
	_entry_layout.visible = true
	_panel_hall.visible = false
	_play_fireworks_intro()
	call_deferred("_focus_name_input_with_retries")


func _focus_name_input_with_retries() -> void:
	if _name_input == null:
		return
	for delay_s in _KEYBOARD_RETRY_DELAYS:
		if delay_s > 0.0:
			await get_tree().create_timer(delay_s).timeout
		if not _entry_layout.visible or _panel_hall.visible:
			return
		_name_input.virtual_keyboard_enabled = true
		_name_input.editable = true
		_name_input.grab_focus()
		_show_virtual_keyboard()


func _on_name_input_focus_entered() -> void:
	if not _entry_layout.visible or _panel_hall.visible:
		return
	_show_virtual_keyboard()


func _show_virtual_keyboard() -> void:
	var kb_rect := Rect2i(_name_input.global_position, _name_input.size)
	DisplayServer.virtual_keyboard_show(_name_input.text, kb_rect)


func _show_hall_screen() -> void:
	_entry_layout.visible = false
	_panel_hall.visible = true
	DisplayServer.virtual_keyboard_hide()
	_rebuild_hall_list()


func _rebuild_hall_list() -> void:
	for child in _entries_root.get_children():
		if child == _entry_template:
			continue
		child.queue_free()
	var hall := get_node_or_null("/root/HallOfFame")
	if hall == null:
		return
	var entries: Array = hall.call("get_entries")
	_entry_template.visible = false
	for i in range(entries.size()):
		var item = entries[i]
		if not (item is Dictionary):
			continue
		var row := _entry_template.duplicate()
		row.visible = true
		var rank_label := row.get_node_or_null("EntryRow/RankValue") as Label
		var name_label := row.get_node_or_null("EntryRow/NameValue") as Label
		var score_label := row.get_node_or_null("EntryRow/ScoreValue") as Label
		var rank_text := "#%d" % (i + 1)
		var rank_color := _DEFAULT_RANK_COLOR
		if i == 0:
			rank_color = _TOP_1_COLOR
		elif i == 1:
			rank_color = _TOP_2_COLOR
		elif i == 2:
			rank_color = _TOP_3_COLOR
		if rank_label:
			rank_label.text = rank_text
			rank_label.add_theme_color_override("font_color", rank_color)
		if name_label:
			name_label.text = str((item as Dictionary).get("name", "Без имени"))
			name_label.add_theme_color_override("font_color", rank_color if i < 3 else Color.WHITE)
		if score_label:
			var score_value := int((item as Dictionary).get("correct_answers", 0))
			score_label.text = "%d/%d" % [score_value, _TOTAL_LEVELS]
			score_label.add_theme_color_override("font_color", rank_color)
		_entries_root.add_child(row)


func _play_enter_anim() -> void:
	var base := _panel_entry.modulate
	_panel_entry.modulate = Color(base.r, base.g, base.b, 0.0)
	_panel_entry.scale = Vector2(0.96, 0.96)
	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel_entry, "modulate", Color(base.r, base.g, base.b, 1.0), 0.24)
	tw.parallel().tween_property(_panel_entry, "scale", Vector2.ONE, 0.24)


func _on_save_pressed() -> void:
	if _is_saved:
		return
	var player_name := _name_input.text.strip_edges()
	if player_name.is_empty():
		_name_input.grab_focus()
		return
	var hall := get_node_or_null("/root/HallOfFame")
	if hall != null:
		hall.call("add_entry", player_name, _last_score)
	_is_saved = true
	_show_hall_screen()


func _on_name_submitted(_text: String) -> void:
	_on_save_pressed()


func _on_home_pressed() -> void:
	if get_tree().paused:
		return
	if main_menu_scene_path.is_empty():
		return
	DisplayServer.virtual_keyboard_hide()
	var hall := get_node_or_null("/root/HallOfFame")
	if hall != null and hall.has_method("clear_pending_correct_answers"):
		hall.call("clear_pending_correct_answers")
	var run := get_tree().root.get_node_or_null("RunState")
	if run != null and run.has_method("clear_run"):
		run.call("clear_run")
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.reset_fade_blocking()
		await mgr.transition_to_scene(main_menu_scene_path)
	else:
		get_tree().change_scene_to_file(main_menu_scene_path)


func _get_run_correct_answers() -> int:
	var hall := get_node_or_null("/root/HallOfFame")
	if hall == null:
		return 0
	return maxi(0, int(hall.call("get_pending_correct_answers")))


func _play_fireworks_intro() -> void:
	if _fireworks_layer == null:
		return
	for child in _fireworks_layer.get_children():
		child.queue_free()
	var panel_center := _panel_entry.global_position + (_panel_entry.size * 0.5)
	var left_origin := panel_center + Vector2(-220.0, -80.0)
	var right_origin := panel_center + Vector2(220.0, -80.0)
	_spawn_firework_burst(left_origin)
	_spawn_firework_burst(right_origin)
	await get_tree().create_timer(0.22).timeout
	_spawn_firework_burst(panel_center + Vector2(0.0, -140.0))


func _spawn_firework_burst(origin_global: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var origin_local := origin_global - _fireworks_layer.global_position
	for i in range(18):
		var spark := ColorRect.new()
		spark.color = _FIREWORK_COLORS[i % _FIREWORK_COLORS.size()]
		spark.custom_minimum_size = Vector2(12, 12)
		spark.size = Vector2(12, 12)
		spark.position = origin_local
		spark.pivot_offset = spark.size * 0.5
		_fireworks_layer.add_child(spark)

		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(120.0, 300.0)
		var target := spark.position + Vector2(cos(angle), sin(angle)) * distance

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(spark, "scale", Vector2(0.15, 0.15), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.finished.connect(func() -> void:
			if is_instance_valid(spark):
				spark.queue_free()
		)
