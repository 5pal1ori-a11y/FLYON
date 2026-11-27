extends Screen
## 전투 화면: 이동 → 등불 놓기(미리보기) → 점화 → 적 턴.

var bt: Battle
var view: BoardView
var hud: RunHud
var obj_label: Label
var hint_label: Label
var summary: RichTextLabel
var undo_btn: Button
var fire_btn: Button
var skip_btn: Button
var preview_cell := Vector2i(-99, -99)
var locked: Array = []
var busy := false
var puzzle := false
var puzzle_index := -1
var tutorial := false
var hp_label_override := -1


func build(p: Dictionary) -> void:
	bt = Game.battle
	if bt == null:
		Game.goto("title")
		return
	puzzle = p.get("puzzle", false)
	puzzle_index = int(Game.room.get("puzzle", -1))
	tutorial = not puzzle and not Save.setting("tutorial", false)
	var bd := BiomeData.get_def(bt.b.biome)
	if Game.room.get("kind", "") == "boss":
		Sfx.music("boss")
	else:
		Sfx.music(bd["music"])
	var v := UI.screen_frame(self, "")
	if puzzle:
		var h := UI.hbox()
		var back := UI.button("‹", func(): Game.goto("puzzles"), 36, false, 64)
		back.custom_minimum_size = Vector2(80, 64)
		h.add_child(back)
		var pd: Dictionary = PuzzleData.load_all()[puzzle_index]
		h.add_child(UI.expand(UI.label("시험 %d · %s" % [puzzle_index + 1, GearData.LANTERNS[pd["lantern"]]["name"]], 32, UI.AMBER, true)))
		h.add_child(UI.button("다시", func(): Game.start_puzzle(puzzle_index), 24, false, 64))
		v.add_child(h)
	else:
		hud = RunHud.make(self)
		v.add_child(hud)
	obj_label = UI.label("", 24, bd["accent"])
	v.add_child(obj_label)
	hint_label = UI.label("", 21, Color(0.85, 0.82, 0.75))
	hint_label.custom_minimum_size = Vector2(0, 58)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(hint_label)
	# 보드: 화면 높이에 맞춰 칸 크기를 정한다
	var vp := get_viewport_rect().size
	var avail_w: float = vp.x - 32
	var avail_h: float = vp.y - 450 - Game.safe_top - Game.safe_bottom
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cc)
	view = BoardView.new()
	view.cell = floor(min(96.0, avail_w / bt.b.w, avail_h / bt.b.h))
	view.puzzle = puzzle
	view.lantern_color = GearData.LANTERNS[bt.lantern_id]["color"]
	cc.add_child(view)
	view.setup(bt.b)
	view.cell_pressed.connect(_on_press)
	view.cell_dragged.connect(_on_drag)
	view.cell_released.connect(_on_release)
	view.player_hp.connect(func(hp): if hud: hud.refresh(hp, bt.player().max_hp))
	summary = UI.rich("", 23)
	summary.custom_minimum_size = Vector2(0, 40)
	v.add_child(summary)
	var row := UI.hbox(12)
	undo_btn = UI.button("되돌리기", _on_undo, 24, false, 80)
	skip_btn = UI.button("제자리", _on_skip_move, 24, false, 80)
	fire_btn = UI.button("점화", _on_fire, 32, true, 80)
	row.add_child(UI.expand(undo_btn))
	row.add_child(UI.expand(skip_btn))
	row.add_child(UI.expand(fire_btn))
	if Save.setting("left", false):
		row.move_child(fire_btn, 0)
	v.add_child(row)
	_refresh()


# ───────────────────── 상태 갱신 ─────────────────────
func _refresh() -> void:
	view.b = bt.b
	var p := bt.player()
	if hud != null:
		hud.refresh(p.hp, p.max_hp)
	_objective_text()
	if bt.phase == "move":
		view.move_cells = bt.reachable()
		view.lantern_cells = []
		view.preview = {}
		view.preview_cells = []
		view.locked_cells = []
	else:
		view.move_cells = {}
		view.lantern_cells = bt.lantern_cells(locked)
		view.locked_cells = locked
	var aim := bt.phase == "aim"
	skip_btn.visible = bt.phase == "move"
	if bt.phase == "aim":
		undo_btn.text = "이동 취소"
		undo_btn.disabled = false
	else:
		undo_btn.text = "되돌리기 %d" % bt.undo_left
		undo_btn.disabled = not bt.can_undo()
	if puzzle:
		undo_btn.text = "이동 취소" if aim else "되돌리기"
		undo_btn.disabled = not aim
	var need := bt.needs_cells()
	if aim and need == 2 and locked.is_empty():
		fire_btn.text = "첫 등불 고정"
	else:
		fire_btn.text = "점화"
	fire_btn.disabled = busy or not aim or preview_cell.x == -99
	_hint()
	_summary()


