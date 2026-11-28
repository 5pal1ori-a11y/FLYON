extends Screen
## 등불 오두막: 탐험 준비, 시설, 등불·동료 해금, 꾸미기.

var tab := "start"
var content: VBoxContainer
var footer: VBoxContainer
var ember_chip: PanelContainer
var sel_char := 0
var sel_lantern := 0
var sel_asc := 0


class HutArt:
	extends Control
	var t := 0.0
	var npcs := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 196)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _glow(c: Vector2, r: float, col: Color, a: float) -> void:
		for i in 16:
			draw_circle(c, r * (i + 1) / 16.0, Color(col, a * 1.6 / 16.0))

	func _draw() -> void:
		var s := size
		var gy := s.y - 34.0
		# 땅
		var pts := PackedVector2Array()
		for i in 21:
			pts.append(Vector2(s.x * i / 20.0, gy + sin(i * 0.6) * 5))
		pts.append(Vector2(s.x, s.y))
		pts.append(Vector2(0, s.y))
		draw_colored_polygon(pts, Color("0a0914"))
		# 초가집
		var hx := s.x * 0.3
		var fl := 1.0 + 0.06 * sin(t * 6.0) + 0.04 * sin(t * 9.3)
		_glow(Vector2(hx, gy - 40), 170 * fl, Color(1, 0.62, 0.26), 0.22)
		draw_rect(Rect2(hx - 86, gy - 74, 172, 76), Color("2a2130"))
		var roof := PackedVector2Array([Vector2(hx - 116, gy - 66), Vector2(hx - 92, gy - 104), Vector2(hx - 50, gy - 128), Vector2(hx, gy - 136),
			Vector2(hx + 50, gy - 128), Vector2(hx + 92, gy - 104), Vector2(hx + 116, gy - 66)])
		draw_colored_polygon(roof, Color("4a3a26"))
		for i in 9:
			var rx := hx - 96 + i * 24
			draw_line(Vector2(rx, gy - 70), Vector2(rx + (hx - rx) * 0.35, gy - 126 + abs(rx - hx) * 0.22), Color(0.25, 0.18, 0.1, 0.6), 2)
		draw_polyline(roof, Color(0.9, 0.7, 0.4, 0.25), 2, true)
		# 불 밝힌 창호
		for wx in [hx - 52.0, hx + 20.0]:
			var wr := Rect2(wx, gy - 60, 34, 46)
			draw_rect(wr.grow(3), Color("1a120c"))
			draw_rect(wr, Color(1.0, 0.82, 0.5).lerp(Color(1, 0.7, 0.35), 0.5 + 0.5 * sin(t * 5 + wx)))
			draw_line(wr.position + Vector2(17, 0), wr.position + Vector2(17, 46), Color("2a1c10"), 2)
			for k in [15.0, 31.0]:
				draw_line(wr.position + Vector2(0, k), wr.position + Vector2(34, k), Color("2a1c10"), 2)
		# 굴뚝 연기
		for i in 4:
			var ph := fmod(t * 0.25 + i * 0.25, 1.0)
			draw_circle(Vector2(hx + 70 + sin(ph * 5 + i) * 8, gy - 136 - ph * 60), 8 + ph * 12, Color(0.7, 0.7, 0.8, 0.12 * (1.0 - ph)))
		# 모닥불과 구출한 사람들
		var fx := s.x * 0.68
		_glow(Vector2(fx, gy - 14), 120 * fl, Color(1, 0.55, 0.2), 0.3)
		draw_line(Vector2(fx - 20, gy), Vector2(fx + 16, gy - 8), Color("2a1a10"), 5)
		draw_line(Vector2(fx + 20, gy), Vector2(fx - 16, gy - 8), Color("2a1a10"), 5)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 13, gy - 6), Vector2(fx + 13, gy - 6), Vector2(fx + 3 * sin(t * 7), gy - 44 * fl)]), Color("ff8a2e"))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 7, gy - 6), Vector2(fx + 7, gy - 6), Vector2(fx + 2 * sin(t * 9), gy - 26 * fl)]), Color("ffe08a"))
		var spots := [-74.0, 58.0, -112.0, 96.0, 134.0]
		for i in npcs:
			var px: float = fx + spots[i % spots.size()]
			var hh := 40.0 + (i % 3) * 5
			draw_colored_polygon(PackedVector2Array([Vector2(px - 13, gy + 2), Vector2(px + 13, gy + 2), Vector2(px + 7, gy - hh + 12), Vector2(px - 7, gy - hh + 12)]), Color("06060c"))
			draw_circle(Vector2(px, gy - hh + 4), 9, Color("06060c"))
			draw_arc(Vector2(px, gy - hh + 4), 9, -0.6 if px < fx else PI - 0.9, 0.9 if px < fx else PI + 0.6, 8, Color(1, 0.6, 0.3, 0.5), 2, true)


