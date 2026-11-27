extends Screen
## 도감: 적, 각인, 유물, 이야기, 업적, 통계.

var tab := "enemies"
var content: VBoxContainer
var tab_buttons := {}


func build(_p: Dictionary) -> void:
	var v := UI.screen_frame(self, "도감", func(): Game.goto("title"))
	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	for t in [["enemies", "적"], ["insc", "각인"], ["relics", "유물"], ["story", "이야기"], ["ach", "업적"], ["stats", "기록"]]:
		var key: String = t[0]
		var b := UI.button(t[1], func():
			tab = key
			_refresh(), 24, false, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_buttons[key] = b
	v.add_child(tabs)
	content = UI.vbox(12)
	v.add_child(UI.scroll(content))
	_refresh()


func _refresh() -> void:
	for k in tab_buttons.keys():
		tab_buttons[k].add_theme_color_override("font_color", UI.AMBER if k == tab else UI.SUB)
	for c in content.get_children():
		c.queue_free()
	var cx: Dictionary = Save.meta["codex"]
	match tab:
		"enemies":
			var seen: Dictionary = cx["enemies"]
			content.add_child(UI.label("발견 %d / %d" % [seen.size(), EnemyData.ENEMIES.size()], 22, UI.SUB))
			for k in EnemyData.ENEMIES.keys():
				var d: Dictionary = EnemyData.ENEMIES[k]
				if seen.has(k):
					var p := UI.panel(16)
					var vv := UI.vbox(6)
					p.add_child(vv)
					vv.add_child(UI.label("%s%s · 체력 %d · 공격 %d · 이동 %d" % [d["name"], " (보스)" if d.get("boss", false) else "", d["hp"], d["atk"], d["move"]], 26, UI.AMBER, true))
					vv.add_child(UI.label(d["desc"], 22))
					content.add_child(p)
				else:
					content.add_child(UI.label("??? — 아직 만나지 못했다", 22, UI.SUB))
		"insc":
			var seen2: Dictionary = cx["insc"]
			content.add_child(UI.label("발견 %d / %d" % [seen2.size(), UpgradeData.INSCRIPTIONS.size()], 22, UI.SUB))
			for tag in UpgradeData.TAG_ORDER:
				content.add_child(UI.label(UI.tag_name(tag) + " 각인", 28, UI.tag_color(tag), true))
				for s in UpgradeData.SETS[tag]:
					content.add_child(UI.label("  세트 %d: %s" % [s["n"], s["desc"]], 21, UI.SUB))
				for k in UpgradeData.INSCRIPTIONS.keys():
					var d2: Dictionary = UpgradeData.INSCRIPTIONS[k]
					if d2["tag"] != tag:
						continue
					if seen2.has(k):
						content.add_child(UI.label("· %s (%s) — %s" % [d2["name"], UI.RARITY[int(d2["rarity"])], d2["desc"]], 22))
					else:
						content.add_child(UI.label("· ???", 22, UI.SUB))
		"relics":
			var seen3: Dictionary = cx["relics"]
			content.add_child(UI.label("발견 %d / %d" % [seen3.size(), UpgradeData.RELICS.size()], 22, UI.SUB))
			for k in UpgradeData.RELICS.keys():
				var r: Dictionary = UpgradeData.RELICS[k]
				if seen3.has(k):
					content.add_child(UI.label("· %s — %s" % [r["name"], r["desc"]], 22, UI.RED if r.get("curse", false) else UI.TEXT))
				else:
					content.add_child(UI.label("· ???", 22, UI.SUB))
		"story":
			var got: Array = Save.meta["story"]
			content.add_child(UI.label("이야기 조각 %d / %d" % [got.size(), MetaData.STORY.size()], 22, UI.SUB))
			for s2 in MetaData.STORY:
				if got.has(s2["id"]):
					var p2 := UI.panel(18)
					var v2 := UI.vbox(8)
					p2.add_child(v2)
					v2.add_child(UI.label(s2["title"], 28, UI.AMBER, true))
					v2.add_child(UI.label(s2["text"], 24))
					content.add_child(p2)
				else:
					content.add_child(UI.label("· 아직 열리지 않은 이야기", 22, UI.SUB))
		"ach":
			var done: Array = Save.meta["ach"]
			content.add_child(UI.label("업적 %d / %d" % [done.size(), MetaData.ACHIEVEMENTS.size()], 22, UI.SUB))
			for a in MetaData.ACHIEVEMENTS:
				var ok := done.has(a["id"])
				var prog := "%d/%d" % [min(Save.stat(a["stat"]), int(a["goal"])), int(a["goal"])]
				var line: String = ("● " if ok else "○ ") + a["name"] + " — " + a["desc"] + ("" if ok else "  (" + prog + ")")
				if a.has("skin"):
					line += "  · 보상: " + GearData.SKINS[a["skin"]]["name"]
				content.add_child(UI.label(line, 22, UI.AMBER if ok else UI.TEXT))
		"stats":
			var names := {"runs": "탐험", "wins": "정복", "deaths": "쓰러짐", "rooms": "통과한 방", "kills": "처치",
				"casts": "점화", "freezes": "굳힘", "chains": "연쇄", "perfect_rooms": "무피해 방", "embers_total": "누적 불씨",
				"max_kill_cast": "한 번 최다 처치", "endless_depth": "끝없는 탑 최고층", "puzzles": "푼 시험"}
			Save.sync_derived_stats()
			for k in names.keys():
				content.add_child(UI.label("%s  %d" % [names[k], Save.stat(k)], 26))
