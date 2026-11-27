extends Screen
## 도전: 일일 도전, 주간 도전, 끝없는 탑, 시험(퍼즐).


func build(_p: Dictionary) -> void:
	var v := UI.screen_frame(self, "도전 · 시험", func(): Game.goto("title"))
	var body := UI.vbox(18)
	v.add_child(UI.scroll(body))
	var busy := Game.has_saved_run()
	if busy:
		body.add_child(UI.label("진행 중인 탐험이 있어 도전을 시작할 수 없습니다. 먼저 끝내거나 포기하세요.", 22, UI.RED))
	# 일일
	var today := Game.today_key()
	var wd: int = Time.get_date_dict_from_system()["weekday"]
	var lid: String = GearData.LANTERN_ORDER[wd % GearData.LANTERN_ORDER.size()]
	var best := int(Save.meta["best"]["daily"].get(today, 0))
	body.add_child(_card("일일 도전 · " + today,
		"전 세계가 같은 탑을 오른다. 등불지기 · 오늘의 등불 「%s」 · 그을음 3단계 · 짧은 1층 + 보스.\n오늘 최고 점수: %d" % [GearData.LANTERNS[lid]["name"], best],
		"도전하기", func(): Game.new_run("daily", "keeper", lid, 3), busy))
	# 주간
	var wk := Game.week_index()
	var wr := RandomNumberGenerator.new()
	wr.seed = int(hash("weekly" + str(wk))) & 0x7fffffff
	var a := wr.randi_range(0, RunState.WEEKLY_MODS.size() - 1)
	var b := (a + 1 + wr.randi_range(0, RunState.WEEKLY_MODS.size() - 2)) % RunState.WEEKLY_MODS.size()
	var rules := "%s: %s\n%s: %s" % [RunState.WEEKLY_MODS[a]["name"], RunState.WEEKLY_MODS[a]["desc"], RunState.WEEKLY_MODS[b]["name"], RunState.WEEKLY_MODS[b]["desc"]]
	var last: Dictionary = Save.meta.get("last", {})
	var wbest := int(Save.meta["best"]["weekly"].get(str(wk), 0))
	body.add_child(_card("주간 도전", "이번 주 규칙\n" + rules + "\n2층짜리 탑 · 최고 점수 %d" % wbest,
		"도전하기", func(): Game.new_run("weekly", last.get("char", "keeper"), last.get("lantern", "candle"), 0), busy))
	# 끝없는 탑
	body.add_child(_card("끝없는 탑", "꼭대기 위에도 계단이 있다. 층이 오를수록 적이 강해진다.\n최고 기록: %d층" % int(Save.meta["best"]["endless"]),
		"오르기", func(): Game.new_run("endless", last.get("char", "keeper"), last.get("lantern", "candle"), 0), busy))
	# 시험
	var solved: int = Save.meta["puzzles"].size()
	body.add_child(_card("등불지기의 시험", "단 한 번의 이동과 점화로 모든 적을 물리쳐라. 100문제.\n푼 문제: %d / %d" % [solved, PuzzleData.load_all().size()],
		"시험 보기", func(): Game.goto("puzzles"), false))


func _card(title: String, desc: String, btn: String, cb: Callable, disabled: bool) -> Control:
	var p := UI.panel(22)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label(title, 32, UI.AMBER, true))
	v.add_child(UI.label(desc, 23))
	var b := UI.button(btn, cb, 28, true, 76)
	b.disabled = disabled
	v.add_child(b)
	return p