class Portrait:
	extends Control
	var who := "keeper"

	func _init(w: String = "keeper", px: float = 150.0) -> void:
		who = w
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		clip_contents = true

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.49, Color(0.2, 0.12, 0.06, 0.16))
		draw_set_transform(c + Vector2(-6, -2), 0.0, Vector2.ONE)
		var sk: String = Save.meta.get("skin", "amber")
		Art.unit(self, "player", size.x * 1.02, {"t": 0.0, "who": who, "skin": GearData.SKINS.get(sk, GearData.SKINS["amber"])["color"]})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(c, size.x * 0.49, 0, TAU, 48, Color(0.3, 0.2, 0.1, 0.4), 2, true)


class Swatch:
	extends Control
	var col := Color.WHITE
	var selected := false
	var locked := false
	var prism := false
	var t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 110)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_process(prism)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 50)
		var cc := Color.from_hsv(fmod(t * 0.2, 1.0), 0.55, 1.0) if prism else col
		if locked:
			draw_circle(c, 38, Color(1, 1, 1, 0.05))
			draw_arc(c, 38, 0, TAU, 40, Color(1, 1, 1, 0.12), 1.5, true)
			Icon.paint(self, "lock", c, 28, Color(1, 1, 1, 0.3))
			return
		for i in 10:
			draw_circle(c, 56.0 * (i + 1) / 10.0, Color(cc, 0.03))
		draw_circle(c, 38, Color(0.1, 0.09, 0.17))
		Icon.paint(self, "flame", c, 46, cc)
		draw_arc(c, 38, 0, TAU, 40, cc if selected else Color(1, 1, 1, 0.18), 3.5 if selected else 1.5, true)


func build(p: Dictionary) -> void:
	Sfx.music("title")
	tab = p.get("tab", "start")
	var last: Dictionary = Save.meta.get("last", {})
	var chars: Array = Save.meta["chars"]
	sel_char = max(0, chars.find(last.get("char", "keeper")))
	sel_lantern = max(0, owned_lanterns().find(last.get("lantern", "candle")))
	sel_asc = clampi(int(last.get("asc", 0)), 0, int(Save.meta["asc_unlocked"]))
	var v := UI.screen_frame(self, "등불 오두막", func(): Game.goto("title"))
	ember_chip = UI.chip("flame", "0", UI.AMBER, 24)
	(v.get_meta("header") as HBoxContainer).add_child(ember_chip)
	var art := HutArt.new()
	art.npcs = Save.meta["npcs"].size()
	v.add_child(art)
	v.add_child(UI.tabs([["start", "출발"], ["facility", "시설"], ["lantern", "등불"], ["ally", "동료"], ["skin", "불꽃"]], tab, func(k):
		tab = k
		_refresh()))
	content = UI.vbox(16)
	v.add_child(UI.scroll(content))
	footer = UI.vbox(10)
	v.add_child(footer)
	_refresh()


