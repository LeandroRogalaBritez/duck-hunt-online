extends Node

const SOUNDS := {
	&"prepare": preload("res://assets/alien/audio/prepare.mp3"),
	&"fire": preload("res://assets/alien/audio/fire.mp3"),
	&"hit": preload("res://assets/alien/audio/hit.mp3"),
	&"miss": preload("res://assets/alien/audio/empty.mp3"),
	&"dash": preload("res://assets/alien/audio/dash.mp3"),
	&"ready": preload("res://assets/alien/audio/ready.mp3"),
	&"wave": preload("res://assets/alien/audio/wave.mp3"),
	&"win": preload("res://assets/alien/audio/win.mp3"),
	&"lose": preload("res://assets/alien/audio/lose.mp3"),
	&"landing": preload("res://assets/alien/audio/landing.mp3"),
	&"collect": preload("res://assets/alien/audio/collect.mp3"),
	&"ui": preload("res://assets/alien/audio/ui.mp3"),
}
const BED := preload("res://assets/alien/audio/ambience.mp3")
var enabled := true
var _pool: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _voice := 0


func _ready() -> void:
	for bus in [&"SFX", &"Ambience", &"UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var has_limiter := false
	for index in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.volume_db = -13
		add_child(player)
		_pool.append(player)
	_ambience = AudioStreamPlayer.new()
	var bed := BED.duplicate() as AudioStreamMP3
	bed.loop = true
	_ambience.stream = bed
	_ambience.bus = &"Ambience"
	_ambience.volume_db = -18
	add_child(_ambience)
	if DisplayServer.get_name() != "headless":
		_ambience.play()


func cue(key: StringName) -> void:
	if DisplayServer.get_name() == "headless" or not enabled or not SOUNDS.has(key):
		return
	var player := _pool[_voice]
	_voice = (_voice + 1) % _pool.size()
	player.stream = SOUNDS[key]
	player.volume_db = -4.0 if key == &"ui" else (-10.0 if key == &"miss" else -13.0)
	player.bus = &"UI" if key == &"ui" else &"SFX"
	player.pitch_scale = randf_range(0.97, 1.03) if key == &"fire" or key == &"hit" else 1.0
	player.play()


func set_effects_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"UI"), linear_to_db(maxf(value, 0.0001)))


func set_ambience_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambience"), linear_to_db(maxf(value, 0.0001)))


func _exit_tree() -> void:
	for player in _pool:
		player.stop()
		player.stream = null
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	_pool.clear()
