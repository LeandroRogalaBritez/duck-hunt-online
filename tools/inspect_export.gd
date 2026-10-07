extends SceneTree

var _files: Array[String] = []


func _initialize() -> void:
	_walk("res://")
	var forbidden: Array[String] = []
	for path in _files:
		var lower := path.to_lower()
		if lower.contains("assets/pato/") or lower.contains("assets/cao/") or lower.contains("assets/cenario/") or lower.contains("assets/sons/") or lower.contains("duck_hunt") or lower.contains("pikpng") or lower.contains("nes - duck"):
			forbidden.append(path)
	if not forbidden.is_empty():
		push_error("Legacy media in export: " + str(forbidden))
		quit(1)
		return
	for required in ["res://assets/alien/art/city_night.png", "res://assets/alien/art/et_hover.tres", "res://assets/alien/art/agents_present.tres", "res://assets/alien/audio/ambience.mp3"]:
		if not ResourceLoader.exists(required) or ResourceLoader.load(required) == null:
			push_error("Required asset missing from export: " + required)
			quit(1)
			return
	print("PASS: exported package inspected; ", _files.size(), " files, no legacy media paths")
	quit()


func _walk(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		_files.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		_walk(path.path_join(directory))
