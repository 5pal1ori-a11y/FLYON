extends Screen
## 전투 화면: 이동 → 등불 놓기(미리보기) → 점화 → 적 턴.

var bt: Battle
var view: BoardView
var hud: RunHud
var obj_label: Label
var obj_icon: Icon
var turn_chip: PanelContainer
var hint_label: Label
var summary: HBoxContainer
var undo_btn: Button
var fire_btn: Button
var skip_btn: Button
var preview_cell := Vector2i(-99, -99)
var locked: Array = []
var busy := false
var puzzle := false
var puzzle_index := -1
var tutorial := false
var _last_release_preview := Vector2i(-99, -99)


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
	var v := UI.screen_frame(self, "", Callable(), bt.b.biome)
	v.add_theme_constant_override("separation", 12)
	if puzzle:
		var h := UI.hbox(12)
		h.add_child(UI.icon_button("back", func(): Game.goto("puzzles"), 58, 22))
		var pd: Dictionary = PuzzleData.load_all()[puzzle_index]
		var tl := UI.title("시험 %d" % (puzzle_index + 1), 32, UI.TEXT)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
		h.add_child(UI.chip("lantern", GearData.LANTERNS[pd["lantern"]]["name"], UI.AMBER, 20))
		h.add_child(UI.grow())
		h.add_child(UI.icon_button("undo", func(): Game.start_puzzle(puzzle_index), 58, 24))
		v.add_child(h)
	else:
		hud = RunHud.make(self)
		v.add_child(hud)
	# 목표 줄
	var op := PanelContainer.new()
	var osb := FancyBox.make(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.02), Color(bd["accent"], 0.28), 12, 14).with_shadow(Color(0, 0, 0, 0), 0, 0)
	osb.pad(14, 9)
	op.add_theme_stylebox_override("panel", osb)
	var oh := UI.hbox(10)
	op.add_child(oh)
	obj_icon = Icon.make("flag", 22, bd["accent"])
	oh.add_child(obj_icon)
	obj_label = UI.tag("", 21, UI.TEXT, true)
	obj_label.clip_text = true
	obj_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oh.add_child(obj_label)
	turn_chip = UI.chip("", "", UI.SUB, 18)
	oh.add_child(turn_chip)
	v.add_child(op)
	hint_label = UI.label("", 20, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.custom_minimum_size = Vector2(0, 52)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(hint_label)
	# 보드: 화면 높이에 맞춰 칸 크기를 정한다
	var vp := get_viewport_rect().size
	var avail_w: float = vp.x - 44
	var avail_h: float = vp.y - 462 - Game.safe_top - Game.safe_bottom
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
	summary = UI.hbox(8)
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.custom_minimum_size = Vector2(0, 44)
	v.add_child(summary)
	var row := UI.hbox(10)
	undo_btn = UI.button("되돌리기", _on_undo, 22, false, 84, "undo")
	skip_btn = UI.button("제자리", _on_skip_move, 22, false, 84, "stay")
	fire_btn = UI.button("점화", _on_fire, 32, true, 84, "flame")
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_btn.size_flags_stretch_ratio = 1.5
	row.add_child(undo_btn)
	row.add_child(skip_btn)
	row.add_child(fire_btn)
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
	if aim:
		undo_btn.text = "이동 취소"
		undo_btn.disabled = false
	else:
		undo_btn.text = "되돌리기" if puzzle else "되돌리기 %d" % bt.undo_left
		undo_btn.disabled = not bt.can_undo()
	if aim and bt.needs_cells() == 2 and locked.is_empty():
		fire_btn.text = "첫 등불"
	else:
		fire_btn.text = "점화"
	fire_btn.disabled = busy or not aim or preview_cell.x == -99
	_hint()
	_summary()


func _objective_text() -> void:
	var o: Dictionary = bt.b.objective
	var t: String = o.get("type", "annihilate")
	var od: Dictionary = MetaData.OBJECTIVES.get(t, {"name": ""})
	var s: String = od["name"]
	var icon := "flag"
	match t:
		"annihilate":
			icon = "sword"
			s += "  남은 적 %d" % bt.b.enemies().size()
		"survive":
			icon = "shield"
			s += "  %d턴 남음" % max(0, bt.turns_left())
		"candles":
			icon = "flame"
			s += "  %d/%d  %d턴 남음" % [int(o.get("lit", 0)), int(o.get("total", 0)), max(0, bt.turns_left())]
		"escape":
			icon = "next"
			s += "  %d턴 남음" % max(0, bt.turns_left())
		"protect":
			icon = "lantern"
			var bc := bt.b.beacon()
			s += "  등대 체력 %d" % (bc.hp if bc != null else 0)
		"boss":
			icon = "crown"
			var bu := bt.b.boss_unit()
			if bu != null:
				s = "%s  %d/%d" % [EnemyData.get_def(bu.kind)["name"], bu.hp, bu.max_hp]
		"puzzle":
			icon = "scroll"
			s = "한 번의 이동과 점화로 모두 물리쳐라"
	obj_label.text = s
	if obj_icon.kind != icon:
		obj_icon.kind = icon
		obj_icon.queue_redraw()
	turn_chip.visible = not puzzle
	UI.chip_set(turn_chip, "%d턴" % bt.b.turn)


func _hint() -> void:
	var h := ""
	if bt.phase == "move":
		h = "파란 칸을 누르면 이동합니다. 적을 누르면 정보를 봅니다."
		if bt.b.flags.get("fog", false) and not puzzle:
			h = "안개 속 4칸보다 먼 적은 정체가 보이지 않습니다."
	elif bt.phase == "aim":
		if preview_cell.x == -99:
			h = "작은 마름모를 눌러 등불 자리를 고르세요. 그림자가 미리 보입니다."
		elif tutorial:
			h = "보라색은 내 그림자, 빨간 테두리는 적 그림자입니다. 겹치면 적이 굳습니다."
		else:
			h = "같은 칸을 다시 누르면 바로 점화합니다."
	if not tutorial and not puzzle and bt.b.turn > 1 and not (bt.phase == "move" and bt.b.flags.get("fog", false) and bt.b.turn == 2):
		h = ""
	if bt.b.radius_penalty > 0 and h == "":
		h = "빛이 줄어 등불 반경이 %.1f 좁아졌습니다." % bt.b.radius_penalty
	hint_label.text = h


func _summary() -> void:
	for c in summary.get_children():
		c.queue_free()
	if view.preview.is_empty():
		return
	var pv: Dictionary = view.preview
	var cast: Dictionary = pv["cast"]
	if puzzle:
		summary.add_child(UI.chip("sword", "처치 %d / %d" % [int(pv.get("kills", 0)), bt.b.enemies().size()], UI.AMBER if pv.get("clear", false) else UI.TEXT, 20))
		return
	var dmg := 0
	for h in cast["hits"]:
		if h["team"] == Unit.TEAM_ENEMY:
			dmg += int(h["amt"])
	summary.add_child(UI.chip("sword", "처치 %d" % int(pv.get("kills", 0)), UI.AMBER if int(pv.get("kills", 0)) > 0 else UI.SUB, 20))
	summary.add_child(UI.chip("bolt", "피해 %d" % dmg, UI.TEXT if dmg > 0 else UI.SUB, 20))
	if not cast["frozen"].is_empty():
		summary.add_child(UI.chip("snow", "굳힘 %d" % cast["frozen"].size(), UI.BLUE, 20))
	if pv.get("win", false):
		summary.add_child(UI.chip("star", "승리", Color("ffd66a"), 20))
	elif pv.get("dead", false):
		summary.add_child(UI.chip("close", "쓰러진다", UI.RED, 20))
	else:
		var pd := int(pv.get("player_dmg", 0))
		if pd > 0:
			summary.add_child(UI.chip("heart", "받을 피해 %d" % pd, UI.RED, 20))
		else:
			summary.add_child(UI.chip("shield", "안전", UI.GREEN, 20))
		var bd := int(pv.get("beacon_dmg", 0))
		if bd > 0:
			summary.add_child(UI.chip("lantern", "등대 -%d" % bd, UI.RED, 20))


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
	_summary()
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
	var v := UI.vbox(12)
	if u != null and u.is_enemy():
		if view._fog_hidden(u, bt.player()):
			v.add_child(UI.label("안개에 가려 정체를 알 수 없습니다. 4칸 안으로 다가가면 보입니다.", 23))
			sheet("안개 속의 무언가", v)
			return
		var d: Dictionary = EnemyData.get_def(u.kind)
		var name: String = d["name"]
		if u.elite != "":
			name = EnemyData.ELITES[u.elite]["name"] + " " + name
		var chips := UI.hbox(8)
		chips.add_child(UI.chip("heart", "%d/%d" % [u.hp, u.max_hp], UI.RED, 20))
		chips.add_child(UI.chip("sword", "공격 %d" % u.atk, UI.TEXT, 20))
		chips.add_child(UI.chip("next", "이동 %d" % u.move, UI.TEXT, 20))
		v.add_child(chips)
		v.add_child(UI.label(d["desc"], 23))
		if u.elite != "":
			v.add_child(UI.label("엘리트: " + EnemyData.ELITES[u.elite]["desc"], 21, UI.RED, true))
		var sts := UI.hbox(8)
		if u.frozen():
			sts.add_child(UI.chip("snow", "굳음 %d턴" % int(u.st["frozen"]), UI.BLUE, 19))
		if u.burning():
			sts.add_child(UI.chip("flame", "화상 %d" % int(u.st["burn"]), Color("ff9a4a"), 19))
		if u.poisoned():
			sts.add_child(UI.chip("poison", "독 %d" % int(u.st["poison"]), UI.GREEN, 19))
		if int(u.st.get("shield", 0)) > 0:
			sts.add_child(UI.chip("shield", "껍질 %d" % int(u.st["shield"]), UI.TEXT, 19))
		if sts.get_child_count() > 0:
			v.add_child(sts)
		sheet(name, v)
		return
	if u != null and u.is_beacon():
		v.add_child(UI.label("지켜야 할 등대입니다. 체력 %d/%d. 등대도 그림자를 드리워 적을 벱니다." % [u.hp, u.max_hp], 23))
		sheet("등대", v)
		return
	if u != null and u.is_player():
		var p := bt.player()
		var chips2 := UI.hbox(8)
		chips2.add_child(UI.chip("heart", "%d/%d" % [p.hp, p.max_hp], UI.RED, 20))
		chips2.add_child(UI.chip("next", "이동 %d" % bt.move_range(), UI.TEXT, 20))
		chips2.add_child(UI.chip("lantern", "등불 거리 %d" % bt.throw_range(), UI.AMBER, 20))
		v.add_child(chips2)
		v.add_child(UI.label(GearData.LANTERNS[bt.lantern_id]["name"] + ": " + GearData.LANTERNS[bt.lantern_id]["desc"], 22))
		sheet("나", v)
		return
	var tt := bt.b.tile(c)
	if Board.TILE_DESC.has(tt):
		v.add_child(UI.label(Board.TILE_DESC[tt], 23))
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
	dim.color = Color(0.02, 0.02, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var vb := UI.vbox(18)
	cc.add_child(vb)
	var text := ""
	var col := Color("ffd9a0")
	match res:
		"win":
			text = "시험 통과" if puzzle else ("보스를 쓰러뜨렸다" if Game.room.get("kind", "") == "boss" else "방을 밝혔다")
			Sfx.play("win")
		"lose":
			text = "등불이 꺼졌다"
			col = UI.RED
			Sfx.play("lose")
		"fail":
			text = "한 번 더" if puzzle else "목표를 놓쳤다"
			col = UI.RED
			Sfx.play("lose")
	var tl := UI.title(text, 60, col, HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_color_override("font_shadow_color", Color(col, 0.35))
	tl.add_theme_constant_override("shadow_offset_x", 0)
	tl.add_theme_constant_override("shadow_offset_y", 0)
	tl.add_theme_constant_override("shadow_outline_size", 20)
	vb.add_child(tl)
	if res == "win" and not puzzle and bt.stats.get("damage_taken", 0) == 0:
		var pc := UI.chip("shield", "한 대도 맞지 않았다", UI.GREEN, 22)
		pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(pc)
	if res == "fail" and not puzzle:
		vb.add_child(UI.label("체력 2를 잃고 다음 방으로 갑니다.", 22, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
	create_tween().tween_property(dim, "color:a", 0.72, 0.3)
	if tutorial and res == "win":
		Save.set_setting("tutorial", true)
	if puzzle:
		if res == "win":
			Game.puzzle_solved(puzzle_index)
		var h := UI.hbox(12)
		h.custom_minimum_size = Vector2(600, 0)
		h.add_child(UI.expand(UI.button("목록", func(): Game.goto("puzzles"), 24, false, 76, "scroll")))
		h.add_child(UI.expand(UI.button("다시", func(): Game.start_puzzle(puzzle_index), 24, false, 76, "undo")))
		if res == "win" and puzzle_index + 1 < PuzzleData.load_all().size():
			h.add_child(UI.expand(UI.button("다음", func(): Game.start_puzzle(puzzle_index + 1), 24, true, 76, "next")))
		vb.add_child(h)
		return
	await get_tree().create_timer(1.2).timeout
	Game.finish_battle()
