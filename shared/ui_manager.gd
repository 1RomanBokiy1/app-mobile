extends Node
class_name UiManager
## Центральное управление игровым UI: регистрация экранов и согласование с паузой.

var _game_ui_stack: Array[Control] = []


static func get_instance() -> UiManager:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var st := loop as SceneTree
	if st == null:
		return null
	var n := st.root.get_node_or_null(NodePath("UIManager"))
	return n as UiManager


func register_game_ui(ui: Control) -> void:
	if ui == null or not is_instance_valid(ui):
		return
	if ui in _game_ui_stack:
		return
	_game_ui_stack.append(ui)


func unregister_game_ui(ui: Control) -> void:
	_game_ui_stack.erase(ui)


func is_paused() -> bool:
	return get_tree().paused


func set_game_paused(paused: bool) -> void:
	get_tree().paused = paused
