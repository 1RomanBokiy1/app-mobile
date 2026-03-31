extends Control

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

@onready var _title: Label = %FinalTitle
@onready var _text: RichTextLabel = %FinalText
@onready var _panel: PanelContainer = %FinalPanel
@onready var _btn_home: Button = %BtnHome
@onready var _ui_full: Control = $UiLayer/UiFull


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
	_MenuUi.bind_press_feedback(_btn_home)
	_btn_home.pressed.connect(_on_home_pressed)

	_apply_variant()
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


func _apply_variant() -> void:
	# Вариант выбираем по оставшимся жизням в RunState, если он есть.
	var run := get_tree().root.get_node_or_null("RunState")
	var lives := 3
	if run != null:
		lives = int(run.get("lives"))

	if lives <= 0:
		_title.text = "Неудача"
		_text.text = "Ты дошёл до финала, но потерял все жизни.\nПопробуй ещё раз и будь внимательнее."
	elif lives == 3:
		_title.text = "Поздравляем!"
		_text.text = "Ты прошёл все уровни и доказал, что умеешь управлять городом D‑Bus City.\nСпасибо за игру!"
	else:
		_title.text = "Надо ещё подумать"
		_text.text = "Ты прошёл все уровни, но некоторые решения были спорными.\nПопробуй перепройти и собрать идеальный результат."


func _play_enter_anim() -> void:
	var base := _panel.modulate
	_panel.modulate = Color(base.r, base.g, base.b, 0.0)
	_panel.scale = Vector2(0.96, 0.96)
	var tw := get_tree().create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate", Color(base.r, base.g, base.b, 1.0), 0.26)
	tw.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.26)


func _on_home_pressed() -> void:
	if get_tree().paused:
		return
	if main_menu_scene_path.is_empty():
		return
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.reset_fade_blocking()
		await mgr.transition_to_scene(main_menu_scene_path)
	else:
		get_tree().change_scene_to_file(main_menu_scene_path)

