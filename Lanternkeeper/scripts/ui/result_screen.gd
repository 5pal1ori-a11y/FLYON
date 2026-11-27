extends Screen
## 탐험 결과: 정산, 새로 열린 것, 일일 도전 결과 공유.


func build(p: Dictionary) -> void:
	Sfx.music("title")
	var v := UI.screen_frame(self, "")
	var victory: bool = p.get("victory", false)
	var title := "탑을 정복했다!" if victory else ("탐험 포기" if p.get("abandoned", false) else "등불이 꺼졌다")
	v.add_child(UI.spacer(30))
	v.add_child(UI.label(title, 56, UI.AMBER if victory else UI.RED, true, HORIZONTAL_ALIGNMENT_CENTER))
	var mode: String = p.get("mode", "normal")
	var mode_name := {"normal": "탐험", "daily": "일일 도전", "weekly": "주간 도전", "endless": "끝없는 탑"}
	v.add_child(UI.label("%s · %s · %s · 그을음 %d" % [mode_name.get(mode, ""), GearData.CHARACTERS[p.get("character", "keeper")]["name"],
		GearData.LANTERNS[p.get("lantern", "candle")]["name"], int(p.get("asc", 0))], 24, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	var body := UI.vbox(12)
	v.add_child(UI.scroll(body))
	var sp := UI.panel(22)
	var sv := UI.vbox(8)
	sp.add_child(sv)
	sv.add_child(UI.label("도달한 층  %d" % (int(p.get("floor", 0)) + (0 if victory and mode != "endless" else 1)), 28))
	sv.add_child(UI.label("통과한 방  %d   (엘리트 %d · 보스 %d)" % [p.get("rooms", 0), p.get("elites", 0), p.get("bosses", 0)], 28))
	sv.add_child(UI.label("물리친 적  %d" % p.get("kills", 0), 28))
	if mode == "daily" or mode == "weekly":
		sv.add_child(UI.label("점수  %d" % int(p.get("score", 0)), 34, UI.AMBER, true))
	sv.add_child(UI.label("불씨 +%d" % int(p.get("embers", 0)), 34, UI.AMBER, true))
	body.add_child(sp)
	var unlocks: Array = p.get("unlocks", [])
	if not unlocks.is_empty():
		body.add_child(UI.label("새로 열린 것", 28, UI.VIOLET, true))
		var names := {"ach": "업적", "story": "이야기", "skin": "꾸미기", "char": "동료"}
		for u in unlocks:
			body.add_child(UI.label("· %s: %s" % [names.get(u["kind"], ""), u["title"]], 24))
	var ins: Array = p.get("inscriptions", [])
	if not ins.is_empty():
		var t := ""
		for id in ins:
			t += UpgradeData.inscription(id)["name"] + " · "
		body.add_child(UI.label("새긴 각인: " + t.trim_suffix(" · "), 22, UI.SUB))
	if mode == "daily" or mode == "weekly":
		body.add_child(UI.button("결과 복사하기", func():
			DisplayServer.clipboard_set(_share_text(p))
			Game.toast("결과를 복사했습니다", "info"), 26))
	var h := UI.hbox(14)
	h.add_child(UI.expand(UI.button("오두막으로", func(): Game.goto("hub"), 30, true, 90)))
	v.add_child(h)
	Sfx.play("win" if victory else "lose")


func _share_text(p: Dictionary) -> String:
	var bar := ""
	var rooms := int(p.get("rooms", 0))
	for i in 8:
		bar += "■" if i < rooms else "□"
	var mode_name := "일일 도전 " + str(p.get("date", "")) if p.get("mode") == "daily" else "주간 도전"
	return "등불지기 %s\n%s\n점수 %d · 처치 %d · %s" % [mode_name, bar, int(p.get("score", 0)), int(p.get("kills", 0)),
		"정복!" if p.get("victory", false) else "도전 중"]
