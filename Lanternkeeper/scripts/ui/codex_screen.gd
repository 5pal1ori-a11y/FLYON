extends Screen
## 도감: 적, 각인, 유물, 이야기, 업적, 기록.

var tab := "enemies"
var content: VBoxContainer


class Shade:
	extends Control
	## 한지 위 그림자극처럼 적을 보여 준다.
	var kind := "rat"
	var boss := false

	func _init(k: String = "rat", b: bool = false) -> void:
		kind = k
		boss = b
		custom_minimum_size = Vector2(0, 124)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4)
		draw_circle(c, 56, Color(0.25, 0.15, 0.06, 0.12))
		draw_set_transform(c, 0.0, Vector2.ONE * (0.82 if boss else 1.0))
		Art.unit(self, kind, 104.0, {"t": 0.6, "facing": Vector2i(0, 1)})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func build(p: Dictionary) -> void:
	tab = p.get("tab", "enemies")
	var v := UI.screen_frame(self, "도감", func(): Game.goto("title"))
	v.add_child(UI.tabs([["enemies", "적"], ["insc", "각인"], ["relics", "유물"], ["story", "이야기"], ["ach", "업적"], ["stats", "기록"]], tab, func(k):
		tab = k
		_refresh(), 20))
	content = UI.vbox(12)
	v.add_child(UI.scroll(content))
	_refresh()


func _count(n: int, total: int) -> void:
	var h := UI.hbox(10)
	h.add_child(UI.tag("%d / %d" % [n, total], 20, UI.AMBER, true))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = total
	bar.value = n
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.08), 4, Color(0, 0, 0, 0), 0, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.AMBER, 4, Color(0, 0, 0, 0), 0, 0))
	h.add_child(bar)
	content.add_child(h)


func _unknown(text: String) -> void:
	var row := UI.hbox(10)
	row.add_child(Icon.make("lock", 20, Color(1, 1, 1, 0.22)))
	row.add_child(UI.label(text, 20, Color(1, 1, 1, 0.3)))
	content.add_child(row)