func _objective_text() -> void:
	var o: Dictionary = bt.b.objective
	var t: String = o.get("type", "annihilate")
	var od: Dictionary = MetaData.OBJECTIVES.get(t, {"name": ""})
	var s: String = "목표 · " + od["name"]
	match t:
		"survive":
			s += " · 남은 턴 %d" % max(0, bt.turns_left())
		"candles":
			s += " · %d/%d · 남은 턴 %d" % [int(o.get("lit", 0)), int(o.get("total", 0)), max(0, bt.turns_left())]
		"escape":
			s += " · 남은 턴 %d" % max(0, bt.turns_left())
		"protect":
			var bc := bt.b.beacon()
			s += " · 등대 ♥%d" % (bc.hp if bc != null else 0)
		"boss":
			var bu := bt.b.boss_unit()
			if bu != null:
				s = "보스 · %s ♥%d/%d" % [EnemyData.get_def(bu.kind)["name"], bu.hp, bu.max_hp]
		"puzzle":
			s = "단 한 번의 이동과 점화로 모든 적을 물리쳐라"
	s += "   턴 %d" % bt.b.turn
	obj_label.text = s


func _hint() -> void:
	var h := ""
	if bt.phase == "move":
		h = "파란 칸: 이동 · 나 또는 [제자리]: 이동하지 않기 · 적을 누르면 정보"
		if bt.b.flags.get("fog", false) and not puzzle:
			h += "\n안개: 4칸보다 먼 적은 보이지 않습니다"
	elif bt.phase == "aim":
		if preview_cell.x == -99:
			h = "작은 점을 눌러 등불 자리를 고르면 그림자가 미리 보입니다"
		else:
			h = "같은 칸을 다시 누르거나 [점화]"
			if tutorial:
				h += "\n보라 = 내 그림자(적을 벤다) · 빨간 테두리 = 적 그림자 · 겹치면 굳음"
	if not tutorial and not puzzle and bt.b.turn > 1:
		h = ""
	hint_label.text = h
	hint_label.visible = h != ""


func _summary() -> void:
	if view.preview.is_empty():
		var p := bt.player()
		var parts := []
		if bt.b.radius_penalty > 0:
			parts.append("[color=#ff9a7a]빛 감소 -%.1f[/color]" % bt.b.radius_penalty)
		parts.append("되돌리기 %d" % bt.undo_left if not puzzle else "")
		summary.text = "  ".join(parts.filter(func(x): return x != ""))
		return
	var pv: Dictionary = view.preview
	var cast: Dictionary = pv["cast"]
	if puzzle:
		summary.text = "[color=#c8b8ff]그림자 미리보기[/color] · 정답이라면 모든 적이 쓰러집니다"
		return
	var kills := int(pv.get("kills", 0))
	var dmg := 0
	for h in cast["hits"]:
		if h["team"] == Unit.TEAM_ENEMY:
			dmg += int(h["amt"])
	var s := "처치 [b]%d[/b] · 피해 %d · 굳힘 %d" % [kills, dmg, cast["frozen"].size()]
	if pv.get("win", false):
		s += "  [color=#ffd36a]→ 승리![/color]"
	else:
		var pd := int(pv.get("player_dmg", 0))
		if pv.get("dead", false):
			s += "  [color=#ff5a50]→ 쓰러집니다![/color]"
		elif pd > 0:
			s += "  [color=#ff8a80]받을 피해 %d[/color]" % pd
		else:
			s += "  [color=#8af08a]안전[/color]"
		var bd := int(pv.get("beacon_dmg", 0))
		if bd > 0:
			s += " [color=#ffb070]등대 -%d[/color]" % bd
	summary.text = s


# ───────────────────── 입력 ─────────────────────
func _on_press(c: Vector2i) -> void:
	if busy or bt.result != "":
		return
	if bt.phase == "aim" and view.lantern_cells.has(c):
		_set_preview(c)


