extends Screen
## 첫 화면: 탑과 등불, 떠다니는 불티.


class TitleArt:
	extends Control
	var t := 0.0
	var embers := []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 40:
			embers.append([r.randf(), r.randf(), r.randf_range(0.02, 0.06), r.randf_range(1.5, 4.0), r.randf() * 10])

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var s := size
		for i in 24:
			var a := i / 24.0
			draw_rect(Rect2(0, s.y * a, s.x, s.y / 24.0 + 1), Color(0.03, 0.03, 0.05).lerp(Color(0.12, 0.07, 0.06), a * 0.8))
		var cx := s.x * 0.5
		# 탑 실루엣
		var base_y := s.y * 0.62
		var tower := PackedVector2Array([Vector2(cx - 120, base_y), Vector2(cx - 80, s.y * 0.2), Vector2(cx - 40, s.y * 0.12),
			Vector2(cx, s.y * 0.06), Vector2(cx + 40, s.y * 0.12), Vector2(cx + 80, s.y * 0.2), Vector2(cx + 120, base_y)])
		draw_colored_polygon(tower, Color(0.05, 0.045, 0.07))
		for i in 6:
			var wy := s.y * (0.18 + i * 0.07)
			var on := sin(t * 1.3 + i * 1.7) > 0.2
			draw_rect(Rect2(cx - 8, wy, 16, 22), Color(1, 0.7, 0.35, 0.8) if on else Color(0.15, 0.1, 0.08))
		draw_circle(Vector2(cx, s.y * 0.06), 30 + 6 * sin(t * 2), Color(1, 0.75, 0.4, 0.12))
		# 언덕
		var hill := PackedVector2Array()
		for i in 21:
			var x := s.x * i / 20.0
			hill.append(Vector2(x, base_y + 30 + sin(i * 0.7) * 14))
		hill.append(Vector2(s.x, s.y))
		hill.append(Vector2(0, s.y))
		draw_colored_polygon(hill, Color(0.025, 0.022, 0.035))
		# 등불지기와 긴 그림자
		var p := Vector2(cx, base_y + 36)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 0), p + Vector2(10, 0), p + Vector2(160, 260), p + Vector2(60, 260)]), Color(0.1, 0.05, 0.16, 0.85))
		draw_circle(p + Vector2(-22, -36), 60 + 4 * sin(t * 5), Color(1, 0.7, 0.35, 0.10))
		draw_circle(p + Vector2(-22, -36), 26 + 2 * sin(t * 7), Color(1, 0.75, 0.4, 0.25))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 0), p + Vector2(14, 0), p + Vector2(8, -40), p + Vector2(-8, -40)]), Color(0.02, 0.02, 0.03))
		draw_circle(p + Vector2(0, -48), 10, Color(0.02, 0.02, 0.03))
		draw_rect(Rect2(p + Vector2(-28, -44), Vector2(12, 14)), Color(1, 0.8, 0.45))
		for e in embers:
			var y := fmod(e[1] - t * e[2] + 1.0, 1.0)
			var x: float = e[0] + sin(t * 0.7 + e[4]) * 0.02
			var a := sin(y * PI)
			draw_circle(Vector2(x * s.x, y * s.y), e[3], Color(1, 0.65, 0.3, 0.6 * a))


func build(_p: Dictionary) -> void:
	Sfx.music("title")
	var art := TitleArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 60)
	m.add_theme_constant_override("margin_right", 60)
	m.add_theme_constant_override("margin_top", 90 + Game.safe_top)
	m.add_theme_constant_override("margin_bottom", 40 + Game.safe_bottom)
	add_child(m)
	var v := UI.vbox(14)
	m.add_child(v)
	var title := UI.label("등불지기", 92, UI.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(1, 0.5, 0.2, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 18)
	v.add_child(title)
	v.add_child(UI.label("그림자로 싸우는 턴제 퍼즐 로그라이트", 26, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	if Game.has_saved_run():
		v.add_child(UI.button("이어하기", func(): Game.continue_run(), 32, true, 92))
	v.add_child(UI.button("등불 오두막", func(): Game.goto("hub"), 30, not Game.has_saved_run(), 84))
	v.add_child(UI.button("도전 · 시험", func(): Game.goto("challenge"), 28))
	var h := UI.hbox(14)
	h.add_child(UI.expand(UI.button("도감", func(): Game.goto("codex"), 28)))
	h.add_child(UI.expand(UI.button("설정", func(): Game.goto("settings"), 28)))
	v.add_child(h)
	v.add_child(UI.label("불씨 %d · v%s" % [int(Save.meta["embers"]), ProjectSettings.get_setting("application/config/version", "1.0")], 20, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
