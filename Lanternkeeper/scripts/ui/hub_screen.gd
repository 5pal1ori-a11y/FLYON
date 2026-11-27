extends Screen
## 등불 오두막: 탐험 준비, 시설 업그레이드, 등불·동료 해금, 꾸미기.

var tab := "start"
var content: VBoxContainer
var embers_label: Label
var sel_char := 0
var sel_lantern := 0
var sel_asc := 0
var tab_buttons := {}


func build(p: Dictionary) -> void:
	Sfx.music("title")
	tab = p.get("tab", "start")
	var last: Dictionary = Save.meta.get("last", {})
	var chars: Array = Save.meta["chars"]
	sel_char = max(0, chars.find(last.get("char", "keeper")))
	var lans := owned_lanterns()
	sel_lantern = max(0, lans.find(last.get("lantern", "candle")))
	sel_asc = clampi(int(last.get("asc", 0)), 0, int(Save.meta["asc_unlocked"]))
	var v := UI.screen_frame(self, "등불 오두막", func(): Game.goto("title"))
	embers_label = UI.label("", 26, UI.AMBER)
	v.add_child(embers_label)
	var tabs := UI.hbox(8)
	for t in [["start", "출발"], ["facility", "시설"], ["lantern", "등불"], ["ally", "동료"], ["skin", "꾸미기"]]:
		var key: String = t[0]
		var b := UI.button(t[1], func(): _set_tab(key), 24, false, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_buttons[key] = b
	v.add_child(tabs)
	content = UI.vbox(16)
	v.add_child(UI.scroll(content))
	_refresh()


func owned_lanterns() -> Array:
	var out := []
	for l in GearData.LANTERN_ORDER:
		if Save.meta["lanterns"].has(l):
			out.append(l)
	return out


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	embers_label.text = "불씨 %d" % int(Save.meta["embers"])
	for k in tab_buttons.keys():
		var b: Button = tab_buttons[k]
		b.add_theme_color_override("font_color", UI.AMBER if k == tab else UI.SUB)
	for c in content.get_children():
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


func _row_selector(title: String, value_text: String, desc: String, on_prev: Callable, on_next: Callable) -> Control:
	var p := UI.panel(18)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label(title, 22, UI.SUB))
	var h := UI.hbox(10)
	var bp := UI.button("‹", on_prev, 36, false, 70)
	bp.custom_minimum_size = Vector2(80, 70)
	var bn := UI.button("›", on_next, 36, false, 70)
	bn.custom_minimum_size = Vector2(80, 70)
	h.add_child(bp)
	var l := UI.label(value_text, 32, UI.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(UI.expand(l))
	h.add_child(bn)
	v.add_child(h)
	v.add_child(UI.label(desc, 23, UI.TEXT))
	return p


func _tab_start() -> void:
	if Game.has_saved_run():
		var rp := UI.panel(20, UI.PANEL, UI.AMBER)
		var rv := UI.vbox(12)
		rp.add_child(rv)
		var rd: Dictionary = Save.meta["run"]
		rv.add_child(UI.label("진행 중인 탐험", 30, UI.AMBER, true))
		rv.add_child(UI.label("%d층 · 체력 %d · 기름 %d" % [int(rd["floor"]) + 1, int(rd["hp"]), int(rd["oil"])], 24))
		var h := UI.hbox()
		h.add_child(UI.expand(UI.button("이어하기", func(): Game.continue_run(), 28, true)))
		h.add_child(UI.expand(UI.button("포기", func(): confirm("탐험을 포기할까요? 불씨는 절반만 받습니다.", "포기", func():
			Game.load_saved_run()
			Game.end_run(false, true)), 26)))
		rv.add_child(h)
		content.add_child(rp)
		return
	var chars: Array = Save.meta["chars"]
	var cid: String = chars[sel_char % chars.size()]
	var cd: Dictionary = GearData.CHARACTERS[cid]
	content.add_child(_row_selector("등불지기", cd["name"], "체력 %d · 이동 %d\n%s" % [cd["hp"] + Save.facility_level("hearth"), cd["move"], cd["desc"]],
		func():
			sel_char = (sel_char - 1 + chars.size()) % chars.size()
			_refresh(),
		func():
			sel_char = (sel_char + 1) % chars.size()
			_refresh()))
	var lans := owned_lanterns()
	var lid: String = lans[sel_lantern % lans.size()]
	var ld: Dictionary = GearData.LANTERNS[lid]
	var stats := "반경 %.1f · 그림자 %d칸 · 피해 %d" % [ld["radius"], ld["length"], ld["dmg"]] if ld["mode"] != "directional" else "그림자 %d칸 · 피해 %d" % [ld["length"], ld["dmg"]]
	content.add_child(_row_selector("등불", ld["name"], stats + "\n" + ld["desc"],
		func():
			sel_lantern = (sel_lantern - 1 + lans.size()) % lans.size()
			_refresh(),
		func():
			sel_lantern = (sel_lantern + 1) % lans.size()
			_refresh()))
	var maxa := int(Save.meta["asc_unlocked"])
	if maxa > 0:
		var desc := "기본 난이도" if sel_asc == 0 else ""
		for i in sel_asc:
			desc += ("" if i == 0 else "\n") + "· " + MetaData.ASCENSION[i]["desc"]
		content.add_child(_row_selector("그을음 단계 (난이도)", "%d단계" % sel_asc, desc,
			func():
				sel_asc = (sel_asc - 1 + maxa + 1) % (maxa + 1)
				_refresh(),
			func():
				sel_asc = (sel_asc + 1) % (maxa + 1)
				_refresh()))
	else:
		content.add_child(UI.label("탑을 한 번 정복하면 그을음 단계(더 높은 난이도)가 열립니다.", 22, UI.SUB))
	content.add_child(UI.spacer(6))
	content.add_child(UI.button("탑으로 출발", func():
		Sfx.play("ignite")
		Game.new_run("normal", cid, lid, sel_asc), 34, true, 100))


func _tab_facility() -> void:
	for fid in GearData.FACILITY_ORDER:
		var fd: Dictionary = GearData.FACILITIES[fid]
		var lv := Save.facility_level(fid)
		var maxlv: int = fd["costs"].size()
		var p := UI.panel(18)
		var v := UI.vbox(8)
		p.add_child(v)
		var h := UI.hbox()
		h.add_child(UI.expand(UI.label(fd["name"], 30, UI.AMBER, true)))
		var lvl := UI.label("Lv %d/%d" % [lv, maxlv], 24, UI.SUB)
		lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(lvl)
		v.add_child(h)
		v.add_child(UI.label(fd["desc"], 23))
		var needs: String = fd["needs"]
		if needs != "" and not Save.meta["npcs"].has(needs):
			v.add_child(UI.label("필요: %s 구출 (탑 어딘가에 갇혀 있다)" % GearData.NPCS[needs]["name"], 22, UI.RED))
		elif lv >= maxlv:
			v.add_child(UI.label("최고 단계", 22, UI.GREEN))
		else:
			var cost: int = fd["costs"][lv]
			var b := UI.button("짓기 · 불씨 %d" % cost if lv == 0 else "강화 · 불씨 %d" % cost, func():
				if Save.spend_embers(cost):
					Save.meta["facilities"][fid] = lv + 1
					RunState.fac = Save.meta["facilities"]
					Save.save_meta()
					Sfx.play("coin")
					_refresh(), 26, true, 68)
			b.disabled = int(Save.meta["embers"]) < cost
			v.add_child(b)
		content.add_child(p)


func _tab_lantern() -> void:
	for lid in GearData.LANTERN_ORDER:
		var ld: Dictionary = GearData.LANTERNS[lid]
		var p := UI.panel(18)
		var v := UI.vbox(8)
		p.add_child(v)
		v.add_child(UI.label(ld["name"], 30, ld["color"], true))
		v.add_child(UI.label(ld["desc"], 23))
		if Save.meta["lanterns"].has(lid):
			v.add_child(UI.label("보유", 22, UI.GREEN))
		else:
			var cost: int = ld["cost"]
			var b := UI.button("해금 · 불씨 %d" % cost, func():
				if Save.spend_embers(cost):
					Save.meta["lanterns"].append(lid)
					Save.check_unlocks()
					Save.save_meta()
					Sfx.play("coin")
					_refresh(), 26, true, 68)
			b.disabled = int(Save.meta["embers"]) < cost
			v.add_child(b)
		content.add_child(p)


func _tab_ally() -> void:
	content.add_child(UI.label("등불지기", 26, UI.SUB))
	for cid in GearData.CHARACTER_ORDER:
		var cd: Dictionary = GearData.CHARACTERS[cid]
		var p := UI.panel(18)
		var v := UI.vbox(8)
		p.add_child(v)
		v.add_child(UI.label("%s · 체력 %d · 이동 %d" % [cd["name"], cd["hp"], cd["move"]], 28, UI.AMBER, true))
		v.add_child(UI.label(cd["desc"], 23))
		if Save.meta["chars"].has(cid):
			v.add_child(UI.label("함께하는 중", 22, UI.GREEN))
		elif int(cd["cost"]) > 0:
			var cost: int = cd["cost"]
			var b := UI.button("데려오기 · 불씨 %d" % cost, func():
				if Save.spend_embers(cost):
					Save.meta["chars"].append(cid)
					Save.check_unlocks()
					Save.save_meta()
					_refresh(), 26, true, 68)
			b.disabled = int(Save.meta["embers"]) < cost
			v.add_child(b)
		else:
			v.add_child(UI.label("조건: 거울 군주를 쓰러뜨리기", 22, UI.RED))
		content.add_child(p)
	content.add_child(UI.label("구출한 사람들", 26, UI.SUB))
	for nid in GearData.NPCS.keys():
		var nd: Dictionary = GearData.NPCS[nid]
		var ok: bool = Save.meta["npcs"].has(nid)
		content.add_child(UI.label(("● " if ok else "○ ") + (nd["name"] + " — " + nd["desc"] if ok else "??? — 탑 어딘가에 갇혀 있다"), 23, UI.TEXT if ok else UI.SUB))


func _tab_skin() -> void:
	content.add_child(UI.label("업적을 달성하면 등불 불꽃의 색이 열립니다.", 22, UI.SUB))
	for sid in GearData.SKIN_ORDER:
		var sd: Dictionary = GearData.SKINS[sid]
		var owned: bool = Save.meta["skins"].has(sid)
		var sel: bool = Save.meta["skin"] == sid
		var b := UI.button(("● " if sel else "") + sd["name"] + ("" if owned else "  (잠김 · " + sd["desc"] + ")"), func():
			Save.meta["skin"] = sid
			Save.save_meta()
			_refresh(), 26, sel, 72)
		b.disabled = not owned
		b.add_theme_color_override("font_color", sd["color"] if owned else UI.SUB)
		content.add_child(b)
