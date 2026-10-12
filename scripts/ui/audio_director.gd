extends Node
## Original synthesized audio, retained as ordinary editable WAV assets.
var music_enabled := true
var effects_enabled := true
var gesture_received := false
const SELECT = preload("res://assets/audio/select.wav")
const CHIP = preload("res://assets/audio/chip.wav")
const DISCARD = preload("res://assets/audio/discard.wav")

func _ready() -> void:
	var stream := preload("res://assets/audio/ambient.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	$Music.stream = stream
	$Music.volume_db = -12
	$Effects.volume_db = -8

func unlock() -> void:
	gesture_received = true
	if music_enabled and not $Music.playing:
		$Music.play()

func set_music(value: bool) -> void:
	music_enabled = value
	if value and gesture_received:
		$Music.play()
	else:
		$Music.stop()

func play_select() -> void:
	_play(SELECT, 1.0)

func play_discard() -> void:
	_play(DISCARD, 1.0)

func play_score(index: int) -> void:
	_play(CHIP, minf(1.0 + index * 0.09, 2.1))

func _play(stream: AudioStream, pitch: float) -> void:
	if effects_enabled:
		$Effects.stream = stream
		$Effects.pitch_scale = pitch
		$Effects.play()

func _exit_tree() -> void:
	$Music.stop()
	$Effects.stop()
	$Music.stream = null
	$Effects.stream = null