func _on_drag(c: Vector2i) -> void:
	if busy or bt.phase != "aim":
		return
	if view.lantern_cells.has(c):
		_set_preview(c, true)


var _last_release_preview := Vector2i(-99, -99)


func _on_release(c: Vector2i) -> void:
	if busy or bt.result != "":
		return
	var p := bt.player()
	if bt.phase == "move":
		if c == p.pos:
			_on_skip_move()
			return
		if view.move_cells.has(c):
			_do_move(c)
			return
		if bt.lantern_cells().has(c) and bt.b.unit_at(c) == null:
			bt.skip_move()
			_refresh()
			_set_preview(c)
			_last_release_preview = c
			return
		_inspect(c)
		return
	if bt.phase == "aim":
		if view.lantern_cells.has(c):
			if _last_release_preview == c and preview_cell == c:
				_on_fire()
				return
			_last_release_preview = c
			return
		_inspect(c)


func _set_preview(c: Vector2i, from_drag: bool = false) -> void:
	if preview_cell == c and not view.preview.is_empty():
		return
	preview_cell = c
	if not from_drag:
		Sfx.play("ui_tap", 1.3, 0.6)
	var cells := locked.duplicate()
	cells.append(c)
	if cells.size() < bt.needs_cells():
		# 쌍둥이 램프 첫 칸: 미리보기는 한 칸만
		view.preview = bt.preview(cells)
	else:
		view.preview = bt.preview(cells)
	view.preview_cells = [c]
	_refresh()


func _do_move(c: Vector2i) -> void:
	busy = true
	var info: Dictionary = view.move_cells[c]
	var from := bt.player().pos
	view.move_cells = {}
	var ev := bt.move_to(c)
	if ev.is_empty():
		busy = false
		_refresh()
		return
	match info["type"]:
		"walk", "step":
			if info["type"] == "step":
				view.burst(view.center(from), Color(0.6, 0.4, 1.0), 12, 120)
			await view.anim_player_move(info["path"])
		"push":
			Sfx.play("step", 0.7)
			view.tiles_layer.queue_redraw()
			await view.anim_player_move([c])
		"douse":
			Sfx.play("water")
			view.burst(view.center(c), Color(0.6, 0.6, 0.65), 14, 100)
	view.sync_units()
	busy = false
	preview_cell = Vector2i(-99, -99)
	_last_release_preview = Vector2i(-99, -99)
	if bt.result != "":
		_finish()
		return
	_refresh()


func _on_skip_move() -> void:
	if busy or bt.phase != "move":
		return
	bt.skip_move()
	_refresh()


func _on_undo() -> void:
	if busy:
		return
	if bt.undo():
		Sfx.play("page")
		locked = []
		preview_cell = Vector2i(-99, -99)
		_last_release_preview = Vector2i(-99, -99)
		view.preview = {}
		view.b = bt.b
		view.sync_units()
		_refresh()


func _on_fire() -> void:
	if busy or bt.phase != "aim" or preview_cell.x == -99:
		return
	var cells := locked.duplicate()
	cells.append(preview_cell)
	if cells.size() < bt.needs_cells():
		locked = cells
		preview_cell = Vector2i(-99, -99)
		_last_release_preview = Vector2i(-99, -99)
		view.preview = {}
		Sfx.play("place")
		_refresh()
		return
	busy = true
	fire_btn.disabled = true
	undo_btn.disabled = true
	view.preview = {}
	view.move_cells = {}
	view.lantern_cells = []
	view.locked_cells = []
	locked = []
	preview_cell = Vector2i(-99, -99)
	_last_release_preview = Vector2i(-99, -99)
	Sfx.play("place")
	var out := bt.cast(cells)
	await view.play_cast(out["cast"])
	if hud != null:
		hud.refresh(max(0, bt.player().hp), bt.player().max_hp)
	if out.get("enemy") != null:
		await view.play_enemy(out["enemy"])
	if out.get("echo") != null:
		await view.play_cast(out["echo"])
	view.b = bt.b
	view.sync_units()
	busy = false
	if tutorial and bt.b.turn >= 3:
		tutorial = false
	if bt.result != "":
		_finish()
		return
	_refresh()