func owned_lanterns() -> Array:
	var out := []
	for l in GearData.LANTERN_ORDER:
		if Save.meta["lanterns"].has(l):
			out.append(l)
	return out


func _refresh() -> void:
	UI.chip_set(ember_chip, str(int(Save.meta["embers"])))
	for c in content.get_children():
		c.queue_free()
	for c in footer.get_children():
		c.queue_free()
	match tab:
		"start":
			_tab_start()
		"facility":
			_tab_facility()
		"lantern":
			_tab_lantern()
		"ally":
			_tab_ally()
		"skin":
			_tab_skin()


func _arrows(count: int, on_step: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if count > 1:
		h.add_child(UI.icon_button("back", func(): on_step.call(-1), 52, 20))
		h.add_child(UI.icon_button("next", func(): on_step.call(1), 52, 20))
	return h


func _buy_button(cost: int, on_buy: Callable, word: String = "") -> Button:
	var b := UI.button(("%s  %d" % [word, cost]).strip_edges(), func():
		if Save.spend_embers(cost):
			on_buy.call()
			Save.check_unlocks()
			Save.save_meta()
			Sfx.play("coin")
			_refresh(), 22, true, 56, "flame")
	b.disabled = int(Save.meta["embers"]) < cost
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size.x = 170
	return b


func _tab_start() -> void:
	if Game.has_saved_run():
		var rd: Dictionary = Save.meta["run"]
		var rp := UI.paper(20)
		var rv := UI.vbox(10)
		rp.add_child(rv)
		rv.add_child(UI.title("오르던 탑이 있다", 30, UI.INK))
		var row := UI.hbox(18)
		for pair in [["tower", "%d층" % (int(rd["floor"]) + 1)], ["heart", str(int(rd["hp"]))], ["oil", str(int(rd["oil"]))]]:
			var hh := UI.hbox(6)
			hh.add_child(Icon.make(pair[0], 24, UI.INK_SUB))
			hh.add_child(UI.tag(pair[1], 24, UI.INK, true))
			row.add_child(hh)
		rv.add_child(row)
		content.add_child(rp)
		footer.add_child(UI.button("이어서 오르기", func(): Game.continue_run(), 30, true, 92, "tower"))
		footer.add_child(UI.button("이 탐험 포기하기", func(): confirm("탐험을 포기할까요?\n불씨는 절반만 받습니다.", "포기", func():
			Game.load_saved_run()
			Game.end_run(false, true)), 22, false, 60))
		return
	var chars: Array = Save.meta["chars"]
	var cid: String = chars[sel_char % chars.size()]
	var cd: Dictionary = GearData.CHARACTERS[cid]
	var cp := UI.paper(18)
	var ch := UI.hbox(18)
	cp.add_child(ch)
	ch.add_child(Portrait.new(cid, 150))
	var cv := UI.vbox(8)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cv)
	var ctop := UI.hbox(8)
	ctop.add_child(UI.expand(UI.title_wrap(cd["name"], 32, UI.INK)))
	ctop.add_child(_arrows(chars.size(), func(d):
		sel_char = (sel_char + d + chars.size()) % chars.size()
		_refresh()))
	cv.add_child(ctop)
	var stats := UI.hbox(16)
	for pair in [["heart", "체력 %d" % (int(cd["hp"]) + Save.facility_level("hearth"))], ["next", "이동 %d칸" % int(cd["move"])]]:
		var hh2 := UI.hbox(6)
		hh2.add_child(Icon.make(pair[0], 20, Color("a8402e") if pair[0] == "heart" else UI.INK_SUB))
		hh2.add_child(UI.tag(pair[1], 21, UI.INK, true))
		stats.add_child(hh2)
	cv.add_child(stats)
	cv.add_child(UI.label(cd["desc"], 21, UI.INK_SUB))
	content.add_child(cp)

	var lans := owned_lanterns()
	var lid: String = lans[sel_lantern % lans.size()]
	var ld: Dictionary = GearData.LANTERNS[lid]
	var lp := UI.paper(18)
	var lh := UI.hbox(18)
	lp.add_child(lh)
	lh.add_child(LanternDiagram.make(lid, 150))
	var lv := UI.vbox(8)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lv)
	var ltop := UI.hbox(8)
	ltop.add_child(UI.expand(UI.title_wrap(ld["name"], 32, UI.INK)))
	ltop.add_child(_arrows(lans.size(), func(d):
		sel_lantern = (sel_lantern + d + lans.size()) % lans.size()
		_refresh()))
	lv.add_child(ltop)
	lv.add_child(UI.tag("그림자 %d칸   피해 %d" % [ld["length"], ld["dmg"]], 21, UI.INK, true))
	lv.add_child(UI.label(ld["desc"], 21, UI.INK_SUB))
	content.add_child(lp)

	var maxa := int(Save.meta["asc_unlocked"])
	if maxa > 0:
		var ap := UI.panel(18)
		var av := UI.vbox(8)
		ap.add_child(av)
		var atop := UI.hbox(10)
		atop.add_child(UI.title("그을음 %d단계" % sel_asc, 28, UI.AMBER if sel_asc > 0 else UI.TEXT))
		atop.add_child(UI.grow())
		atop.add_child(_arrows(maxa + 1, func(d):
			sel_asc = (sel_asc + d + maxa + 1) % (maxa + 1)
			_refresh()))
		av.add_child(atop)
		if sel_asc == 0:
			av.add_child(UI.label("기본 난이도. 단계를 올리면 불리한 규칙이 하나씩 쌓이고 불씨를 10%씩 더 받습니다.", 20, UI.SUB))
		for i in sel_asc:
			av.add_child(UI.label("%d  %s" % [i + 1, MetaData.ASCENSION[i]["desc"]], 20, UI.TEXT if i == sel_asc - 1 else UI.SUB))
		content.add_child(ap)
	else:
		content.add_child(UI.label("탑을 한 번 정복하면 더 어려운 그을음 단계가 열립니다.", 20, UI.SUB))
	footer.add_child(UI.button("탑으로 출발", func():
		Sfx.play("ignite")
		Game.new_run("normal", cid, lid, sel_asc), 32, true, 96, "tower"))


