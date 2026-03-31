extends Node
## Память для кнопки "Назад" в `settings.tscn`:
## - если настройки открыты из главного меню -> возвращаем в главное меню
## - если настройки открыты из уровня -> возвращаем в уровень

const DEFAULT_RETURN_SCENE_PATH: String = "res://scenes/main_menu.tscn"

var return_scene_path: String = DEFAULT_RETURN_SCENE_PATH


func set_return_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	return_scene_path = scene_path


func get_return_scene() -> String:
	if return_scene_path.is_empty():
		return DEFAULT_RETURN_SCENE_PATH
	return return_scene_path

