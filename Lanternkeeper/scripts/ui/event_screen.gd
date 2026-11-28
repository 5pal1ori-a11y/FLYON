extends Screen
## 무작위 이벤트: 한지 두루마리에 적힌 이야기 + 선택지 + 결과.

var hud: RunHud
var body: VBoxContainer
var ev: Dictionary


func build(p: Dictionary) -> void:
	var id: String = p.get("id", "e_campfire")
	ev = EventData.EVENTS.get(id, EventData.EVENTS["e_campfire"])
	var v := UI.screen_frame(self, "", Callable(), Game.run.biome())
	hud = RunHud.make(self)
	v.add_child(hud)
	body = UI.vbox(16)
	v.add_child(UI.scroll(body))
	Sfx.play("page")
	_show_intro()


func _scroll_paper(text: String) -> PanelContainer:
	var tp := UI.paper(26)
	tp.add_child(UI.story(text, 26, UI.INK))
	return tp


func _show_intro() -> void:
	body.add_child(UI.spacer(8))
	body.add_child(UI.title_wrap(ev["title"], 42, Color("ffd9a0")))
	var paper := _scroll_paper(ev["text"])
	body.add_child(paper)
	UI.light_up([paper], 0.0)
	body.add_child(UI.spacer(4))
	var r := Game.run
	for ch in ev["choices"]:
		var req: Dictionary = ch.get("req", {})
		var ok := true
		var why := ""
		if req.has("oil") and r.oil < int(req["oil"]):
			ok = false
			why = "  (기름 %d 필요)" % int(req["oil"])
		if req.has("hp") and r.hp <= int(req["hp"]):
			ok = false
			why = "  (체력 부족)"
		var b := UI.button(ch["text"] + why, func(): _choose(ch), 24, false, 80)
		b.disabled = not ok
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(b)


func _choose(ch: Dictionary) -> void:
	Sfx.play("ui_confirm")
	var msgs := Game.apply_outcomes(ch["out"])
	hud.refresh()
	for c in body.get_children():
		c.queue_free()
	body.add_child(UI.spacer(8))
	body.add_child(UI.title_wrap(ev["title"], 42, Color("ffd9a0")))
	body.add_child(UI.story(ch["text"], 23, UI.SUB))
	var rp := UI.paper(24)
	var rv := UI.vbox(12)
	rp.add_child(rv)
	if msgs.is_empty():
		rv.add_child(UI.story("아무 일도 일어나지 않았다.", 25, UI.INK))
	for m in msgs:
		var good: bool = m.contains("+") or m.contains("획득") or m.contains("구출")
		var bad: bool = m.contains("-") or m.contains("저주") or m.contains("잃었다")
		if m.begins_with("—"):
			rv.add_child(UI.story(m.replace("—", "").strip_edges(), 22, UI.INK_SUB))
			continue
		var row := UI.hbox(10)
		var col := Color("2f7a35") if good and not bad else (Color("a02a1c") if bad else UI.INK)
		row.add_child(Icon.make("check" if good and not bad else ("close" if bad else "stay"), 20, col))
		row.add_child(UI.expand(UI.label(m, 24, col, true)))
		rv.add_child(row)
	body.add_child(rp)
	Game.save_run()
	body.add_child(UI.button("계속 오른다", func(): Game.finish_event(), 28, true, 84, "next"))