func _tab_facility() -> void:
	for fid in GearData.FACILITY_ORDER:
		var fd: Dictionary = GearData.FACILITIES[fid]
		var lv := Save.facility_level(fid)
		var maxlv: int = fd["costs"].size()
		var needs: String = fd["needs"]
		var locked: bool = needs != "" and not Save.meta["npcs"].has(needs)
		var p := UI.panel(18)
		var v := UI.vbox(8)
		p.add_child(v)
		var h := UI.hbox(12)
		h.add_child(UI.title(fd["name"], 28, UI.SUB if locked else UI.TEXT))
		h.add_child(UI.pips(lv, maxlv))
		h.add_child(UI.grow())
		if locked:
			h.add_child(Icon.make("lock", 24, UI.SUB))
		elif lv >= maxlv:
			h.add_child(UI.tag("다 지었다", 20, UI.GREEN, true))
		else:
			var cost: int = fd["costs"][lv]
			h.add_child(_buy_button(cost, func():
				Save.meta["facilities"][fid] = lv + 1
				RunState.fac = Save.meta["facilities"], "짓기" if lv == 0 else "강화"))
		v.add_child(h)
		v.add_child(UI.label(fd["desc"], 21, UI.SUB))
		if locked:
			v.add_child(UI.label("탑 어딘가에 갇힌 %s을(를) 구해야 지을 수 있습니다." % GearData.NPCS[needs]["name"], 20, UI.RED))
		content.add_child(p)


