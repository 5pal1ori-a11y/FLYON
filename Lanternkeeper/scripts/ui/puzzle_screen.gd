extends Screen
## 시험(퍼즐) 목록: 통과한 문제는 불 켜진 한지, 열 문제를 풀 때마다 다음 열 문제가 열린다.


func build(_p: Dictionary) -> void:
	var v := UI.screen_frame(self, "등불지기의 시험", func(): Game.goto("challenge"))
	var list := PuzzleData.load_all()
	var solved: Dictionary = Save.meta["puzzles"]
	(v.get_meta("header") as HBoxContainer).add_child(UI.chip("check", "%d/%d" % [solved.size(), list.size()], UI.AMBER, 21))
	v.add_child(UI.label("한 번의 이동과 점화로 모든 적을 물리치세요. 열 문제를 통과할 때마다 다음 열 문제가 열립니다.", 20, UI.SUB))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var unlocked := 20 + (solved.size() / 10) * 10
	for i in list.size():
		var idx := i
		var done := solved.has(str(i))
		var is_locked := i >= unlocked
		var b := UI.button("" if is_locked else str(i + 1), func(): Game.start_puzzle(idx), 26, false, 104, "lock" if is_locked else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if done:
			UI.style_button(b, "tab_on")
		b.disabled = is_locked
		grid.add_child(b)
	v.add_child(UI.scroll(grid))
