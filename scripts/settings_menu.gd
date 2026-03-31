extends Control
## Экран настроек: звук, вибрация, язык ru/en.

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

@onready var _settings: Node = get_tree().root.get_node("AppSettings")
@onready var _title: Label = $MenuHeaderBar/HeaderMargin/HeaderTitle
@onready var _lbl_sound: Label = %LblSound
@onready var _lbl_vib: Label = %LblVibration
@onready var _lbl_lang: Label = %LblLanguage
@onready var _slider_sound: HSlider = %SliderSound
@onready var _lbl_volume_value: Label = %LblVolumeValue
@onready var _toggle_vib: CheckButton = %ToggleVibration
@onready var _btn_lang: Button = %BtnLanguage
@onready var _btn_back: Button = %BtnBack


func _ready() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	var mb = _MusicBusScript.new()
	mb.call("play_menu")
	_slider_sound.value = _settings.master_volume_percent
	_update_volume_label()
	_slider_sound.value_changed.connect(_on_volume_slider_changed)
	_toggle_vib.button_pressed = _settings.vibration_enabled
	_toggle_vib.toggled.connect(_on_vibration_toggled)
	_btn_lang.pressed.connect(_on_language_pressed)
	_btn_back.pressed.connect(_on_back_pressed)
	_MenuUi.bind_press_feedback(_btn_lang)
	_MenuUi.bind_press_feedback(_btn_back)
	_refresh_texts()


func _exit_tree() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _refresh_texts() -> void:
	var en: bool = _settings.language_code == "en"
	if en:
		_title.text = "SETTINGS"
		_lbl_sound.text = "Volume"
		_lbl_vib.text = "Vibration"
		_lbl_lang.text = "Language"
		_btn_back.text = "BACK"
	else:
		_title.text = "НАСТРОЙКИ"
		_lbl_sound.text = "Громкость"
		_lbl_vib.text = "Вибрация"
		_lbl_lang.text = "Язык"
		_btn_back.text = "НАЗАД"
	_update_lang_button()


func _update_lang_button() -> void:
	_btn_lang.text = "ENG" if _settings.language_code == "ru" else "RU"


func _update_volume_label() -> void:
	_lbl_volume_value.text = "%d%%" % int(_slider_sound.value)


func _on_volume_slider_changed(v: float) -> void:
	_settings.set_master_volume_percent(int(round(v)))
	_update_volume_label()


func _on_vibration_toggled(pressed: bool) -> void:
	_settings.set_vibration_enabled(pressed)
	if pressed:
		_settings.vibrate_light()


func _on_language_pressed() -> void:
	_settings.toggle_language()
	_refresh_texts()


func _on_back_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	var nav := get_tree().root.get_node_or_null("NavigationState")
	_settings.vibrate_light()
	var return_path: String = main_menu_scene_path
	if nav:
		return_path = str(nav.call("get_return_scene"))
	if return_path.is_empty():
		return
	get_tree().change_scene_to_file(return_path)
