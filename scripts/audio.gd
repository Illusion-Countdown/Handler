extends Node
## 音频池（自动加载为 Audio）

const NAMES := [
	"sfx_command", "sfx_confirm", "sfx_deny", "sfx_scan", "sfx_hit", "sfx_rifle",
	"sfx_cannon", "sfx_explosion", "sfx_explosion_big", "sfx_jam", "sfx_death_signal",
	"sfx_alarm", "sfx_wave", "sfx_ui", "sfx_radio_open", "sfx_radio_close", "sfx_pulse",
]
const LOOPS := ["amb_drone", "mus_dread"]

var streams: Dictionary = {}
var players: Array = []
var idx: int = 0
var music: AudioStreamPlayer
var amb: AudioStreamPlayer
var last_frame: Dictionary = {}


func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p):
			streams[n] = load(p)
	for i in range(24):
		var pl := AudioStreamPlayer.new()
		pl.bus = "Master"
		add_child(pl)
		players.append(pl)
	for n in LOOPS:
		var p2 := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p2):
			var s = load(p2)
			if s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_end = s.data.size() / 2
			streams[n] = s
	music = AudioStreamPlayer.new()
	music.volume_db = -20.0
	add_child(music)
	amb = AudioStreamPlayer.new()
	amb.volume_db = -26.0
	add_child(amb)
	if streams.has("mus_dread"):
		music.stream = streams["mus_dread"]
		music.play()
	if streams.has("amb_drone"):
		amb.stream = streams["amb_drone"]
		amb.play()


func play(n: String, vol_db: float = -4.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var pl: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	pl.stream = streams[n]
	pl.volume_db = vol_db
	pl.pitch_scale = pitch
	pl.play()


func set_threat(v: float) -> void:
	## v: 0..1 战场压力，用来抬音乐音量
	music.volume_db = lerpf(-24.0, -12.0, clamp(v, 0.0, 1.0))
	amb.volume_db = lerpf(-30.0, -18.0, clamp(v, 0.0, 1.0))