func _inspect(c: Vector2i) -> void:
	var u := bt.b.unit_at(c)
	var v := UI.vbox(10)
	if u != null and u.is_enemy():
		if view._fog_hidden(u, bt.player()):
			v.add_child(UI.label("안개에 가려 정체를 알 수 없다. 4칸 안으로 다가가면 보인다.", 24))
			sheet("???", v)
			return
		var d: Dictionary = EnemyData.get_def(u.kind)
		var title: String = d["name"]
		if u.elite != "":
			title = EnemyData.ELITES[u.elite]["name"] + " " + title
		v.add_child(UI.label("체력 %d/%d · 공격 %d · 이동 %d" % [u.hp, u.max_hp, u.atk, u.move], 24, UI.AMBER))
		v.add_child(UI.label(d["desc"], 24))
		if u.elite != "":
			v.add_child(UI.label("엘리트: " + EnemyData.ELITES[u.elite]["desc"], 22, UI.RED))
		var sts := []
		if u.frozen():
			sts.append("굳음 %d턴" % int(u.st["frozen"]))
		if u.burning():
			sts.append("화상 %d" % int(u.st["burn"]))
		if u.poisoned():
			sts.append("독 %d" % int(u.st["poison"]))
		if int(u.st.get("shield", 0)) > 0:
			sts.append("껍질 %d" % int(u.st["shield"]))
		if not sts.is_empty():
			v.add_child(UI.label("상태: " + ", ".join(sts), 22, UI.BLUE))
		sheet(title, v)
		return
	if u != null and u.is_beacon():
		v.add_child(UI.label("지켜야 할 등대. 체력 %d/%d. 등대도 그림자를 드리워 적을 벤다." % [u.hp, u.max_hp], 24))
		sheet("등대", v)
		return
	if u != null and u.is_player():
		var p := bt.player()
		v.add_child(UI.label("체력 %d/%d · 이동 %d · 등불 거리 %d" % [p.hp, p.max_hp, bt.move_range(), bt.throw_range()], 24))
		v.add_child(UI.label(GearData.LANTERNS[bt.lantern_id]["name"] + ": " + GearData.LANTERNS[bt.lantern_id]["desc"], 22, UI.AMBER))
		sheet("나", v)
		return
	var tt := bt.b.tile(c)
	if Board.TILE_DESC.has(tt):
		v.add_child(UI.label(Board.TILE_DESC[tt], 24))
		sheet(Board.TILE_NAMES[tt], v)


# ───────────────────── 종료 ─────────────────────
func _finish() -> void:
	busy = true
	fire_btn.disabled = true
	undo_btn.disabled = true
	skip_btn.disabled = true
	await get_tree().create_timer(0.35).timeout
	var res := bt.result
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var vb := UI.vbox(18)
	cc.add_child(vb)
	var title := ""
	var col := UI.AMBER
	match res:
		"win":
			title = "시험 통과!" if puzzle else ("보스 격파!" if Game.room.get("kind", "") == "boss" else "방 정복")
			Sfx.play("win")
		"lose":
			title = "등불이 꺼졌다…"
			col = UI.RED
			Sfx.play("lose")
		"fail":
			title = "다시 도전" if puzzle else "목표 실패"
			col = UI.RED
			Sfx.play("lose")
	var tl := UI.label(title, 58, col, true, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(tl)
	if res == "win" and not puzzle and bt.stats.get("damage_taken", 0) == 0:
		vb.add_child(UI.label("피해 없이 정복", 26, UI.GREEN, false, HORIZONTAL_ALIGNMENT_CENTER))
	create_tween().tween_property(dim, "color:a", 0.65, 0.3)
	if tutorial and res == "win":
		Save.set_setting("tutorial", true)
	if puzzle:
		if res == "win":
			Game.puzzle_solved(puzzle_index)
		var h := UI.hbox(14)
		h.add_child(UI.button("목록", func(): Game.goto("puzzles"), 28))
		h.add_child(UI.button("다시", func(): Game.start_puzzle(puzzle_index), 28))
		if res == "win" and puzzle_index + 1 < PuzzleData.load_all().size():
			h.add_child(UI.button("다음 ▶", func(): Game.start_puzzle(puzzle_index + 1), 28, true))
		vb.add_child(h)
		return
	await get_tree().create_timer(1.2).timeout
	Game.finish_battle()
