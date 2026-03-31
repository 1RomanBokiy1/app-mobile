extends RefCounted
## Общие UI-хелперы: анимация нажатия для BaseButton (touch). Вызывать через preload("res://scripts/menu_ui.gd").


static func bind_press_feedback(btn: BaseButton) -> void:
	if btn == null or btn.get_meta(&"menu_ui_press_bound", false):
		return
	btn.set_meta(&"menu_ui_press_bound", true)
	var refresh_pivot := func() -> void:
		btn.pivot_offset = btn.size * 0.5
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(refresh_pivot)
	btn.button_down.connect(func() -> void: _tween_down(btn))
	btn.button_up.connect(func() -> void: _tween_up(btn))
	btn.focus_exited.connect(func() -> void: _tween_up(btn))

	# Дополнительно: подгон текста, чтобы не вылезал за рамки на мобилках.
	if btn is Button:
		_bind_text_fit_internal(btn as Button, 28)


static func _bind_text_fit_internal(btn: Button, min_font_size: int) -> void:
	if btn.get_meta(&"menu_ui_text_fit_bound", false):
		return
	btn.set_meta(&"menu_ui_text_fit_bound", true)
	btn.clip_text = true
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var base_size := int(btn.get_meta(&"menu_ui_base_font_size", 0))
	if base_size <= 0:
		base_size = btn.get_theme_font_size(&"font_size")
		if base_size <= 0:
			base_size = 44
		btn.set_meta(&"menu_ui_base_font_size", base_size)

	var fit := func() -> void:
		_fit_button_text(btn, min_font_size)
	btn.resized.connect(fit)
	fit.call()


static func _fit_button_text(btn: Button, min_font_size: int) -> void:
	if btn == null:
		return
	if btn.text.is_empty():
		return
	var font := btn.get_theme_font(&"font")
	if font == null:
		return
	var base_size := int(btn.get_meta(&"menu_ui_base_font_size", 44))
	var style := btn.get_theme_stylebox(&"normal")
	var pad_l := 0.0
	var pad_r := 0.0
	if style != null:
		pad_l = style.get_content_margin(SIDE_LEFT)
		pad_r = style.get_content_margin(SIDE_RIGHT)
	var avail := btn.size.x - pad_l - pad_r - 8.0
	if avail <= 10.0:
		return

	var size := clampi(base_size, min_font_size, base_size)
	while size >= min_font_size:
		var w := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		if w <= avail:
			break
		size -= 2
	btn.add_theme_font_size_override("font_size", size)


static func _tween_down(btn: BaseButton) -> void:
	var t := btn.create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07)
	t.parallel().tween_property(btn, "modulate", Color(0.88, 0.88, 0.92), 0.07)


static func _tween_up(btn: BaseButton) -> void:
	var t := btn.create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.12)
	t.parallel().tween_property(btn, "modulate", Color.WHITE, 0.12)
