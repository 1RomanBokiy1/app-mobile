extends Node
## Фоновая музыка: отдельный трек для главного меню (и экранов вокруг него) и для игрового уровня.

@export var menu_music_path: String = "res://assets/audio/bgm_main_menu.mp3"
@export var level_music_path: String = "res://assets/audio/bgm_level.mp3"

var _player: AudioStreamPlayer
var _current_kind: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)


func play_menu_music() -> void:
	_play_kind("menu", menu_music_path)


func play_level_music() -> void:
	_play_kind("level", level_music_path)


func _play_kind(kind: String, path: String) -> void:
	if _current_kind == kind and _player.playing:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path) as AudioStream
	if st == null:
		return
	_set_loop(st)
	_player.stream = st
	_current_kind = kind
	_player.play()


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
