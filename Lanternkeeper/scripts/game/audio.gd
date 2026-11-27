extends Node
## 효과음·배경음악 재생 (자동 로드: Sfx)

const SFX := ["ui_tap", "ui_confirm", "step", "place", "ignite", "hit", "kill", "chain", "freeze", "shatter",
	"heal", "hurt", "explode", "deflect", "enemy_step", "shoot", "win", "lose", "coin", "page", "banner", "water"]
const MUSIC := ["title", "fog", "mirror", "library", "eclipse", "boss"]

var streams := {}
var music_streams := {}
var players: Array = []
var next_player := 0
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var cur_music := ""
var last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for n in MUSIC:
		var path := "res://assets/audio/music_%s.wav" % n
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamWAV:
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD
				st.loop_begin = 0
				st.loop_end = int(st.get_length() * st.mix_rate)
			music_streams[n] = st
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)


func _db(v: float) -> float:
	return linear_to_db(clampf(v, 0.0001, 1.0))


func play(n: String, pitch: float = 1.0, vol: float = 1.0) -> void:
	if not streams.has(n):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(n, -1000)) < 30:
		return
	last_play[n] = now
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[n]
	p.pitch_scale = pitch
	p.volume_db = _db(float(Save.setting("sfx", 0.8)) * vol)
	p.play()


func music(n: String) -> void:
	if n == cur_music or not music_streams.has(n):
		return
	cur_music = n
	var target := float(Save.setting("music", 0.55))
	var old := music_a
	music_a = music_b
	music_b = old
	music_a.stream = music_streams[n]
	music_a.volume_db = -60.0
	music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(music_a, "volume_db", _db(target), 1.2)
	tw.tween_property(music_b, "volume_db", -60.0, 1.2)
	tw.chain().tween_callback(music_b.stop)


func apply_volumes() -> void:
	if music_a.playing:
		music_a.volume_db = _db(float(Save.setting("music", 0.55)))
