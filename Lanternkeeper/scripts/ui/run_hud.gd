class_name RunHud
extends VBoxContainer
## 탐험 중 상단 정보 줄: 체력, 기름, 층, 되돌리기, 가방·메뉴 버튼.

var screen: Screen
var hp_label: Label
var info_label: Label


static func make(s: Screen) -> RunHud:
	var h := RunHud.new()
	h.screen = s
	h.add_theme_constant_override("separation", 6)
	var row := UI.hbox(10)
	h.add_child(row)
	h.hp_label = UI.label("", 30, UI.RED, true)
	h.hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(h.hp_label)
	h.info_label = UI.label("", 22, UI.AMBER)
	h.info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.info_label.clip_text = true
	h.info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(h.info_label)
	var bag := UI.button("가방", func(): h.show_bag(), 24, false, 62)
	bag.custom_minimum_size = Vector2(96, 62)
	row.add_child(bag)
	var menu := UI.button("≡", func(): h.show_menu(), 30, false, 62)
	menu.custom_minimum_size = Vector2(72, 62)
	row.add_child(menu)
	h.refresh()
	return h


func refresh(hp_override: int = -1, max_override: int = -1) -> void:
	var r := Game.run
	if r == null:
		return
	var hp := hp_override if hp_override >= 0 else r.hp
	var mx := max_override if max_override >= 0 else r.max_hp()
	hp_label.text = "♥ %d/%d" % [hp, mx]
	var fl := "%d층" % (r.floor + 1)
	if r.mode == "daily":
		fl = "일일 도전"
	elif r.mode == "weekly":
		fl = "주간 %d/%d층" % [r.floor + 1, r.floors_total]
	elif r.mode == "endless":
		fl = "끝없는 탑 %d층" % (r.floor + 1)
	info_label.text = "기름 %d · %s · %s" % [r.oil, fl, BiomeData.get_def(r.biome())["name"]]


func show_bag() -> void:
	var r := Game.run
	var v := UI.vbox(12)
	var cd: Dictionary = GearData.CHARACTERS[r.character]
	var ld: Dictionary = GearData.LANTERNS[r.lantern]
	v.add_child(UI.label("%s · %s · 그을음 %d단계 · 되돌리기 %d" % [cd["name"], ld["name"], r.asc, r.undo], 24, UI.AMBER))
	if not r.weekly.is_empty():
		for w in r.weekly:
			var wm: Dictionary = RunState.WEEKLY_MODS[int(w)]
			v.add_child(UI.label("주간 규칙 · %s: %s" % [wm["name"], wm["desc"]], 22, UI.BLUE))
	var sets := Mods.active_sets(r.inscriptions)
	if not sets.is_empty():
		v.add_child(UI.label("세트 효과", 26, UI.VIOLET, true))
		for s in sets:
			v.add_child(UI.label("· %s %d: %s" % [UI.tag_name(s["tag"]), s["n"], s["desc"]], 22, UI.tag_color(s["tag"])))
	var counts := Mods.tag_counts(r.inscriptions)
	var ct := ""
	for tg in UpgradeData.TAG_ORDER:
		if counts.has(tg):
			ct += "%s %d  " % [UI.tag_name(tg), counts[tg]]
	v.add_child(UI.label("각인 %d개   %s" % [r.inscriptions.size(), ct], 26, UI.AMBER, true))
	for id in r.inscriptions:
		var d := UpgradeData.inscription(id)
		v.add_child(UI.label("· %s — %s" % [d["name"], d["desc"]], 22, UI.tag_color(d["tag"])))
	v.add_child(UI.label("유물 %d개" % r.relics.size(), 26, UI.AMBER, true))
	for id in r.relics:
		var rd := UpgradeData.relic(id)
		v.add_child(UI.label("· %s — %s" % [rd["name"], rd["desc"]], 22, UI.RED if rd.get("curse", false) else UI.TEXT))
	screen.sheet("가방", v)


func show_menu() -> void:
	var v := UI.vbox(12)
	var dim: Control
	v.add_child(UI.button("설정", func(): Game.goto("settings", {"back": "map"}), 28))
	v.add_child(UI.button("저장하고 오두막으로", func():
		Game.save_run()
		Game.run = null
		Game.goto("hub"), 28))
	v.add_child(UI.button("탐험 포기", func(): screen.confirm("정말 포기할까요? 불씨는 절반만 받습니다.", "포기", func(): Game.end_run(false, true)), 28))
	dim = screen.sheet("메뉴", v)
