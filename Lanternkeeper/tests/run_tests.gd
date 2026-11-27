extends SceneTree
## 규칙 엔진 자동 테스트.  실행: godot --headless --path . -s tests/run_tests.gd

var passed := 0
var failed := 0
var current := ""


func _init() -> void:
	var tests := [
		"t_player_shadow_hits", "t_pillar_shadow", "t_freeze_by_overlap", "t_water_flood", "t_glass_shatter",
		"t_mirror_light", "t_front_guard", "t_brazier_blocks", "t_shield_cap", "t_mist_split", "t_chain",
		"t_rat_moves_and_bites", "t_archer_aim_then_shoot", "t_charger_stun", "t_statue_lit",
		"t_battle_flow_and_undo", "t_preview_matches_cast", "t_candles_objective", "t_escape_objective",
		"t_moon_directional", "t_inverse_black_flame", "t_twin_lanterns", "t_mods_sets",
		"t_room_gen_many", "t_map_gen", "t_run_serialize", "t_bot_runs", "t_puzzles_solvable",
	]
	for t in tests:
		current = t
		var before := failed
		var ok = call(t)
		if ok != true:
			failed += 1
			print("  ✗ ", t, " — 스크립트 오류로 중단됨")
		elif failed == before:
			passed += 1
			print("  ✓ ", t)
	print("\n결과: %d 통과, %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failed += 1
		push_error("✗ %s: %s" % [current, msg])
		print("  ✗ ", current, " — ", msg)


func ctx(lantern := "candle", mods := {}) -> Dictionary:
	return {"mods": mods, "lantern": GearData.LANTERNS[lantern]}


func empty_board() -> Board:
	var b := Board.new(7, 9)
	b.objective = {"type": "annihilate"}
	return b


# ── 그림자 ──
func t_player_shadow_hits() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("rat", Vector2i(3, 4))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(e.dead, "쥐(체력 2)가 촛불 그림자(피해 2)에 쓰러져야 함, hp=%d" % e.hp)
	var found := false
	for s in r["shadows"]:
		if s["caster"]["is_player"]:
			found = s["cells"].has(Vector2i(3, 5)) and s["cells"].has(Vector2i(3, 3))
	check(found, "내 그림자가 위로 3칸 뻗어야 함")
	return true


func t_pillar_shadow() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(0, 8), 7, 7, 2)
	b.set_tile(Vector2i(4, 5), Board.PILLAR)
	var e := b.spawn_enemy("shield", Vector2i(4, 3))
	Combat.resolve(b, [Vector2i(4, 7)], ctx())
	check(e.hp == 4, "방패병은 기둥 그림자에 맞아도 최대 1 피해, hp=%d" % e.hp)
	return true


func t_freeze_by_overlap() -> bool:
	# 등불-나-적이 한 줄이면 내 그림자가 적 그림자의 시작점을 덮는다 → 굳음
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("shield", Vector2i(3, 4))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(r["frozen"].has(e.id) and e.frozen(), "내 그림자가 적 그림자와 겹치면 굳어야 함")
	# 그림자 끝자락에 있는 적은 겹치지 않는다
	var b2 := empty_board()
	b2.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e2 := b2.spawn_enemy("shield", Vector2i(3, 3))
	var r2 := Combat.resolve(b2, [Vector2i(3, 7)], ctx())
	check(not r2["frozen"].has(e2.id), "그림자 끝의 적은 굳지 않음")
	return true


func t_water_flood() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	for x in range(0, 7):
		b.set_tile(Vector2i(x, 4), Board.WATER)
	var e := b.spawn_enemy("rat", Vector2i(0, 4))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(e.dead, "물길로 번진 그림자에 먼 쥐가 맞아야 함")
	var flooded := false
	for f in r["fx"]:
		if f["type"] == "flood":
			flooded = true
	check(flooded, "flood 효과 기록")
	return true


func t_glass_shatter() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	b.set_tile(Vector2i(3, 4), Board.GLASS)
	var e := b.spawn_enemy("rat", Vector2i(4, 3))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(b.tile(Vector2i(3, 4)) == Board.FLOOR, "유리가 깨져야 함")
	check(r["shattered"].size() == 1, "깨진 유리 기록")
	check(e.hp == 1, "파편 피해 1, hp=%d" % e.hp)
	return true


