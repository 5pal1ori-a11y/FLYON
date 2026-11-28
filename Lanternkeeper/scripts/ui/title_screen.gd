extends Screen
## 첫 화면: 밤의 탑, 등불지기, 세로로 쓴 제목. 등불이 켜지며 화면이 열린다.


class TitleArt:
	extends Control
	var t := 0.0
	var lit := 0.0
	var embers := []
	var stars := []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 34:
			embers.append([r.randf(), r.randf(), r.randf_range(0.02, 0.055), r.randf_range(1.4, 3.4), r.randf() * 10])
		for i in 70:
			stars.append([r.randf(), r.randf() * 0.55, r.randf_range(0.8, 2.0), r.randf() * 6.28])

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _hill(base: float, amp: float, freq: float, phase: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 25:
			var x := size.x * i / 24.0
			pts.append(Vector2(x, base + sin(i * freq + phase) * amp + sin(i * freq * 2.3 + phase) * amp * 0.35))
		pts.append(Vector2(size.x, size.y))
		pts.append(Vector2(0, size.y))
		draw_colored_polygon(pts, col)

	func _glow(c: Vector2, r: float, col: Color, a: float) -> void:
		var n := 22
		for i in n:
			draw_circle(c, r * (i + 1) / n, Color(col, a * 1.6 / n))

	func _draw() -> void:
		var s := size
		for i in 28:
			var a := i / 28.0
			draw_rect(Rect2(0, s.y * a, s.x, s.y / 28.0 + 1), Color("08081a").lerp(Color("332c62"), pow(clampf(a / 0.62, 0.0, 1.0), 1.6)))
		for st in stars:
			var tw: float = 0.55 + 0.45 * sin(t * 1.3 + st[3])
			draw_circle(Vector2(st[0] * s.x, st[1] * s.y), st[2], Color(0.85, 0.88, 1.0, 0.5 * tw))
		# 달
		var moon := Vector2(s.x * 0.74, s.y * 0.16)
		_glow(moon, 190, Color(0.75, 0.8, 1.0), 0.16)
		draw_circle(moon, 54, Color("e9e4d2"))
		draw_circle(moon + Vector2(-14, -10), 9, Color(0.78, 0.76, 0.68, 0.5))
		draw_circle(moon + Vector2(16, 14), 13, Color(0.78, 0.76, 0.68, 0.4))
		var base_y := s.y * 0.6
		_hill(base_y - 60, 26, 0.5, 0.4, Color("1f1b40"))
		_hill(base_y - 10, 18, 0.7, 2.1, Color("141230"))
		# 층층이 쌓인 탑
		var cx := s.x * 0.42
		var ty := base_y + 36.0
		var body := Color("090816")
		var edge := Color(0.72, 0.78, 1.0, 0.22)
		for i in 5:
			var bw := 168.0 - i * 26.0
			var bh := 84.0 - i * 6.0
			var rw := bw + 64.0
			draw_rect(Rect2(cx - bw / 2, ty - bh, bw, bh), body)
			var ry := ty - bh
			var roof := PackedVector2Array([Vector2(cx - rw / 2 - 10, ry - 8), Vector2(cx - rw / 2 + 14, ry + 2), Vector2(cx + rw / 2 - 14, ry + 2),
				Vector2(cx + rw / 2 + 10, ry - 8), Vector2(cx + bw / 2 - 8, ry - 24), Vector2(cx - bw / 2 + 8, ry - 24)])
			draw_colored_polygon(roof, body)
			draw_line(Vector2(cx - bw / 2 + 8, ry - 24), Vector2(cx + bw / 2 - 8, ry - 24), edge, 2, true)
			draw_line(Vector2(cx + bw / 2 - 8, ry - 24), Vector2(cx + rw / 2 + 10, ry - 8), edge, 2, true)
			var on := i % 2 == 0 or sin(t * 0.6 + i) > 0.6
			var wr := Rect2(cx - 13, ty - bh * 0.72, 26, bh * 0.46)
			if on:
				_glow(wr.get_center(), 44, Color(1, 0.65, 0.3), 0.22 * lit)
				draw_rect(wr, Color("14122a").lerp(Color(1, 0.76, 0.42), lit))
				draw_line(wr.position + Vector2(13, 0), wr.position + Vector2(13, wr.size.y), Color(0.2, 0.12, 0.06), 2)
				draw_line(wr.position + Vector2(0, wr.size.y * 0.5), wr.position + Vector2(26, wr.size.y * 0.5), Color(0.2, 0.12, 0.06), 2)
			else:
				draw_rect(wr, Color("14122a"))
			ty = ry - 24
		draw_line(Vector2(cx, ty), Vector2(cx, ty - 46), body, 6)
		draw_circle(Vector2(cx, ty - 20), 8, body)
		_hill(base_y + 34, 12, 0.6, 5.0, Color("08070f"))
		# 등불지기
		var p := Vector2(s.x * 0.2, base_y + 52)
		var fl := 1.0 + 0.05 * sin(t * 6.1) + 0.03 * sin(t * 9.7)
		var lp := p + Vector2(-26, -34)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(12, 0), p + Vector2(250, 330), p + Vector2(100, 330)]),
			Color(0.16, 0.08, 0.3, 0.75 * lit))
		_glow(lp, 230 * fl, Color(1, 0.66, 0.3), 0.3 * lit)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 0), p + Vector2(16, 0), p + Vector2(9, -44), p + Vector2(-9, -44)]), Color("05050a"))
		draw_circle(p + Vector2(0, -52), 12, Color("05050a"))
		draw_line(p + Vector2(-8, -34), lp + Vector2(0, -10), Color("05050a"), 3)
		draw_rect(Rect2(lp - Vector2(8, 10), Vector2(16, 20)), Color("1a100a"))
		draw_rect(Rect2(lp - Vector2(5, 7), Vector2(10, 14)), Color(1, 0.84, 0.5).lerp(Color("1a100a"), 1.0 - lit))
		for e in embers:
			var y := fmod(e[1] - t * e[2] + 1.0, 1.0)
			var x: float = e[0] + sin(t * 0.7 + e[4]) * 0.02
			draw_circle(Vector2(x * s.x, y * s.y), e[3], Color(1, 0.65, 0.3, 0.55 * sin(y * PI) * lit))
		# 아래쪽을 어둡게 눌러 버튼이 읽히게
		for i in 16:
			var a2 := i / 16.0
			draw_rect(Rect2(0, s.y * (0.6 + 0.4 * a2), s.x, s.y * 0.4 / 16.0 + 1), Color(0.03, 0.03, 0.06, 0.8 * a2))


