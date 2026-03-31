extends Node
class_name UiManager
## Центральное управление игровым UI: регистрация экранов и согласование с паузой.

var _game_ui_stack: Array[Control] = []
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_busy: bool = false


func _ready() -> void:
	_ensure_fade_layer()


func _ensure_fade_layer() -> void:
	if _fade_layer != null and is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 1000
	_fade_layer.visible = false
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	# Прозрачный слой не должен перехватывать клики — иначе кнопки «мёртвые».
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.anchor_left = 0.0
	_fade_rect.anchor_top = 0.0
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.offset_left = 0
	_fade_rect.offset_top = 0
	_fade_rect.offset_right = 0
	_fade_rect.offset_bottom = 0
	_fade_layer.add_child(_fade_rect)


func transition_to_scene(scene_path: String, fade_out: float = 0.22, fade_in: float = 0.22) -> void:
	if _fade_busy:
		reset_fade_blocking()
	if scene_path.is_empty():
		return
	_fade_busy = true
	_ensure_fade_layer()
	_fade_layer.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	await _tween_fade_to(1.0, fade_out)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _tween_fade_to(0.0, fade_in)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.visible = false

	_fade_busy = false


func reset_fade_blocking() -> void:
	## Сброс, если переход прервался — иначе кнопки на следующей сцене не кликаются.
	_fade_busy = false
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.visible = false
	if _fade_rect != null and is_instance_valid(_fade_rect):
		var c := _fade_rect.color
		_fade_rect.color = Color(c.r, c.g, c.b, 0.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tween_fade_to(alpha: float, dur: float) -> void:
	if _fade_rect == null:
		return
	dur = maxf(0.01, dur)
	var c := _fade_rect.color
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fade_rect, "color", Color(c.r, c.g, c.b, alpha), dur)
	await tw.finished


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
