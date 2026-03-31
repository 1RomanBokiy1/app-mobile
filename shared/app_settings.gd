extends Node
## Сохранение настроек: звук, вибрация, язык (ru/en). Автозагрузка: AppSettings.

const _CONFIG_PATH := "user://app_settings.cfg"

var sound_enabled: bool = true
var vibration_enabled: bool = true
var language_code: String = "ru"


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_locale()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_CONFIG_PATH) != OK:
		return
	sound_enabled = bool(cf.get_value("app", "sound_enabled", true))
	vibration_enabled = bool(cf.get_value("app", "vibration_enabled", true))
	language_code = str(cf.get_value("app", "language", "ru"))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("app", "sound_enabled", sound_enabled)
	cf.set_value("app", "vibration_enabled", vibration_enabled)
	cf.set_value("app", "language", language_code)
	cf.save(_CONFIG_PATH)


func apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not sound_enabled)


func apply_locale() -> void:
	var code := language_code
	if code != "ru" and code != "en":
		code = "ru"
		language_code = code
	TranslationServer.set_locale(code)


func set_sound_enabled(v: bool) -> void:
	sound_enabled = v
	apply_audio()
	save_settings()


func set_vibration_enabled(v: bool) -> void:
	vibration_enabled = v
	save_settings()


func set_language(code: String) -> void:
	if code != "ru" and code != "en":
		return
	language_code = code
	apply_locale()
	save_settings()


func toggle_language() -> void:
	set_language("en" if language_code == "ru" else "ru")


func vibrate_light() -> void:
	if not vibration_enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(40)
