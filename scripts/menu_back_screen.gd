extends Control
## Экран с заголовком, опциональным текстом и кнопкой «Назад» (настройки / об игре).

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export var title_text: String = ""
@export_multiline var body_text: String = ""

@onready var _btn_back: Button = %BtnBack


func _ready() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	var mb = _MusicBusScript.new()
	mb.call("play_menu")
	var title: Label = get_node_or_null(NodePath("MenuHeaderBar/HeaderMargin/HeaderTitle")) as Label
	if title:
		title.text = title_text
		if title_text == "ОБ ИГРЕ":
			title.add_theme_font_size_override("font_size", 84)
	var header_margin := get_node_or_null(NodePath("MenuHeaderBar/HeaderMargin")) as MarginContainer
	if header_margin:
		header_margin.add_theme_constant_override("margin_top", 8)
		header_margin.add_theme_constant_override("margin_bottom", 8)
	var body: Label = get_node_or_null(NodePath("UiRoot/Column/BodyPanel/BodyLabel")) as Label
	if body == null:
		body = get_node_or_null(NodePath("UiRoot/Column/BodyLabel")) as Label
	if body:
		body.text = body_text
		body.visible = not body_text.strip_edges().is_empty()
	_MenuUi.bind_press_feedback(_btn_back)
	_btn_back.pressed.connect(_on_back_pressed)


func _exit_tree() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _on_back_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if main_menu_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(main_menu_scene_path)