func t_mirror_light() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(0, 8), 7, 7, 2)
	b.set_tile(Vector2i(3, 5), Board.MIRROR)
	b.set_tile(Vector2i(5, 5), Board.PILLAR)
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	var mirror_lights := 0
	for l in r["lights"]:
		if l["mirror"]:
			mirror_lights += 1
	check(mirror_lights == 1, "거울이 두 번째 광원이 되어야 함")
	return true


func t_front_guard() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("knight", Vector2i(3, 4))
	e.facing = Vector2i(0, 1)
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(e.hp == 4 and r["deflects"].size() == 1, "정면 그림자는 튕겨 나가야 함")
	var b2 := empty_board()
	b2.spawn_player(Vector2i(3, 2), 7, 7, 2)
	var e2 := b2.spawn_enemy("knight", Vector2i(3, 4))
	e2.facing = Vector2i(0, 1)
	Combat.resolve(b2, [Vector2i(3, 1)], ctx())
	check(e2.hp == 2, "등 뒤 그림자는 들어가야 함, hp=%d" % e2.hp)
	return true


func t_brazier_blocks() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	b.set_tile(Vector2i(4, 4), Board.BRAZIER)
	var e := b.spawn_enemy("rat", Vector2i(3, 4))
	Combat.resolve(b, [Vector2i(3, 7)], ctx())
	check(e.hp == 2, "화로 주변에는 그림자가 들지 않아야 함")
	return true


func t_shield_cap() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("shield", Vector2i(3, 4))
	Combat.resolve(b, [Vector2i(3, 7)], ctx("candle", {"dmg": 5}))
	check(e.hp == 4, "방패병 피해 상한 1")
	return true


func t_mist_split() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	b.spawn_enemy("mist", Vector2i(3, 4))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx("candle", {"dmg": 2}))
	check(r["spawns"].size() == 2, "안개가 둘로 갈라져야 함")
	check(b.enemies().size() == 2, "작은 안개 2마리")
	return true


func t_chain() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	b.spawn_enemy("rat", Vector2i(3, 4))
	var e2 := b.spawn_enemy("moth", Vector2i(1, 3))
	var r := Combat.resolve(b, [Vector2i(3, 7)], ctx("candle", {"chain": 1}))
	check(r["chains"].size() >= 1 and e2.dead, "연쇄로 나방이 쓰러져야 함")
	return true


# ── 적 AI ──
func t_rat_moves_and_bites() -> bool:
	var b := empty_board()
	var p := b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("rat", Vector2i(3, 4))
	EnemyAI.run(b, ctx())
	check(e.pos == Vector2i(3, 5), "쥐가 한 칸 다가와야 함 %s" % e.pos)
	check(p.hp == 6, "다가온 뒤 물어야 함 hp=%d" % p.hp)
	return true


func t_archer_aim_then_shoot() -> bool:
	var b := empty_board()
	var p := b.spawn_player(Vector2i(3, 7), 7, 7, 2)
	var e := b.spawn_enemy("archer", Vector2i(3, 3))
	EnemyAI.run(b, ctx())
	check(e.ai.has("aim"), "조준해야 함")
	check(p.hp == 7, "첫 턴엔 쏘지 않음")
	EnemyAI.run(b, ctx())
	check(p.hp == 6, "둘째 턴에 맞아야 함 hp=%d" % p.hp)
	var e2 := b.spawn_enemy("archer", Vector2i(0, 7))
	EnemyAI.run(b, ctx())
	p.pos = Vector2i(2, 6)
	var hp_before := p.hp
	EnemyAI.run(b, ctx())
	check(p.hp == hp_before or e2.dead, "조준선에서 비키면 피할 수 있어야 함")
	return true


func t_charger_stun() -> bool:
	var b := empty_board()
	var p := b.spawn_player(Vector2i(3, 7), 7, 7, 2)
	var e := b.spawn_enemy("charger", Vector2i(3, 2))
	EnemyAI.run(b, ctx())
	check(e.ai.has("charge"), "돌진 조준")
	p.pos = Vector2i(5, 7)
	EnemyAI.run(b, ctx())
	check(e.pos == Vector2i(3, 8) and e.frozen(), "벽까지 돌진 후 기절 %s" % e.pos)
	return true


