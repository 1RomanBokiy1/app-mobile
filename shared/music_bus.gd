extends RefCounted
class_name MusicBus
## Вызовы к автозагрузке MusicManager (без глобального имени в линтере — создаём экземпляр-хелпер).


func play_menu() -> void:
	var m := _mgr()
	if m:
		m.call("play_menu_music")


func play_level() -> void:
	var m := _mgr()
	if m:
		m.call("play_level_music")


func _mgr() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var st := loop as SceneTree
	if st == null:
		return null
	return st.root.get_node_or_null("MusicManager")
