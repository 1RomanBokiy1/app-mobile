class_name MenuMain
extends Control

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")

@export_file("*.tscn") var play_scene_path: String = "res://scenes/level_scene.tscn"
@export_file("*.tscn") var settings_scene_path: String = "res://scenes/settings.tscn"
@export_file("*.tscn") var about_scene_path: String = "res://scenes/about_game.tscn"
@export_file("*.tscn") var level_select_scene_path: String = "res://scenes/level_select.tscn"

@onready var _btn_play: Button = %BtnPlay
@onready var _btn_level: Button = %BtnLevel
@onready var _btn_settings: Button = %BtnSettings
@onready var _btn_about: Button = %BtnAbout
@onready var _cloud_layer: Node = $CloudBackground/CloudLayer


func _ready() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	_MenuUi.bind_press_feedback(_btn_play)
	_MenuUi.bind_press_feedback(_btn_level)
	_MenuUi.bind_press_feedback(_btn_settings)
	_MenuUi.bind_press_feedback(_btn_about)
	_btn_play.pressed.connect(_on_play_pressed)
	_btn_level.pressed.connect(_on_level_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_about.pressed.connect(_on_about_pressed)


func _exit_tree() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _on_play_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if play_scene_path.is_empty():
		return
	if _cloud_layer != null and _cloud_layer.has_method("scatter_and_finish"):
		await _cloud_layer.scatter_and_finish(1.15)
	get_tree().change_scene_to_file(play_scene_path)


func _on_level_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if level_select_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(level_select_scene_path)


func _on_settings_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if settings_scene_path.is_empty():
		return
	var nav := get_tree().root.get_node_or_null("NavigationState")
	if nav:
		nav.call("set_return_scene", "res://scenes/main_menu.tscn")
	get_tree().change_scene_to_file(settings_scene_path)


func _on_about_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if about_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(about_scene_path)
