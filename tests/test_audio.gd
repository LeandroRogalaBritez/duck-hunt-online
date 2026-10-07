extends Node

const AUDIO = preload("res://scenes/invasion/invasion_audio.gd")
var _capture := AudioEffectCapture.new()
var _player := AudioStreamPlayer.new()
var _peak := 0.0
var _squares := 0.0
var _frames := 0


func _ready() -> void:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, &"AudioValidation")
	AudioServer.add_bus_effect(index, _capture)
	AudioServer.set_bus_mute(0, true)
	_player.bus = &"AudioValidation"
	add_child(_player)
	_run.call_deferred()


func _process(_delta: float) -> void:
	_drain()


func _drain() -> void:
	var available := _capture.get_frames_available()
	if available <= 0:
		return
	for frame in _capture.get_buffer(available):
		_peak = maxf(_peak, maxf(absf(frame.x), absf(frame.y)))
		_squares += frame.length_squared()
		_frames += 1


func _run() -> void:
	var samples := AUDIO.SOUNDS.duplicate()
	samples[&"ambience"] = AUDIO.BED
	var report: Array[Dictionary] = []
	for key in samples:
		_peak = 0
		_squares = 0
		_frames = 0
		_capture.clear_buffer()
		_player.stream = samples[key]
		_player.play()
		await _player.finished
		_drain()
		var rms := sqrt(_squares / maxf(_frames * 2, 1))
		var entry := {"id": str(key), "duration": _player.stream.get_length(), "peak_db": linear_to_db(maxf(_peak, 0.000001)), "rms_db": linear_to_db(maxf(rms, 0.000001)), "decoded_frames": _frames}
		report.append(entry)
		print("AUDIO: ", entry)
		if _frames == 0 or _peak <= 0:
			push_error("Audio could not be decoded: " + str(key))
			get_tree().quit(1)
			return
	var file := FileAccess.open("res://tests/evidence/audio_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	_player.stop()
	_player.stream = null
	print("PASS: all 13 ElevenLabs assets decode and contain audio")
	get_tree().quit()