func _tab_lantern() -> void:
	for lid in GearData.LANTERN_ORDER:
		var ld: Dictionary = GearData.LANTERNS[lid]
		var owned: bool = Save.meta["lanterns"].has(lid)
		var p := UI.paper(18, owned)
		var h := UI.hbox(18)
		p.add_child(h)
		h.add_child(LanternDiagram.make(lid, 132))
		var v := UI.vbox(8)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UI.title(ld["name"], 28, UI.INK))
		v.add_child(UI.label(ld["desc"], 21, UI.INK_SUB))
		if owned:
			v.add_child(UI.tag("가지고 있다", 20, Color("2f7a35"), true))
		else:
			v.add_child(_buy_button(int(ld["cost"]), func(): Save.meta["lanterns"].append(lid), "얻기"))
			p.modulate = Color(0.78, 0.76, 0.82)
		content.add_child(p)


func _tab_ally() -> void:
	for cid in GearData.CHARACTER_ORDER:
		var cd: Dictionary = GearData.CHARACTERS[cid]
		var owned: bool = Save.meta["chars"].has(cid)
		var p := UI.paper(18, owned)
		var h := UI.hbox(18)
		p.add_child(h)
		h.add_child(Portrait.new(cid, 120))
		var v := UI.vbox(8)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UI.title(cd["name"], 28, UI.INK))
		v.add_child(UI.label(cd["desc"], 21, UI.INK_SUB))
		if owned:
			v.add_child(UI.tag("함께하는 중", 20, Color("2f7a35"), true))
		elif int(cd["cost"]) > 0:
			v.add_child(_buy_button(int(cd["cost"]), func(): Save.meta["chars"].append(cid), "부르기"))
			p.modulate = Color(0.78, 0.76, 0.82)
		else:
			v.add_child(UI.tag("거울 군주를 쓰러뜨리면 합류한다", 20, Color("a02a1c"), true))
			p.modulate = Color(0.78, 0.76, 0.82)
		content.add_child(p)
	var np := UI.panel(18)
	var nv := UI.vbox(10)
	np.add_child(nv)
	nv.add_child(UI.title("구출한 사람들  %d / %d" % [Save.meta["npcs"].size(), GearData.NPCS.size()], 26))
	for nid in GearData.NPCS.keys():
		var nd: Dictionary = GearData.NPCS[nid]
		var ok: bool = Save.meta["npcs"].has(nid)
		var row := UI.hbox(10)
		row.add_child(Icon.make("person", 24, UI.AMBER if ok else Color(1, 1, 1, 0.2)))
		row.add_child(UI.expand(UI.label(nd["name"] + "  " + nd["desc"] if ok else "아직 탑 어딘가에 갇혀 있다", 21, UI.TEXT if ok else UI.SUB)))
		nv.add_child(row)
	content.add_child(np)


func _tab_skin() -> void:
	content.add_child(UI.label("업적을 이루면 등불 불꽃의 색이 열립니다. 팔지 않습니다.", 20, UI.SUB))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 14)
	for sid in GearData.SKIN_ORDER:
		var sd: Dictionary = GearData.SKINS[sid]
		var owned: bool = Save.meta["skins"].has(sid)
		var cell := UI.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sw := Swatch.new()
		sw.col = sd["color"]
		sw.locked = not owned
		sw.selected = Save.meta["skin"] == sid
		sw.prism = sid == "prism" and owned
		sw.mouse_filter = Control.MOUSE_FILTER_PASS
		if owned:
			sw.gui_input.connect(func(e):
				if UI.is_tap(e):
					Save.meta["skin"] = sid
					Save.save_meta()
					Sfx.play("ui_confirm")
					_refresh())
		cell.add_child(sw)
		var nm := UI.label(sd["name"] if owned else sd["desc"].replace("업적: ", ""), 18, UI.TEXT if owned else UI.SUB, owned, HORIZONTAL_ALIGNMENT_CENTER)
		cell.add_child(nm)
		grid.add_child(cell)
	content.add_child(grid)
