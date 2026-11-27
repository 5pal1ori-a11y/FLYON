extends Screen
## 무작위 이벤트: 이야기 + 선택지 + 결과.

var hud: RunHud
var body: VBoxContainer
var ev: Dictionary


func build(p: Dictionary) -> void:
	var id: String = p.get("id", "e_campfire")
	ev = EventData.EVENTS.get(id, EventData.EVENTS["e_campfire"])
	var v := UI.screen_frame(self, "")
	hud = RunHud.make(self)
	v.add_child(hud)
	body = UI.vbox(18)
	v.add_child(UI.scroll(body))
	Sfx.play("page")
	_show_intro()


func _show_intro() -> void:
	body.add_child(UI.spacer(20))
	body.add_child(UI.label(ev["title"], 44, UI.AMBER, true))
	var tp := UI.panel(22)
	tp.add_child(UI.label(ev["text"], 27))
	body.add_child(tp)
	body.add_child(UI.spacer(10))
	var r := Game.run
	for ch in ev["choices"]:
		var req: Dictionary = ch.get("req", {})
		var ok := true
		var req_txt := ""
		if req.has("oil") and r.oil < int(req["oil"]):
			ok = false
			req_txt = " (기름 %d 필요)" % int(req["oil"])
		if req.has("hp") and r.hp <= int(req["hp"]):
			ok = false
			req_txt = " (체력 부족)"
		var b := UI.button(ch["text"] + req_txt, func(): _choose(ch), 26, false, 84)
		b.disabled = not ok
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(b)


func _choose(ch: Dictionary) -> void:
	Sfx.play("ui_confirm")
	var msgs := Game.apply_outcomes(ch["out"])
	hud.refresh()
	for c in body.get_children():
		c.queue_free()
	body.add_child(UI.spacer(20))
	body.add_child(UI.label(ev["title"], 40, UI.AMBER, true))
	body.add_child(UI.label(ch["text"], 25, UI.SUB))
	var rp := UI.panel(22)
	var rv := UI.vbox(8)
	rp.add_child(rv)
	if msgs.is_empty():
		rv.add_child(UI.label("아무 일도 일어나지 않았다.", 26))
	for m in msgs:
		var col := UI.TEXT
		if m.contains("+") or m.contains("획득") or m.contains("구출"):
			col = UI.GREEN
		if m.contains("-") or m.contains("저주") or m.contains("잃었다"):
			col = UI.RED
		rv.add_child(UI.label(m, 26, col))
	body.add_child(rp)
	Game.save_run()
	body.add_child(UI.button("계속", func(): Game.finish_event(), 30, true))