func build(_p: Dictionary) -> void:
	Sfx.music("title")
	var art := TitleArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	# 세로쓰기 제목 (오른쪽 위)
	var col := UI.vbox(-6)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -170
	col.offset_right = -44
	col.offset_top = 250 + Game.safe_top
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var chars := []
	for ch in "등불지기":
		var l := UI.title(ch, 104, Color("ffd9a0"), HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_shadow_color", Color(1, 0.5, 0.15, 0.4))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 22)
		l.modulate.a = 0.0
		col.add_child(l)
		chars.append(l)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 44)
	m.add_theme_constant_override("margin_right", 44)
	m.add_theme_constant_override("margin_top", 40 + Game.safe_top)
	m.add_theme_constant_override("margin_bottom", 36 + Game.safe_bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := UI.vbox(14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	v.add_child(UI.grow())
	var menu := UI.vbox(14)
	v.add_child(menu)
	menu.add_child(UI.label("그림자로 싸우는 퍼즐 로그라이트", 22, Color(0.9, 0.84, 0.74, 0.8)))
	if Game.has_saved_run():
		var rd: Dictionary = Save.meta["run"]
		menu.add_child(UI.button("이어서 오르기  %d층" % (int(rd["floor"]) + 1), func(): Game.continue_run(), 30, true, 92, "tower"))
		menu.add_child(UI.button("등불 오두막", func(): Game.goto("hub"), 26, false, 76, "house"))
	else:
		menu.add_child(UI.button("등불 오두막으로", func(): Game.goto("hub"), 30, true, 92, "house"))
	var h := UI.hbox(12)
	h.add_child(UI.expand(UI.button("도전", func(): Game.goto("challenge"), 24, false, 72, "flag")))
	h.add_child(UI.expand(UI.button("도감", func(): Game.goto("codex"), 24, false, 72, "book")))
	h.add_child(UI.expand(UI.button("설정", func(): Game.goto("settings"), 24, false, 72, "gear")))
	menu.add_child(h)
	var foot := UI.hbox(8)
	foot.add_child(Icon.make("flame", 20, UI.AMBER))
	foot.add_child(UI.tag("불씨 %d" % int(Save.meta["embers"]), 20, UI.AMBER, true))
	foot.add_child(UI.grow())
	foot.add_child(UI.tag("v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 18, Color(1, 1, 1, 0.3)))
	menu.add_child(foot)
	# 여는 연출: 등불이 켜지고, 제목이 한 글자씩 떠오르고, 메뉴가 나타난다
	menu.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func(): Sfx.play("ignite", 1.0, 0.7))
	tw.tween_property(art, "lit", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	for l in chars:
		tw.tween_property(l, "modulate:a", 1.0, 0.16)
	tw.tween_property(menu, "modulate:a", 1.0, 0.3)
