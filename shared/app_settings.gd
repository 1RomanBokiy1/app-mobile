extends Node
## Сохранение настроек: звук, вибрация, язык (ru/en). Автозагрузка: AppSettings.

const _CONFIG_PATH := "user://app_settings.cfg"

## 0–100; 0 = тишина. Старый `sound_enabled` из cfg мигрируется при загрузке.
var master_volume_percent: int = 100
var vibration_enabled: bool = true
var language_code: String = "ru"


func is_sound_enabled() -> bool:
	return master_volume_percent > 0


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_locale()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_CONFIG_PATH) != OK:
		return
	if cf.has_section_key("app", "master_volume_percent"):
		master_volume_percent = int(cf.get_value("app", "master_volume_percent", 100))
	else:
		master_volume_percent = 0 if not bool(cf.get_value("app", "sound_enabled", true)) else 100
	master_volume_percent = clampi(master_volume_percent, 0, 100)
	vibration_enabled = bool(cf.get_value("app", "vibration_enabled", true))
	language_code = str(cf.get_value("app", "language", "ru"))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("app", "master_volume_percent", master_volume_percent)
	cf.set_value("app", "sound_enabled", master_volume_percent > 0)
	cf.set_value("app", "vibration_enabled", vibration_enabled)
	cf.set_value("app", "language", language_code)
	cf.save(_CONFIG_PATH)


func apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var p := clampf(float(master_volume_percent) / 100.0, 0.0, 1.0)
	if p <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(p))


func apply_locale() -> void:
	var code := language_code
	if code != "ru" and code != "en":
		code = "ru"
		language_code = code
	TranslationServer.set_locale(code)


func set_master_volume_percent(v: int) -> void:
	master_volume_percent = clampi(v, 0, 100)
	apply_audio()
	save_settings()


func set_sound_enabled(v: bool) -> void:
	set_master_volume_percent(100 if v else 0)


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
