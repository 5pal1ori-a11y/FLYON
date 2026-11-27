extends SceneTree
## 퍼즐 100개 생성기. 해답이 1~몇 개뿐인 문제만 채택해 난이도 순으로 저장한다.
## 실행: godot --headless --path . -s tools/gen_puzzles.gd

const OUT := "res://scripts/data/puzzles.json"
const COUNT := 100


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261127
	var list := []
	var attempts := 0
	while list.size() < COUNT and attempts < 60000:
		attempts += 1
		var i := list.size()
		var pz := _try(rng, i)
		if not pz.is_empty():
			list.append(pz)
			if list.size() % 10 == 0:
				print("퍼즐 %d개 (시도 %d)" % [list.size(), attempts])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(list, "", false))
	f.close()
	print("저장 완료: %d개" % list.size())
	quit()


func _lantern_for(rng: RandomNumberGenerator, i: int) -> String:
	if i < 20:
		return "candle"
	var pool := ["candle", "torch"]
	if i >= 40:
		pool += ["moon", "twin"]
	if i >= 60:
		pool += ["swing"]
	if i >= 75:
		pool += ["black"]
	return pool[rng.randi_range(0, pool.size() - 1)]


func _try(rng: RandomNumberGenerator, i: int) -> Dictionary:
	# 역방향 생성: 정답(이동+점화)을 먼저 정하고, 그 그림자 위에 적을 심는다.
	var w := 7
	var h := 8
	var b := Board.new(w, h)
	b.biome = BiomeData.ORDER[(i / 25) % 4]
	b.objective = {"type": "puzzle"}
	var lantern := _lantern_for(rng, i)
	var move := 1 if lantern == "twin" else 2
	var reserved := {}
	var pp := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(h / 2, h - 1))
	reserved[pp] = true
	_put(b, rng, Board.PILLAR, rng.randi_range(1, 2 + i / 30), reserved)
	if i >= 8 and rng.randf() < 0.5:
		_put(b, rng, Board.CRATE, 1, reserved)
	if i >= 10 and rng.randf() < 0.45:
		_put(b, rng, Board.GLASS, rng.randi_range(1, 2), reserved)
	if i >= 15 and rng.randf() < 0.5:
		_put(b, rng, Board.MIRROR, rng.randi_range(1, 2), reserved)
	if i >= 25 and rng.randf() < 0.45:
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 3))
		for k in rng.randi_range(3, 6):
			if not reserved.has(c) and b.tile(c) == Board.FLOOR:
				b.set_tile(c, Board.WATER)
			c += Board.DIRS4[rng.randi_range(0, 3)]
			c = Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 2))
	if i >= 35 and rng.randf() < 0.3:
		_put(b, rng, Board.BRAZIER, 1, reserved)
	b.spawn_player(pp, 5, 5, move)
	var bt0 := Battle.new(b.clone(), {}, lantern, 0, true)
	# 정답 이동 칸
	var reach := bt0.reachable()
	var moves := [pp]
	for c in reach.keys():
		if reach[c]["type"] == "walk":
			moves.append(c)
	var mv: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
	var sb := b.clone()
	sb.player().pos = mv
	var cells := Bot._lantern_cells(sb, bt0)
	if cells.is_empty():
		return {}
	var sol := [cells[rng.randi_range(0, cells.size() - 1)]]
	if lantern == "twin":
		var other: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if other == sol[0]:
			return {}
		sol.append(other)
	# 정답 점화가 닿는 칸(아군 그림자 또는 검은 불꽃의 빛)
	var probe := sb.clone()
	var res := Combat.resolve(probe, sol, bt0.ctx)
	var hit_cells := []
	if lantern == "black":
		for li in res["lights"]:
			for c2 in sb.all_cells():
				if Combat.light_covers(li, c2) and Board.is_ground(sb.tile(c2)) and not hit_cells.has(c2):
					hit_cells.append(c2)
	else:
		for s in res["shadows"]:
			if s["caster"]["team"] == Unit.TEAM_PLAYER:
				for c3 in s["cells"]:
					if Board.is_ground(sb.tile(c3)) and not hit_cells.has(c3):
						hit_cells.append(c3)
	hit_cells.erase(mv)
	hit_cells.erase(pp)
	for c4 in sol:
		hit_cells.erase(c4)
	if hit_cells.size() < 2:
		return {}
	RoomGen._shuffle(rng, hit_cells)
	var kinds := ["rat", "rat", "moth", "bomber"]
	if i >= 30:
		kinds += ["knight", "spider"]
	if i >= 45:
		kinds += ["shield", "ghost", "archer"]
	if i >= 55:
		kinds += ["goblin", "charger"]
	var want := mini(6, 2 + i / 20)
	var placed := 0
	for c5 in hit_cells:
		if placed >= want:
			break
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var trial := sb.clone()
		var u := trial.spawn_enemy(kind, c5)
		if u.front_guard:
			u.facing = Board.DIRS4[rng.randi_range(0, 3)]
		var t2 := trial.clone()
		Combat.resolve(t2, sol, bt0.ctx)
		if t2.enemies().is_empty():
			sb = trial
			placed += 1
	if placed < max(2, want - 1):
		return {}
	# 원래 위치로 되돌린 보드에서 해답 수를 센다
	var fb := sb.clone()
	fb.player().pos = pp
	var bt := Battle.new(fb.clone(), {}, lantern, 0, true)
	var limit := 8 if i < 30 else 4
	var sols := Bot.solve_one_shot(bt, limit + 1)
	if sols.is_empty() or sols.size() > limit:
		return {}
	return PuzzleData.to_def(fb, lantern, move, sols[0], i)


func _put(b: Board, rng: RandomNumberGenerator, t: int, n: int, reserved: Dictionary) -> void:
	var guard := 0
	var placed := 0
	while placed < n and guard < 100:
		guard += 1
		var c := Vector2i(rng.randi_range(0, b.w - 1), rng.randi_range(0, b.h - 1))
		if reserved.has(c) or b.tile(c) != Board.FLOOR:
			continue
		b.set_tile(c, t)
		placed += 1