func t_statue_lit() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 7), 7, 7, 2)
	var e := b.spawn_enemy("statue", Vector2i(3, 4))
	b.last_lit = {Vector2i(3, 4): true}
	EnemyAI.run(b, ctx())
	check(e.pos == Vector2i(3, 4), "빛 안의 석상은 멈춤")
	b.last_lit = {}
	EnemyAI.run(b, ctx())
	check(e.pos == Vector2i(3, 5), "어둠에선 다가옴")
	return true


# ── 전투 흐름 ──
func t_battle_flow_and_undo() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 8), 7, 7, 2)
	b.spawn_enemy("rat", Vector2i(3, 2))
	b.spawn_enemy("rat", Vector2i(5, 2))
	var bt := Battle.new(b, {}, "candle", 3)
	var r := bt.reachable()
	check(r.has(Vector2i(3, 6)), "2칸 이동 가능")
	bt.move_to(Vector2i(3, 6))
	check(bt.phase == "aim", "이동 후 조준")
	check(bt.undo(), "이동 되돌리기")
	check(bt.player().pos == Vector2i(3, 8) and bt.phase == "move", "원위치")
	bt.skip_move()
	var out := bt.cast([Vector2i(3, 7)])
	check(out.has("enemy") and bt.phase == "move", "적 턴 후 다음 턴")
	check(bt.b.turn == 2, "턴 증가")
	var ul := bt.undo_left
	check(bt.undo(), "지난 턴으로 되돌리기")
	check(bt.undo_left == ul - 1 and bt.b.turn == 1, "되돌리기 소모")
	return true


func t_preview_matches_cast() -> bool:
	for seed in range(1, 30):
		var b := RoomGen.generate({"biome": BiomeData.ORDER[seed % 4], "kind": "battle", "floor": seed % 4, "row": 3, "seed": seed})
		var bt := Battle.new(b, {}, "candle", 3)
		bt.skip_move()
		var cells := bt.lantern_cells()
		if cells.is_empty():
			continue
		var c: Vector2i = cells[seed % cells.size()]
		var pv := bt.preview([c])
		var hp0 := bt.player().hp
		var out := bt.cast([c])
		if pv.has("player_dmg") and out["enemy"] != null:
			check(hp0 - max(0, bt.player().hp) == int(pv["player_dmg"]), "미리보기 피해와 실제 피해가 같아야 함 (seed %d)" % seed)
	return true


func t_candles_objective() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 8), 7, 7, 2)
	b.set_tile(Vector2i(3, 5), Board.CANDLE)
	b.objective = {"type": "candles", "total": 1, "lit": 0, "turns": 5}
	b.spawn_enemy("rat", Vector2i(0, 0))
	var bt := Battle.new(b, {}, "candle", 3)
	bt.skip_move()
	var out := bt.cast([Vector2i(3, 6)])
	check(out["result"] == "win", "초를 밝히면 승리")
	return true


func t_escape_objective() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 2), 7, 7, 2)
	b.set_tile(Vector2i(3, 0), Board.EXIT)
	b.objective = {"type": "escape", "exit": Vector2i(3, 0), "turns": 8}
	b.spawn_enemy("rat", Vector2i(6, 8))
	var bt := Battle.new(b, {}, "candle", 3)
	bt.move_to(Vector2i(3, 0))
	check(bt.result == "win", "출구 도착 승리")
	return true


func t_moon_directional() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	b.set_tile(Vector2i(0, 6), Board.PILLAR)
	var e := b.spawn_enemy("rat", Vector2i(0, 3))
	Combat.resolve(b, [Vector2i(3, 7)], ctx("moon"))
	check(e.hp == 1, "달빛: 먼 기둥도 같은 방향 그림자 hp=%d" % e.hp)
	return true


func t_inverse_black_flame() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("rat", Vector2i(4, 7))
	Combat.resolve(b, [Vector2i(3, 7)], ctx("black"))
	check(e.dead, "검은 불꽃: 빛 안의 적이 맞음")
	return true


func t_twin_lanterns() -> bool:
	var b := empty_board()
	b.spawn_player(Vector2i(3, 6), 7, 7, 2)
	var e := b.spawn_enemy("shield", Vector2i(3, 5))
	e.cap = 0
	var r := Combat.resolve(b, [Vector2i(2, 7), Vector2i(4, 7)], ctx("twin"))
	check(r["lights"].size() >= 2, "등불 두 개")
	return true


