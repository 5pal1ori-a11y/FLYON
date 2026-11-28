extends Screen
## 도전: 일일 도전, 주간 도전, 끝없는 탑, 시험.


func build(_p: Dictionary) -> void:
	var v := UI.screen_frame(self, "도전", func(): Game.goto("title"))
	var body := UI.vbox(14)
	v.add_child(UI.scroll(body))
	var busy := Game.has_saved_run()
	if busy:
		var warn := UI.hbox(10)
		warn.add_child(Icon.make("tower", 22, UI.RED))
		warn.add_child(UI.expand(UI.label("오르던 탑이 있습니다. 오두막에서 끝내거나 포기한 뒤 도전할 수 있습니다.", 20, UI.RED)))
		body.add_child(warn)
	var today := Game.today_key()
	var wd: int = Time.get_date_dict_from_system()["weekday"]
	var lid: String = GearData.LANTERN_ORDER[wd % GearData.LANTERN_ORDER.size()]
	var best := int(Save.meta["best"]["daily"].get(today, 0))
	body.add_child(_card("calendar", UI.AMBER, "일일 도전", today,
		"오늘은 모두가 같은 탑을 오릅니다. 등불은 %s, 그을음 3단계, 짧은 한 층과 보스." % GearData.LANTERNS[lid]["name"],
		"오늘 최고 %d점" % best if best > 0 else "", "도전한다", func(): Game.new_run("daily", "keeper", lid, 3), busy))
	var wk := Game.week_index()
	var wr := RandomNumberGenerator.new()
	wr.seed = int(hash("weekly" + str(wk))) & 0x7fffffff
	var a := wr.randi_range(0, RunState.WEEKLY_MODS.size() - 1)
	var b := (a + 1 + wr.randi_range(0, RunState.WEEKLY_MODS.size() - 2)) % RunState.WEEKLY_MODS.size()
	var last: Dictionary = Save.meta.get("last", {})
	var wbest := int(Save.meta["best"]["weekly"].get(str(wk), 0))
	var rules := "%s: %s\n%s: %s" % [RunState.WEEKLY_MODS[a]["name"], RunState.WEEKLY_MODS[a]["desc"], RunState.WEEKLY_MODS[b]["name"], RunState.WEEKLY_MODS[b]["desc"]]
	body.add_child(_card("star", UI.VIOLET, "주간 도전", "이번 주 규칙 두 가지", rules,
		"이번 주 최고 %d점" % wbest if wbest > 0 else "", "도전한다", func(): Game.new_run("weekly", last.get("char", "keeper"), last.get("lantern", "candle"), 0), busy))
	var eb := int(Save.meta["best"]["endless"])
	body.add_child(_card("infinity", UI.BLUE, "끝없는 탑", "", "꼭대기 위에도 계단이 있습니다. 오를수록 적이 강해집니다.",
		"최고 %d층" % eb if eb > 0 else "", "오른다", func(): Game.new_run("endless", last.get("char", "keeper"), last.get("lantern", "candle"), 0), busy))
	var solved: int = Save.meta["puzzles"].size()
	body.add_child(_card("scroll", UI.GREEN, "등불지기의 시험", "", "한 번의 이동과 점화로 모든 적을 물리치는 퍼즐 100문제.",
		"%d / %d 통과" % [solved, PuzzleData.load_all().size()], "시험 본다", func(): Game.goto("puzzles"), false))


func _card(icon: String, col: Color, head: String, sub: String, desc: String, record: String, btn: String, cb: Callable, disabled: bool) -> Control:
	var p := UI.panel(20)
	var v := UI.vbox(12)
	p.add_child(v)
	var h := UI.hbox(14)
	h.add_child(Icon.make_badge(icon, 60, Color(col, 0.18), col))
	var t := UI.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.title_wrap(head, 30, UI.TEXT))
	if sub != "":
		t.add_child(UI.tag(sub, 19, col, true))
	h.add_child(t)
	v.add_child(h)
	v.add_child(UI.label(desc, 21, UI.SUB))
	var foot := UI.hbox(12)
	var rl := UI.tag(record, 20, UI.AMBER, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(rl)
	var b := UI.button(btn, cb, 24, true, 60)
	b.custom_minimum_size.x = 190
	b.disabled = disabled
	foot.add_child(b)
	v.add_child(foot)
	return p
