extends Control

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

@onready var _entries_root: VBoxContainer = %EntriesRoot
@onready var _entry_template: PanelContainer = %EntryTemplate
@onready var _btn_back: Button = %BtnBack

const _TOTAL_LEVELS: int = 6
const _TOP_1_COLOR := Color(1.0, 0.9, 0.45, 1.0)
const _TOP_2_COLOR := Color(0.8, 0.88, 1.0, 1.0)
const _TOP_3_COLOR := Color(0.98, 0.78, 0.58, 1.0)
const _DEFAULT_RANK_COLOR := Color(0.84, 0.91, 1.0, 1.0)


func _ready() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	var mb = _MusicBusScript.new()
	mb.call("play_menu")
	_MenuUi.bind_press_feedback(_btn_back)
	_btn_back.pressed.connect(_on_back_pressed)
	_rebuild_hall_list()


func _exit_tree() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _rebuild_hall_list() -> void:
	for child in _entries_root.get_children():
		if child == _entry_template:
			continue
		child.queue_free()
	_entry_template.visible = false
	var hall := get_node_or_null("/root/HallOfFame")
	if hall == null:
		return
	var entries: Array = hall.call("get_entries")
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


func _on_back_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if main_menu_scene_path.is_empty():
		return
	await mgr.transition_to_scene(main_menu_scene_path)
