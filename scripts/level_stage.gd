extends Control
## Уровень: вступление, диалог диктора (тап — печать/дальше), жизни, возврат в меню.

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export_range(0.012, 0.08, 0.002) var typewriter_char_delay: float = 0.028
@export var level_index: int = 0

const DIALOGUE_LINES: PackedStringArray = [
	"Привет! Рад тебя приветствовать в нашем городе D-Bus City.",
	"Я твой заместитель, звать меня ВИЦЕМЭРИО",
	"С сегодняшнего дня тебя назначили нашим мэром, поздравляю! Прошлого посадили за плохое поведение и незнание, как управлять городом.",
	"Здесь здания — это наши приложения в телефоне, а грузовики — наши данные между нашими приложениями.",
	"В правом верхнем углу твои жизни. Если принимаешь неправильные решения — минус одно сердечко. Потеряешь все — и добро пожаловать в тюрьму.",
]

@onready var _btn_menu: Button = %BtnMenu
@onready var _dialogue_label: RichTextLabel = %DialogueText
@onready var _hint_label: Label = %HintLabel
@onready var _heart1: TextureRect = %Heart1
@onready var _heart2: TextureRect = %Heart2
@onready var _heart3: TextureRect = %Heart3
@onready var _portrait: TextureRect = %PortraitNarrator

var _line_index: int = 0
var _lives: int = 3
var _typing: bool = false
var _line_plain: String = ""
var _type_timer: Timer
var _completion_reported: bool = false


func _ready() -> void:
	var lp0 := get_tree().root.get_node_or_null("LevelProgress")
	if lp0:
		level_index = lp0.call("take_pending_level_index", level_index)
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	_MenuUi.bind_press_feedback(_btn_menu)
	_btn_menu.pressed.connect(_on_menu_pressed)
	_type_timer = Timer.new()
	_type_timer.one_shot = false
	add_child(_type_timer)
	_type_timer.timeout.connect(_on_typewriter_tick)
	_update_lives_ui()
	_refresh_dialogue()


func _exit_tree() -> void:
	if _type_timer:
		_type_timer.stop()
		_type_timer.timeout.disconnect(_on_typewriter_tick)
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _gui_input(event: InputEvent) -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr != null and mgr.is_paused():
		return
	if not _hint_label.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		accept_event()
		_on_tap_advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_tap_advance()


func _on_tap_advance() -> void:
	if _typing:
		_finish_line_typing()
		return
	_line_index += 1
	_refresh_dialogue()


func _finish_line_typing() -> void:
	_type_timer.stop()
	_typing = false
	_dialogue_label.visible_characters = -1
	_dialogue_label.text = _line_plain
	_narrator_idle()


func _on_typewriter_tick() -> void:
	var shown: int = _dialogue_label.visible_characters
	if shown < 0:
		shown = 0
	shown += 1
	var n: int = _line_plain.length()
	if n <= 0:
		_type_timer.stop()
		_typing = false
		return
	if shown >= n:
		_dialogue_label.visible_characters = -1
		_type_timer.stop()
		_typing = false
		_narrator_idle()
	else:
		_dialogue_label.visible_characters = shown


func _start_typewriter(full: String) -> void:
	_line_plain = full
	_dialogue_label.text = full
	_dialogue_label.visible_characters = 0
	_typing = true
	_type_timer.wait_time = typewriter_char_delay
	_type_timer.start()
	_narrator_speak()


func _narrator_speak() -> void:
	if _portrait and _portrait.has_method("play_looping"):
		_portrait.call("play_looping")


func _narrator_idle() -> void:
	if _portrait and _portrait.has_method("stop_idle"):
		_portrait.call("stop_idle")


func _update_lives_ui() -> void:
	_heart1.visible = _lives >= 1
	_heart2.visible = _lives >= 2
	_heart3.visible = _lives >= 3


func _refresh_dialogue() -> void:
	_type_timer.stop()
	_typing = false
	_narrator_idle()
	_dialogue_label.visible_characters = -1
	if _line_index >= DIALOGUE_LINES.size():
		_dialogue_label.text = ""
		_hint_label.visible = false
		_try_report_level_done()
		return
	_hint_label.visible = true
	_start_typewriter(DIALOGUE_LINES[_line_index])


func _try_report_level_done() -> void:
	if _completion_reported:
		return
	_completion_reported = true
	var lp := get_tree().root.get_node_or_null("LevelProgress")
	if lp:
		lp.call("notify_level_completed", level_index)


func _on_menu_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if main_menu_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(main_menu_scene_path)
