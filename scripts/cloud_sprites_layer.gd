extends Control
## Пиксельные облака: плотное заполнение экрана и бесшовный цикл по горизонтали.

@export var cloud_texture: Texture2D
@export var cloud_textures: Array[Texture2D] = []
@export var cloud_texture_paths: PackedStringArray = []
@export_range(24, 260, 1) var cloud_count: int = 105
@export_range(0.22, 1.8, 0.05) var min_scale: float = 0.42
@export_range(0.22, 1.8, 0.05) var max_scale: float = 1.05
@export var drift_speed: float = 26.0

var _drift_paused: bool = false
var _path_textures: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_path_textures()
	if not _has_any_texture():
		return
	await get_tree().process_frame
	_rebuild_clouds()


func _has_any_texture() -> bool:
	if cloud_texture != null:
		return true
	for t in cloud_textures:
		if t != null:
			return true
	for t in _path_textures:
		if t != null:
			return true
	return false


func _pick_texture() -> Texture2D:
	var list: Array[Texture2D] = []
	for t in cloud_textures:
		if t != null:
			list.append(t)
	if cloud_texture != null:
		list.append(cloud_texture)
	for t in _path_textures:
		if t != null:
			list.append(t)
	if list.is_empty():
		return null
	return list[randi() % list.size()]

func _load_path_textures() -> void:
	_path_textures.clear()
	if cloud_texture_paths.is_empty():
		return
	for p in cloud_texture_paths:
		var path := str(p)
		if path.is_empty():
			continue
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			continue
		var tex := ImageTexture.create_from_image(img)
		if tex != null:
			_path_textures.append(tex)


func _rebuild_clouds() -> void:
	for c in get_children():
		c.queue_free()
	if _pick_texture() == null or size.x < 8.0 or size.y < 8.0:
		return
	var cols: int = maxi(7, int(ceil(size.x / 170.0)))
	var rows: int = maxi(7, int(ceil(size.y / 130.0)))
	var cells: int = cols * rows
	var n_sparse: int = int(ceil(float(cells) * 0.5)) + 14
	var n_target: int = mini(cloud_count, n_sparse)
	n_target = maxi(n_target, mini(cloud_count, 24))
	n_target = mini(n_target, int(ceil(float(cells) * 1.25)) + 40)
	for i in range(n_target):
		var tex := _pick_texture()
		if tex == null:
			break
		var tex_size := tex.get_size()
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s: float = randf_range(min_scale, max_scale)
		var w: float = tex_size.x * s
		var h: float = tex_size.y * s
		tex_rect.custom_minimum_size = Vector2(w, h)
		tex_rect.size = Vector2(w, h)
		if i < cells:
			var gx: int = i % cols
			var gy: int = int(floor(float(i) / float(cols)))
			var denom_x: float = float(maxi(1, cols - 1))
			var denom_y: float = float(maxi(1, rows - 1))
			var cell_x: float = float(gx) / denom_x * size.x
			var cell_y: float = float(gy) / denom_y * size.y
			tex_rect.position = Vector2(
				cell_x - w * 0.5 + randf_range(-55.0, 55.0),
				cell_y - h * 0.5 + randf_range(-45.0, 45.0)
			)
		else:
			tex_rect.position = Vector2(
				randf_range(w * -0.35, size.x - w * 0.65),
				randf_range(h * -0.3, size.y - h * 0.7)
			)
		var spd: float = randf_range(0.55, 1.35) * drift_speed
		if randf() < 0.5:
			spd = -spd
		tex_rect.set_meta(&"speed", spd)
		tex_rect.set_meta(&"wrap_margin", w * 0.5 + 40.0)
		add_child(tex_rect)


func _process(delta: float) -> void:
	if _drift_paused or not _has_any_texture():
		return
	var w := size.x
	var h := size.y
	if w < 1.0 or h < 1.0:
		return
	for tex_rect in get_children():
		if tex_rect is not TextureRect:
			continue
		var spd: float = float(tex_rect.get_meta(&"speed", drift_speed))
		tex_rect.position.x += spd * delta
		var mrg: float = float(tex_rect.get_meta(&"wrap_margin", tex_rect.size.x))
		if spd > 0.0 and tex_rect.position.x > w + mrg:
			tex_rect.position.x = -tex_rect.size.x - mrg * 0.5 - randf() * 80.0
			tex_rect.position.y = randf_range(-tex_rect.size.y * 0.2, h - tex_rect.size.y * 0.85)
		elif spd < 0.0 and tex_rect.position.x < -tex_rect.size.x - mrg:
			tex_rect.position.x = w + mrg * 0.5 + randf() * 80.0
			tex_rect.position.y = randf_range(-tex_rect.size.y * 0.2, h - tex_rect.size.y * 0.85)


func set_drift_paused(p: bool) -> void:
	_drift_paused = p


func scatter_and_finish(duration: float = 1.15) -> void:
	_drift_paused = true
	var any := false
	for c in get_children():
		if c is TextureRect:
			any = true
			break
	if not any:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN)
	var cx := size.x * 0.5
	for c in get_children():
		if c is not TextureRect:
			continue
		var tex_rect := c as TextureRect
		var dir := 1.0 if tex_rect.position.x + tex_rect.size.x * 0.5 >= cx else -1.0
		var target := tex_rect.position + Vector2(dir * (size.x + tex_rect.size.x) * 1.1, randf_range(-220.0, 220.0))
		tw.tween_property(tex_rect, "position", target, duration)
	await tw.finished
