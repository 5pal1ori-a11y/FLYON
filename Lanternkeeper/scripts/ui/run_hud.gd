class_name RunHud
extends HBoxContainer
## 탐험 중 상단 줄: 체력, 기름, 현재 위치, 가방·메뉴.

var screen: Screen
var hp_chip: PanelContainer
var oil_chip: PanelContainer
var place: Label


static func make(s: Screen) -> RunHud:
	var h := RunHud.new()
	h.screen = s
	h.add_theme_constant_override("separation", 8)
	h.hp_chip = UI.chip("heart", "", UI.RED, 24)
	h.add_child(h.hp_chip)
	h.oil_chip = UI.chip("oil", "", UI.AMBER, 24)
	h.add_child(h.oil_chip)
	h.place = UI.tag("", 20, UI.SUB, true)
	h.place.clip_text = true
	h.place.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(h.place)
	h.add_child(UI.icon_button("bag", func(): h.show_bag(), 58, 24))
	h.add_child(UI.icon_button("menu", func(): h.show_menu(), 58, 22))
	h.refresh()
	return h


func refresh(hp_override: int = -1, max_override: int = -1) -> void:
	var r := Game.run
	if r == null:
		return
	var hp := hp_override if hp_override >= 0 else r.hp
	var mx := max_override if max_override >= 0 else r.max_hp()
	UI.chip_set(hp_chip, "%d/%d" % [hp, mx])
	UI.chip_set(oil_chip, str(r.oil))
	var fl := "%d층" % (r.floor + 1)
	if r.mode == "daily":
		fl = "일일 도전"
	elif r.mode == "weekly":
		fl = "주간 %d/%d층" % [r.floor + 1, r.floors_total]
	elif r.mode == "endless":
		fl = "끝없는 탑 %d층" % (r.floor + 1)
	place.text = "%s  %s" % [fl, BiomeData.get_def(r.biome())["name"]]


func _line(v: VBoxContainer, icon: String, col: Color, head: String, body: String) -> void:
	var row := UI.hbox(12)
	var ic := Icon.make_badge(icon, 40, Color(col, 0.2), col)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label(head, 22, UI.TEXT, true))
	t.add_child(UI.label(body, 20, UI.SUB))
	row.add_child(t)
	v.add_child(row)


func show_bag() -> void:
	var r := Game.run
	var v := UI.vbox(14)
	var cd: Dictionary = GearData.CHARACTERS[r.character]
	var ld: Dictionary = GearData.LANTERNS[r.lantern]
	var top := UI.hbox(8)
	top.add_child(UI.chip("person", cd["name"], UI.TEXT, 20))
	top.add_child(UI.chip("lantern", ld["name"], UI.AMBER, 20))
	top.add_child(UI.chip("undo", "되돌리기 %d" % r.undo, UI.BLUE, 20))
	v.add_child(top)
	if r.asc > 0:
		v.add_child(UI.label("그을음 %d단계" % r.asc, 20, UI.AMBER, true))
	for w in r.weekly:
		var wm: Dictionary = RunState.WEEKLY_MODS[int(w)]
		_line(v, "calendar", UI.BLUE, "주간 규칙: " + wm["name"], wm["desc"])
	var sets := Mods.active_sets(r.inscriptions)
	if not sets.is_empty():
		v.add_child(UI.title("켜진 세트 효과", 24, UI.VIOLET))
		for s in sets:
			_line(v, UI.TAG_ICON.get(s["tag"], "star"), UI.tag_color(s["tag"]), "%s %d개" % [UI.tag_name(s["tag"]), s["n"]], s["desc"])
	v.add_child(UI.title("각인 %d" % r.inscriptions.size(), 24, UI.AMBER))
	if r.inscriptions.is_empty():
		v.add_child(UI.label("아직 새긴 각인이 없습니다. 방을 정복하면 하나씩 고를 수 있습니다.", 20, UI.SUB))
	for id in r.inscriptions:
		var d := UpgradeData.inscription(id)
		_line(v, UI.TAG_ICON.get(d["tag"], "star"), UI.tag_color(d["tag"]), d["name"], d["desc"])
	v.add_child(UI.title("유물 %d" % r.relics.size(), 24, UI.AMBER))
	if r.relics.is_empty():
		v.add_child(UI.label("엘리트와 보스, 보물 방에서 유물을 얻습니다.", 20, UI.SUB))
	for id in r.relics:
		var rd := UpgradeData.relic(id)
		var curse: bool = rd.get("curse", false)
		_line(v, "horn" if curse else "star", UI.RED if curse else UI.BRASS, rd["name"], rd["desc"])
	screen.sheet("가방", v)


func show_menu() -> void:
	var v := UI.vbox(12)
	v.add_child(UI.button("설정", func(): Game.goto("settings", {"back": "map"}), 26, false, 72, "gear"))
	v.add_child(UI.button("저장하고 오두막으로", func():
		Game.save_run()
		Game.run = null
		Game.goto("hub"), 26, false, 72, "house"))
	v.add_child(UI.button("탐험 포기", func(): screen.confirm("정말 포기할까요?\n불씨는 절반만 받습니다.", "포기", func(): Game.end_run(false, true)), 26, false, 72, "close"))
	screen.sheet("메뉴", v)