func _refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	var cx: Dictionary = Save.meta["codex"]
	match tab:
		"enemies":
			var seen: Dictionary = cx["enemies"]
			_count(seen.size(), EnemyData.ENEMIES.size())
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 12)
			for k in EnemyData.ENEMIES.keys():
				var d: Dictionary = EnemyData.ENEMIES[k]
				if seen.has(k):
					var p := UI.paper(12, false)
					p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var vv := UI.vbox(4)
					p.add_child(vv)
					vv.add_child(Shade.new(k, d.get("boss", false)))
					vv.add_child(UI.title_wrap(d["name"], 24, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
					var st := UI.hbox(10)
					st.alignment = BoxContainer.ALIGNMENT_CENTER
					for pair in [["heart", d["hp"], Color("a8402e")], ["sword", d["atk"], UI.INK_SUB], ["next", d["move"], UI.INK_SUB]]:
						var hh := UI.hbox(3)
						hh.add_child(Icon.make(pair[0], 17, pair[2]))
						hh.add_child(UI.tag(str(pair[1]), 19, UI.INK, true))
						st.add_child(hh)
					vv.add_child(st)
					vv.add_child(UI.label(d["desc"], 18, UI.INK_SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
					grid.add_child(p)
				else:
					var q := UI.panel(12)
					q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					q.custom_minimum_size = Vector2(0, 200)
					var qc := CenterContainer.new()
					q.add_child(qc)
					qc.add_child(Icon.make("question", 54, Color(1, 1, 1, 0.14)))
					grid.add_child(q)
			content.add_child(grid)
		"insc":
			var seen2: Dictionary = cx["insc"]
			_count(seen2.size(), UpgradeData.INSCRIPTIONS.size())
			for tg in UpgradeData.TAG_ORDER:
				var col := UI.tag_color(tg)
				var head := UI.hbox(10)
				head.add_child(Icon.make_badge(UI.TAG_ICON[tg], 44, Color(col, 0.2), col))
				head.add_child(UI.title(UI.tag_name(tg), 28, col))
				content.add_child(head)
				for s in UpgradeData.SETS[tg]:
					content.add_child(UI.label("%d개 모으면  %s" % [s["n"], s["desc"]], 19, UI.SUB))
				var p2 := UI.panel(16)
				var v2 := UI.vbox(10)
				p2.add_child(v2)
				for k in UpgradeData.INSCRIPTIONS.keys():
					var d2: Dictionary = UpgradeData.INSCRIPTIONS[k]
					if d2["tag"] != tg:
						continue
					if seen2.has(k):
						var t2 := UI.vbox(1)
						t2.add_child(UI.label(d2["name"], 21, UI.TEXT, true))
						t2.add_child(UI.label(d2["desc"], 19, UI.SUB))
						v2.add_child(t2)
					else:
						v2.add_child(UI.label("아직 보지 못한 각인", 19, Color(1, 1, 1, 0.25)))
				content.add_child(p2)
		"relics":
			var seen3: Dictionary = cx["relics"]
			_count(seen3.size(), UpgradeData.RELICS.size())
			for k in UpgradeData.RELICS.keys():
				var r: Dictionary = UpgradeData.RELICS[k]
				if seen3.has(k):
					var curse: bool = r.get("curse", false)
					var c3 := UI.RED if curse else UI.BRASS
					var row := UI.hbox(12)
					row.add_child(Icon.make_badge("horn" if curse else "star", 40, Color(c3, 0.2), c3))
					var t3 := UI.vbox(1)
					t3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					t3.add_child(UI.label(r["name"], 21, UI.TEXT, true))
					t3.add_child(UI.label(r["desc"], 19, UI.SUB))
					row.add_child(t3)
					content.add_child(row)
				else:
					_unknown("아직 얻지 못한 유물")
		"story":
			var got: Array = Save.meta["story"]
			_count(got.size(), MetaData.STORY.size())
			for s2 in MetaData.STORY:
				if got.has(s2["id"]):
					var p3 := UI.paper(22, false)
					var v3 := UI.vbox(10)
					p3.add_child(v3)
					v3.add_child(UI.title_wrap(s2["title"], 28, UI.INK))
					v3.add_child(UI.story(s2["text"], 23, UI.INK))
					content.add_child(p3)
				else:
					_unknown("아직 열리지 않은 이야기")
		"ach":
			var done: Array = Save.meta["ach"]
			_count(done.size(), MetaData.ACHIEVEMENTS.size())
			for a in MetaData.ACHIEVEMENTS:
				var ok := done.has(a["id"])
				var row2 := UI.hbox(12)
				var gold := Color("ffd66a")
				row2.add_child(Icon.make_badge("crown" if ok else "lock", 40, Color(gold, 0.2) if ok else Color(1, 1, 1, 0.05), gold if ok else Color(1, 1, 1, 0.25)))
				var t4 := UI.vbox(1)
				t4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				t4.add_child(UI.label(a["name"], 21, UI.TEXT if ok else UI.SUB, true))
				var desc: String = a["desc"]
				if a.has("skin"):
					desc += "  (보상: " + GearData.SKINS[a["skin"]]["name"] + ")"
				t4.add_child(UI.label(desc, 19, UI.SUB))
				row2.add_child(t4)
				if not ok:
					row2.add_child(UI.tag("%d/%d" % [min(Save.stat(a["stat"]), int(a["goal"])), int(a["goal"])], 19, UI.SUB, true))
				content.add_child(row2)
		"stats":
			var names := [["runs", "떠난 탐험"], ["wins", "탑을 밝힌 횟수"], ["deaths", "쓰러진 횟수"], ["rooms", "밝힌 방"], ["kills", "물리친 적"],
				["casts", "점화"], ["freezes", "굳힌 적"], ["chains", "연쇄"], ["perfect_rooms", "한 대도 맞지 않은 방"], ["max_kill_cast", "한 번에 가장 많이 물리친 수"],
				["embers_total", "모은 불씨"], ["endless_depth", "끝없는 탑 최고층"], ["puzzles", "푼 시험"]]
			Save.sync_derived_stats()
			var p4 := UI.paper(22, false)
			var v4 := UI.vbox(10)
			p4.add_child(v4)
			for pair in names:
				v4.add_child(UI.stat_row(pair[1], str(Save.stat(pair[0]))))
			content.add_child(p4)