func t_mods_sets() -> bool:
	var m := Mods.build("keeper", ["f_ember", "f_blaze", "f_coal"], ["r_bigwick"], 1, {"hearth": 2})
	check(int(m.get("burning_explode", 0)) == 1, "불꽃 3세트")
	check(float(m.get("radius", 0)) == 1.0, "유물 반경")
	check(int(m.get("enemy_hp", 0)) == 1, "그을음 1")
	check(Mods.max_hp_for("keeper", m) == 9, "화덕 +2")
	return true


# ── 생성기 ──
func t_room_gen_many() -> bool:
	var kinds := ["battle", "elite", "boss"]
	for seed in range(1, 400):
		var biome: String = BiomeData.ORDER[seed % 4]
		var b := RoomGen.generate({"biome": biome, "kind": kinds[seed % 3], "floor": seed % 4, "row": seed % 7, "seed": seed * 31,
			"mods": {"extra_mirrors": seed % 2, "extra_glass": seed % 3}})
		check(b.player() != null, "플레이어 존재")
		check(not b.enemies().is_empty(), "적 존재 seed %d" % seed)
		if kinds[seed % 3] == "boss":
			check(b.boss_unit() != null, "보스 존재 seed %d" % seed)
		var reach := b.reachable_ground(b.player().pos)
		for c in b.all_cells():
			if Board.is_ground(b.tile(c)) and not reach.has(c):
				check(false, "고립된 칸 seed %d %s" % [seed, c])
				break
	return true


func t_map_gen() -> bool:
	for seed in range(1, 100):
		var m := MapGen.generate(seed, seed % 2 == 0)
		var incoming := {}
		for n in m["nodes"]:
			for l in n["links"]:
				incoming[l] = true
			if n["type"] != "boss":
				check(not n["links"].is_empty(), "모든 방에서 다음 방으로 갈 수 있어야 함")
		for n in m["nodes"]:
			if int(n["row"]) > 0:
				check(incoming.has(n["id"]), "모든 방에 들어갈 길이 있어야 함")
	return true


func t_run_serialize() -> bool:
	var r := RunState.new()
	r.seed = 42
	r.inscriptions = ["f_ember"]
	r.relics = ["r_boots"]
	r.new_floor_map()
	var d := JSON.parse_string(JSON.stringify(r.to_dict()))
	var r2 := RunState.from_dict(d)
	check(r2.inscriptions == ["f_ember"] and r2.map["nodes"].size() == r.map["nodes"].size(), "저장/불러오기")
	check(r2.move() == 3, "가벼운 장화 이동 +1")
	return true


# ── 봇 플레이: 크래시 없이 여러 방을 끝까지 진행하는지 ──
func t_bot_runs() -> bool:
	var wins := 0
	var total := 0
	for seed in range(1, 41):
		var biome: String = BiomeData.ORDER[seed % 4]
		var kind: String = ["battle", "battle", "elite", "boss"][seed % 4]
		var b := RoomGen.generate({"biome": biome, "kind": kind, "floor": seed % 4, "row": 4, "seed": seed * 7,
			"player_hp": 12, "player_max": 12})
		var lid: String = GearData.LANTERN_ORDER[seed % 6]
		var bt := Battle.new(b, {}, lid, 3)
		var turns := 0
		while bt.result == "" and turns < 40:
			turns += 1
			Bot.play_turn(bt)
		total += 1
		if bt.result == "win":
			wins += 1
		check(bt.result != "" or turns >= 40, "진행 seed %d" % seed)
	print("    봇 승률 %d/%d" % [wins, total])
	check(wins >= total / 3, "봇이 최소 1/3은 이겨야 밸런스가 정상 (%d/%d)" % [wins, total])
	return true


func t_puzzles_solvable() -> bool:
	var list := PuzzleData.load_all()
	if list.is_empty():
		print("    (퍼즐 파일 없음, 건너뜀)")
		return true
	check(list.size() >= 100, "퍼즐 100개")
	for i in list.size():
		var pz: Dictionary = list[i]
		var sol: Dictionary = pz["solution"]
		var bt := PuzzleData.make_battle(pz)
		var mv: Vector2i = Vector2i(int(sol["move"][0]), int(sol["move"][1]))
		if mv != bt.player().pos:
			bt.move_to(mv)
		else:
			bt.skip_move()
		var cells := []
		for c in sol["cells"]:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		bt.cast(cells)
		check(bt.result == "win", "퍼즐 %d 정답이 통해야 함" % (i + 1))
	return true
