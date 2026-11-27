extends Screen
## 시험(퍼즐) 목록: 100문제, 앞 문제를 풀면 다음 10문제가 열린다.


func build(_p: Dictionary) -> void:
	var v := UI.screen_frame(self, "등불지기의 시험", func(): Game.goto("challenge"))
	var list := PuzzleData.load_all()
	var solved: Dictionary = Save.meta["puzzles"]
	v.add_child(UI.label("푼 문제 %d / %d · 10문제를 풀 때마다 다음 10문제가 열립니다" % [solved.size(), list.size()], 22, UI.SUB))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var unlocked := 10 + (solved.size() / 10) * 10 + 10
	for i in list.size():
		var idx := i
		var done := solved.has(str(i))
		var b := UI.button(str(i + 1), func(): Game.start_puzzle(idx), 26, done, 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if done:
			b.add_theme_color_override("font_color", UI.GREEN)
		b.disabled = i >= unlocked
		grid.add_child(b)
	v.add_child(UI.scroll(grid))
