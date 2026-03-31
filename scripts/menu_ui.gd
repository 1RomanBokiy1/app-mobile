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
