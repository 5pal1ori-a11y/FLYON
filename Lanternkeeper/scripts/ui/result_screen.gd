extends Screen
## 탐험 결과: 정산, 새로 열린 것, 도전 결과 공유.


class Emblem:
	extends Control
	var lit := true
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 230)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 126)
		var col := Color("ffb65c") if lit else Color("5a5870")
		if lit:
			var fl := 1.0 + 0.05 * sin(t * 6.0)
			for i in 20:
				draw_circle(c, 210.0 * fl * (i + 1) / 20.0, Color(1, 0.6, 0.24, 0.025))
		draw_arc(c + Vector2(0, -84), 20, PI, TAU, 16, Color("2a1c12"), 7, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-52, -66), c + Vector2(52, -66), c + Vector2(34, -84), c + Vector2(-34, -84)]), Color("2a1c12"))
		draw_rect(Rect2(c + Vector2(-46, -66), Vector2(92, 132)), Color("2a1c12"))
		draw_rect(Rect2(c + Vector2(-36, -56), Vector2(72, 112)), Color("f6e3b4") if lit else Color("1b1a26"))
		for x in [-12.0, 12.0]:
			draw_line(c + Vector2(x, -56), c + Vector2(x, 56), Color("2a1c12"), 4)
		draw_rect(Rect2(c + Vector2(-54, 66), Vector2(108, 14)), Color("2a1c12"))
		if lit:
			var sway := sin(t * 7.0) * 4.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 40), c + Vector2(16, 40), c + Vector2(sway, -24)]), Color("ff9a3a"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 40), c + Vector2(8, 40), c + Vector2(sway * 0.6, 4)]), Color("fff2c0"))
		else:
			for i in 3:
				var ph := fmod(t * 0.3 + i * 0.33, 1.0)
				draw_circle(c + Vector2(sin(ph * 6 + i) * 10, -96 - ph * 60), 6 + ph * 10, Color(0.7, 0.7, 0.8, 0.14 * (1.0 - ph)))


func build(p: Dictionary) -> void:
	Sfx.music("title")
	var v := UI.screen_frame(self, "")
	var victory: bool = p.get("victory", false)
	var mode: String = p.get("mode", "normal")
	var em := Emblem.new()
	em.lit = victory
	v.add_child(em)
	var text := "탑을 밝혔다" if victory else ("탐험을 접었다" if p.get("abandoned", false) else "등불이 꺼졌다")
	if mode == "endless" and not p.get("abandoned", false):
		text = "끝없는 탑 %d층" % (int(p.get("floor", 0)) + 1)
	v.add_child(UI.title_wrap(text, 52, Color("ffd9a0") if victory else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var chips := UI.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	var mode_name := {"normal": "탐험", "daily": "일일 도전", "weekly": "주간 도전", "endless": "끝없는 탑"}
	chips.add_child(UI.chip("tower", mode_name.get(mode, ""), UI.SUB, 19))
	chips.add_child(UI.chip("person", GearData.CHARACTERS[p.get("character", "keeper")]["name"], UI.SUB, 19))
	chips.add_child(UI.chip("lantern", GearData.LANTERNS[p.get("lantern", "candle")]["name"], UI.SUB, 19))
	if int(p.get("asc", 0)) > 0:
		chips.add_child(UI.chip("flame", "그을음 %d" % int(p["asc"]), UI.AMBER, 19))
	v.add_child(chips)
	var body := UI.vbox(14)
	v.add_child(UI.scroll(body))
	var sp := UI.paper(24)
	var sv := UI.vbox(10)
	sp.add_child(sv)
	sv.add_child(UI.stat_row("오른 층", str(int(p.get("floor", 0)) + (0 if victory and mode != "endless" else 1))))
	sv.add_child(UI.stat_row("밝힌 방", str(p.get("rooms", 0))))
	sv.add_child(UI.stat_row("쓰러뜨린 엘리트와 보스", "%d, %d" % [p.get("elites", 0), p.get("bosses", 0)]))
	sv.add_child(UI.stat_row("물리친 적", str(p.get("kills", 0))))
	if mode == "daily" or mode == "weekly":
		sv.add_child(UI.stat_row("점수", str(int(p.get("score", 0))), UI.INK, UI.INK, 30))
	var line := ColorRect.new()
	line.color = Color(0.3, 0.2, 0.1, 0.25)
	line.custom_minimum_size = Vector2(0, 1.5)
	sv.add_child(line)
	var er := UI.hbox(8)
	er.add_child(Icon.make("flame", 30, Color("c0661a")))
	er.add_child(UI.expand(UI.title("얻은 불씨", 28, UI.INK)))
	var gain := UI.title("+%d" % int(p.get("embers", 0)), 34, Color("b0500f"))
	gain.autowrap_mode = TextServer.AUTOWRAP_OFF
	er.add_child(gain)
	sv.add_child(er)
	body.add_child(sp)
	UI.light_up([sp], 0.0)
	var unlocks: Array = p.get("unlocks", [])
	if not unlocks.is_empty():
		var up := UI.panel(18)
		var uv := UI.vbox(10)
		up.add_child(uv)
		uv.add_child(UI.title("새로 열렸다", 26, UI.VIOLET))
		var names := {"ach": ["crown", "업적", Color("ffd66a")], "story": ["book", "이야기", UI.BLUE], "skin": ["flame", "불꽃", Color("ffd66a")], "char": ["person", "동료", UI.GREEN]}
		for u in unlocks:
			var d: Array = names.get(u["kind"], ["star", "", UI.TEXT])
			var row := UI.hbox(10)
			row.add_child(Icon.make(d[0], 22, d[2]))
			row.add_child(UI.tag(d[1], 20, d[2], true))
			row.add_child(UI.expand(UI.label(u["title"], 21, UI.TEXT)))
			uv.add_child(row)
		body.add_child(up)
	if mode == "daily" or mode == "weekly":
		var sb := UI.button("결과 복사", func():
			DisplayServer.clipboard_set(_share_text(p))
			Game.toast("결과를 복사했습니다", "info"), 24, false, 68, "scroll")
		UI.style_button(sb, "ghost", "scroll")
		body.add_child(sb)
	v.add_child(UI.button("오두막으로 돌아간다", func(): Game.goto("hub"), 28, true, 88, "house"))
	Sfx.play("win" if victory else "lose")


func _share_text(p: Dictionary) -> String:
	var bar := ""
	var rooms := int(p.get("rooms", 0))
	for i in 8:
		bar += "■" if i < rooms else "□"
	var mode_name := "일일 도전 " + str(p.get("date", "")) if p.get("mode") == "daily" else "주간 도전"
	return "등불지기 %s\n%s\n점수 %d  처치 %d  %s" % [mode_name, bar, int(p.get("score", 0)), int(p.get("kills", 0)),
		"탑을 밝혔다" if p.get("victory", false) else "도전 중"]
