extends Control
## 루트: 화면 전환, 알림(토스트), 안전 영역(노치) 계산.

const SCREENS := {
	"title": preload("res://scripts/ui/title_screen.gd"),
	"hub": preload("res://scripts/ui/hub_screen.gd"),
	"map": preload("res://scripts/ui/map_screen.gd"),
	"battle": preload("res://scripts/ui/battle_screen.gd"),
	"reward": preload("res://scripts/ui/reward_screen.gd"),
	"shop": preload("res://scripts/ui/shop_screen.gd"),
	"event": preload("res://scripts/ui/event_screen.gd"),
	"rest": preload("res://scripts/ui/rest_screen.gd"),
	"result": preload("res://scripts/ui/result_screen.gd"),
	"codex": preload("res://scripts/ui/codex_screen.gd"),
	"settings": preload("res://scripts/ui/settings_screen.gd"),
	"challenge": preload("res://scripts/ui/challenge_screen.gd"),
	"puzzles": preload("res://scripts/ui/puzzle_screen.gd"),
}

var current: Control = null
var toast_layer: CanvasLayer
var toast_box: VBoxContainer


func _ready() -> void:
	theme = UI.make_theme()
	_safe_area()
	get_viewport().size_changed.connect(_safe_area)
	Game.screen_requested.connect(_show)
	Game.toast_requested.connect(_toast)
	toast_layer = CanvasLayer.new()
	toast_layer.layer = 20
	add_child(toast_layer)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	m.add_theme_constant_override("margin_top", 14 + Game.safe_top)
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 30)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.theme = theme
	toast_layer.add_child(m)
	toast_box = UI.vbox(8)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(toast_box)
	var start := "title"
	var demo := ""
	var shot := ""
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--screen="):
			start = a.substr(9)
		elif a.begins_with("--demo="):
			demo = a.substr(7)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
	_show(start, {})
	if demo != "":
		_demo(demo)
	if shot != "":
		await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.get_environment("SHOT_DELAY") != "" else 2.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		get_tree().quit()


## 개발용: 특정 상황으로 바로 진입 (스크린샷 확인·디버깅)
func _demo(d: String) -> void:
	var parts := d.split(":")
	var kind := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match kind:
		"hub", "codex", "settings", "challenge", "puzzles":
			Game.goto(kind, {"tab": arg} if arg != "" else {})
		"map":
			Game.new_run("normal", "keeper", arg if arg != "" else "candle", 0)
		"battle", "preview", "boss", "elite":
			Game.new_run("normal", "keeper", arg if arg != "" else "candle", 0)
			if kind == "boss" or kind == "elite":
				var biome_i := int(OS.get_environment("FLOOR")) if OS.get_environment("FLOOR") != "" else 0
				Game.run.floor = biome_i
				var n := {"id": 99, "row": 4, "type": kind}
				Game._start_battle(n)
			else:
				if OS.get_environment("FLOOR") != "":
					Game.run.floor = int(OS.get_environment("FLOOR"))
				Game.enter_node(MapGen.starts(Game.run.map)[0])
			if kind == "preview":
				await get_tree().create_timer(0.5).timeout
				var scr = current
				var bt: Battle = Game.battle
				bt.skip_move()
				var cells := bt.lantern_cells()
				var best = null
				var best_k := -1
				for c in cells:
					var pv := bt.preview([c])
					var k: int = int(pv.get("kills", 0)) * 10 + pv["cast"]["hits"].size()
					if k > best_k:
						best_k = k
						best = c
				scr._refresh()
				scr._set_preview(best)
		"reward":
			Game.new_run("normal", "keeper", "candle", 0)
			Game.goto("reward", {"mode": arg if arg != "" else "elite", "oil": 18})
		"shop":
			Game.new_run("normal", "keeper", "candle", 0)
			Game.run.oil = 150
			Game.goto("shop", {"node": 1})
		"event":
			Game.new_run("normal", "keeper", "candle", 0)
			Game.goto("event", {"id": arg if arg != "" else "e_mirror"})
		"rest":
			Game.new_run("normal", "keeper", "candle", 0)
			Game.goto("rest")
		"puzzle":
			Game.start_puzzle(int(arg) if arg != "" else 0)
		"autoplay":
			var ap: Node = load("res://tools/autoplay.gd").new()
			ap.main = self
			ap.runs_left = int(arg) if arg != "" else 2
			add_child(ap)
		"result":
			Game.goto("result", {"victory": true, "embers": 120, "rooms": 24, "elites": 3, "bosses": 4, "kills": 133, "floor": 4,
				"mode": "daily", "score": 2310, "date": "2026-11-27", "character": "keeper", "lantern": "candle", "asc": 0,
				"inscriptions": ["f_ember", "i_frost"], "unlocks": [{"kind": "ach", "title": "첫 불꽃"}]})


func _safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var vp := get_viewport_rect().size
	if win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var sc := vp.y / float(win.y)
	Game.safe_top = clampi(int(safe.position.y * sc), 0, 140)
	Game.safe_bottom = clampi(int((win.y - safe.end.y) * sc), 0, 100)


func _show(screen: String, p: Dictionary) -> void:
	if not SCREENS.has(screen):
		return
	if current != null:
		current.queue_free()
	var s: Control = SCREENS[screen].new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(s)
	move_child(s, 0)
	s.params = p
	s.build(p)
	current = s
	s.modulate.a = 0.0
	create_tween().tween_property(s, "modulate:a", 1.0, 0.2)


func _toast(text: String, kind: String) -> void:
	var col := UI.AMBER
	var icon := "lantern"
	match kind:
		"bad":
			col = UI.RED
			icon = "close"
		"set":
			col = UI.VIOLET
			icon = "star"
		"ach":
			col = Color("ffd66a")
			icon = "crown"
		"skin":
			col = Color("ffd66a")
			icon = "flame"
		"story":
			col = UI.BLUE
			icon = "book"
		"char":
			col = UI.GREEN
			icon = "person"
	var p := UI.chip(icon, text, col, 21)
	var tsb := FancyBox.make(Color("26233f"), Color("1a1830"), Color(col, 0.6), 999, 14).with_shadow(Color(0, 0, 0, 0.55), 14, 5)
	tsb.pad(20, 13)
	p.add_theme_stylebox_override("panel", tsb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(p.get_meta("label") as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	toast_box.add_child(p)
	p.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	if kind in ["ach", "skin", "story", "char"]:
		Sfx.play("coin")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.run != null:
			Game.save_run()
		else:
			Save.save_meta()
