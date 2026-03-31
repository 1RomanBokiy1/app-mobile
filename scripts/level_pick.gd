extends Control
## Экран выбора уровня: 6 слотов, закрытые по прогрессу; после прохождения всех — всё открыто.

const _UIManagerScript = preload("res://shared/ui_manager.gd")
const _MenuUi = preload("res://scripts/menu_ui.gd")
const _MusicBusScript = preload("res://shared/music_bus.gd")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export_file("*.tscn") var level_scene_path: String = "res://scenes/level_scene.tscn"

@onready var _hdr_title: Label = $MenuHeaderBar/HeaderMargin/HeaderTitle
@onready var _list: VBoxContainer = %LevelList
@onready var _btn_back: Button = %BtnBack

const _BTN_TEX: Texture2D = preload("res://assets/sprites/btn_frame_lavender.png")

var _settings: Node
var _lock_icon: Texture2D
var _good_icon: Texture2D
var _bad_icon: Texture2D
var _btn_style_normal: StyleBoxTexture
var _lp: Node


func _ready() -> void:
	_settings = get_tree().root.get_node("AppSettings")
	_lp = get_tree().root.get_node_or_null("LevelProgress")
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.register_game_ui(self)
	var mb = _MusicBusScript.new()
	mb.call("play_menu")
	_lock_icon = _make_lock_icon()
	_good_icon = _make_check_icon()
	_bad_icon = _make_cross_icon()
	_build_button_style()
	_MenuUi.bind_press_feedback(_btn_back)
	_btn_back.pressed.connect(_on_back_pressed)
	_rebuild_level_rows()
	_refresh_localized_texts()


func _exit_tree() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr:
		mgr.unregister_game_ui(self)


func _build_button_style() -> void:
	_btn_style_normal = StyleBoxTexture.new()
	_btn_style_normal.texture = _BTN_TEX
	_btn_style_normal.texture_margin_left = 14.0
	_btn_style_normal.texture_margin_top = 14.0
	_btn_style_normal.texture_margin_right = 14.0
	_btn_style_normal.texture_margin_bottom = 14.0


func _make_lock_icon() -> ImageTexture:
	var sz := 48
	var im := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var body_col := Color(0.36, 0.4, 0.5, 1)
	var arch_col := Color(0.5, 0.54, 0.63, 1)
	im.fill_rect(Rect2i(10, 22, 28, 22), body_col)
	im.fill_rect(Rect2i(12, 10, 24, 18), arch_col)
	return ImageTexture.create_from_image(im)


func _make_check_icon() -> ImageTexture:
	var sz := 48
	var im := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var col := Color(0.1, 0.7, 0.35, 1)
	# Понятная галочка (две толстые линии).
	var thickness := 3
	var pts: Array[Vector2i] = []
	# Нисходящая часть: (12, 26) -> (20, 34)
	for i in range(0, 12):
		var x := 12 + i
		var y := 26 + int(i * 0.75)
		pts.append(Vector2i(x, y))
	# Восходящая часть: (20, 34) -> (36, 16)
	for i in range(0, 18):
		var x := 20 + i
		var y := 34 - int(i * 1.0)
		pts.append(Vector2i(x, y))
	for p in pts:
		for dx in range(-thickness, thickness + 1):
			for dy in range(-thickness, thickness + 1):
				var px := p.x + dx
				var py := p.y + dy
				if px >= 0 and px < sz and py >= 0 and py < sz:
					im.set_pixel(px, py, col)
	return ImageTexture.create_from_image(im)


func _make_cross_icon() -> ImageTexture:
	var sz := 48
	var im := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var col := Color(0.85, 0.25, 0.25, 1)
	# Крестик.
	for i in range(sz):
		im.set_pixel(i, i, col)
		im.set_pixel(sz - 1 - i, i, col)
	return ImageTexture.create_from_image(im)


func _refresh_localized_texts() -> void:
	var en: bool = _settings.language_code == "en"
	_hdr_title.text = "LEVELS" if en else "УРОВНИ"
	_btn_back.text = "BACK" if en else "НАЗАД"
	_rebuild_level_rows()


func _level_caption(idx: int) -> String:
	var en: bool = _settings.language_code == "en"
	if en:
		return "Level %d — TBA" % [idx + 1]
	return "Уровень %d — Название уровня" % [idx + 1]


func _rebuild_level_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _btn_style_normal == null:
		return
	if _lp == null:
		return
	for i in range(int(_lp.call("get_level_count"))):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 128)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 44)
		btn.add_theme_color_override("font_color", Color(0.04, 0.18, 0.52, 1))
		btn.add_theme_color_override("font_outline_color", Color(0.98, 0.99, 1, 1))
		btn.add_theme_constant_override("outline_size", 4)
		btn.add_theme_stylebox_override("normal", _btn_style_normal)
		btn.add_theme_stylebox_override("pressed", _btn_style_normal)
		btn.add_theme_stylebox_override("hover", _btn_style_normal)
		btn.add_theme_stylebox_override("focus", _btn_style_normal)
		btn.add_theme_stylebox_override("disabled", _btn_style_normal)
		btn.text = _level_caption(i)
		var unlocked: bool = bool(_lp.call("is_level_unlocked", i))
		btn.disabled = not unlocked
		btn.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.94, 0.96, 1, 0.82)
		var lock_rect := TextureRect.new()
		lock_rect.custom_minimum_size = Vector2(52, 52)
		lock_rect.texture = _lock_icon
		lock_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_rect.visible = not unlocked
		lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idx := i
		btn.pressed.connect(_on_level_button_pressed.bind(idx))
		if not btn.disabled:
			_MenuUi.bind_press_feedback(btn)
		row.add_child(btn)
		row.add_child(lock_rect)

		# Статус "правильно/неправильно" после попытки.
		var status_rect := TextureRect.new()
		status_rect.custom_minimum_size = Vector2(52, 52)
		status_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		status_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		status_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lvl_res: int = int(_lp.call("get_level_result", i))
		var show_status: bool = unlocked and (lvl_res == 1 or lvl_res == 2)
		if lvl_res == 1:
			status_rect.texture = _good_icon
		elif lvl_res == 2:
			status_rect.texture = _bad_icon
		status_rect.visible = show_status
		row.add_child(status_rect)

		_list.add_child(row)


func _on_level_button_pressed(idx: int) -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if _lp == null or not bool(_lp.call("is_level_unlocked", idx)):
		return
	if level_scene_path.is_empty():
		return
	_lp.call("begin_play_level", idx)
	get_tree().change_scene_to_file(level_scene_path)


func _on_back_pressed() -> void:
	var mgr := _UIManagerScript.get_instance()
	if mgr == null or mgr.is_paused():
		return
	if main_menu_scene_path.is_empty():
		return
	_settings.vibrate_light()
	get_tree().change_scene_to_file(main_menu_scene_path)
