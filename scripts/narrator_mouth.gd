extends TextureRect
## Циклическая смена кадров рта диктора во время «печати» текста.

@export var frame_textures: Array[Texture2D] = []
@export var frame_paths: PackedStringArray = []
@export_range(0.08, 0.45, 0.01) var frame_duration: float = 0.18

var _frame_idx: int = 0
var _anim_timer: Timer
var _loaded_textures: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loaded_textures = _load_frame_paths()
	_anim_timer = Timer.new()
	_anim_timer.one_shot = false
	add_child(_anim_timer)
	_anim_timer.timeout.connect(_on_frame)
	if _all_frames().is_empty():
		return
	texture = _all_frames()[0]


func _exit_tree() -> void:
	if _anim_timer != null:
		_anim_timer.stop()
		if _anim_timer.timeout.is_connected(_on_frame):
			_anim_timer.timeout.disconnect(_on_frame)


func play_looping() -> void:
	var frames := _all_frames()
	if frames.size() == 0:
		return
	_anim_timer.stop()
	_frame_idx = 0
	texture = frames[0]
	if frames.size() > 1:
		_anim_timer.wait_time = frame_duration
		_anim_timer.start()


func stop_idle() -> void:
	_anim_timer.stop()
	var frames := _all_frames()
	if frames.size() > 0:
		texture = frames[0]


func _on_frame() -> void:
	var frames := _all_frames()
	if frames.size() == 0:
		return
	_frame_idx = (_frame_idx + 1) % frames.size()
	texture = frames[_frame_idx]


func _all_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for t in frame_textures:
		if t != null:
			frames.append(t)
	for t in _loaded_textures:
		if t != null:
			frames.append(t)
	return frames


func _load_frame_paths() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if frame_paths.is_empty():
		return out
	for p in frame_paths:
		var path := str(p)
		if path.is_empty():
			continue
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			continue
		var tex := ImageTexture.create_from_image(img)
		if tex != null:
			out.append(tex)
	return out
