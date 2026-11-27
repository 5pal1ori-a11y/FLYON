class_name RoomGen
## 방 생성: 구역 규칙에 맞는 장치 배치 + 목표 + 적 구성. 같은 시드면 같은 방이 나온다.

const W := 7
const H := 9

const OBJ_WEIGHTS := {"annihilate": 50, "survive": 12, "protect": 12, "candles": 13, "escape": 13}


## p: {biome, kind, floor, row, seed, mods, player_hp, player_max, player_move, level, objective}
static func generate(p: Dictionary) -> Board:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var biome: String = p.get("biome", "fog")
	var kind: String = p.get("kind", "battle")
	var floor_i: int = int(p.get("floor", 0))
	var row: int = int(p.get("row", 0))
	var mods: Dictionary = p.get("mods", {})
	var level: int = int(p.get("level", 0))
	var bd: Dictionary = BiomeData.get_def(biome)

	var obj_type := "annihilate"
	if kind == "boss":
		obj_type = "boss"
	elif kind == "battle" and not (floor_i == 0 and row == 0):
		obj_type = p.get("objective", "")
		if obj_type == "":
			obj_type = _weighted(rng, OBJ_WEIGHTS)

	for attempt in 30:
		var b := Board.new(W, H)
		b.biome = biome
		b.spawn_rng_state = int(rng.randi() % 100000) + 7
		var pstart := Vector2i(3, H - 1)
		var reserved := {pstart: true}
		for d in Board.DIRS8:
			reserved[pstart + d] = true
		var obj := {"type": obj_type}
		var exit_c := Vector2i(-1, -1)
		var beacon_c := Vector2i(-1, -1)
		if obj_type == "escape":
			exit_c = Vector2i(rng.randi_range(0, W - 1), 0)
			reserved[exit_c] = true
			for d in Board.DIRS4:
				reserved[exit_c + d] = true
		elif obj_type == "protect":
			beacon_c = Vector2i(rng.randi_range(2, 4), H - 3)
			reserved[beacon_c] = true
			for d in Board.DIRS8:
				reserved[beacon_c + d] = true

		# 물 웅덩이
		var water_n := rng.randi_range(int(bd["water"][0]), int(bd["water"][1]))
		if water_n > 0:
			var cur := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(1, H - 3))
			var placed := 0
			var guard := 0
			while placed < water_n and guard < 200:
				guard += 1
				if b.in_bounds(cur) and not reserved.has(cur) and b.tile(cur) == Board.FLOOR:
					b.set_tile(cur, Board.WATER)
					placed += 1
				var dd: Vector2i = Board.DIRS4[rng.randi_range(0, 3)]
				var nxt: Vector2i = cur + dd
				if b.in_bounds(nxt) and nxt.y < H - 1:
					cur = nxt
				if rng.randf() < 0.12:
					cur = Vector2i(rng.randi_range(0, W - 1), rng.randi_range(1, H - 3))
		_place(b, rng, Board.PILLAR, rng.randi_range(int(bd["pillar"][0]), int(bd["pillar"][1])), reserved)
		_place(b, rng, Board.CRATE, rng.randi_range(int(bd["crate"][0]), int(bd["crate"][1])), reserved)
		var mirrors := rng.randi_range(int(bd["mirror"][0]), int(bd["mirror"][1])) + int(mods.get("extra_mirrors", 0))
		if obj_type == "boss" and biome == "mirror":
			mirrors = max(mirrors, 3)
		_place(b, rng, Board.MIRROR, mirrors, reserved)
		_place(b, rng, Board.GLASS, rng.randi_range(int(bd["glass"][0]), int(bd["glass"][1])) + int(mods.get("extra_glass", 0)), reserved)
		_place(b, rng, Board.BRAZIER, rng.randi_range(int(bd["brazier"][0]), int(bd["brazier"][1])), reserved, 1, 5)

		if obj_type == "escape":
			b.set_tile(exit_c, Board.EXIT)
			obj["exit"] = exit_c
			obj["turns"] = 9
		if obj_type == "candles":
			var total := 3 + (1 if floor_i >= 2 else 0)
			var placed_c := []
			var guard2 := 0
			while placed_c.size() < total and guard2 < 300:
				guard2 += 1
				var c := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 4))
				if reserved.has(c) or b.tile(c) != Board.FLOOR:
					continue
				var ok := true
				for o in placed_c:
					if Board.cheb(o, c) < 3:
						ok = false
				if ok:
					b.set_tile(c, Board.CANDLE)
					placed_c.append(c)
			obj["total"] = placed_c.size()
			obj["lit"] = 0
			obj["turns"] = 5 + placed_c.size()
		if obj_type == "survive":
			obj["turns"] = min(8, 5 + floor_i)
			obj["pool"] = EnemyData.pool_for(biome, 1 + floor_i)
		b.objective = obj

		if not _connected(b, pstart):
			continue

		var hp_bonus := int(mods.get("enemy_hp", 0)) + level / 3 + (1 if floor_i >= 2 else 0)
		b.spawn_player(pstart, int(p.get("player_hp", 7)), int(p.get("player_max", 7)), int(p.get("player_move", 2)))
		if beacon_c.x >= 0:
			b.set_tile(beacon_c, Board.FLOOR)
			b.spawn_beacon(beacon_c, 3)

		var spawn_cells := []
		for y in range(0, 4):
			for x in W:
				var c := Vector2i(x, y)
				if b.is_free(c) and b.tile(c) != Board.EXIT and Board.manhattan(c, pstart) >= 5:
					spawn_cells.append(c)
		_shuffle(rng, spawn_cells)
		if spawn_cells.size() < 3:
			continue

		if kind == "boss":
			var boss_kind: String = bd["boss"]
			if p.has("boss"):
				boss_kind = p["boss"]
			var bc := Vector2i(3, 1)
			if not b.is_free(bc):
				bc = spawn_cells[0]
			spawn_cells.erase(bc)
			var boss := b.spawn_enemy(boss_kind, bc, "", 0, int(mods.get("boss_atk", 0)))
			var pct := int(mods.get("boss_hp_pct", 0)) + level * 8
			boss.max_hp = int(round(boss.max_hp * (1.0 + pct / 100.0))) + hp_bonus * 2
			boss.hp = boss.max_hp
			var minions := EnemyData.pool_for(biome, 1)
			for i in 2:
				if spawn_cells.is_empty():
					break
				b.spawn_enemy(minions[rng.randi_range(0, minions.size() - 1)], spawn_cells.pop_back(), "", hp_bonus)
		else:
			var budget := 2 + floor_i * 2 + (1 if floor_i >= 1 else 0) + (1 if floor_i >= 2 else 0) + row / 2 + int(mods.get("extra_enemy", 0)) + level
			if kind == "elite":
				budget += 1
			if obj_type == "survive":
				budget -= 1
			if obj_type == "protect" or obj_type == "escape":
				budget -= 1
			var max_tier: int = min(3, 1 + floor_i + row / 3)
			var pool := EnemyData.pool_for(biome, max_tier)
			var count_cap: int = 3 + mini(4, floor_i + row / 3 + level / 2)
			var placed_e := 0
			if kind == "elite":
				var strong := []
				for k in pool:
					if int(EnemyData.ENEMIES[k]["tier"]) >= min(2, max_tier):
						strong.append(k)
				if strong.is_empty():
					strong = pool
				var ek: String = strong[rng.randi_range(0, strong.size() - 1)]
				var elites := EnemyData.ELITES.keys()
				var e1: String = elites[rng.randi_range(0, elites.size() - 1)]
				var eu := b.spawn_enemy(ek, spawn_cells.pop_back(), e1, hp_bonus + 2, int(mods.get("elite_atk", 0)))
				if int(mods.get("double_elite", 0)) > 0:
					var e2: String = elites[(elites.find(e1) + 1 + rng.randi_range(0, elites.size() - 2)) % elites.size()]
					var ed: Dictionary = EnemyData.ELITES[e2]
					eu.move += int(ed.get("move", 0))
					eu.max_hp += int(ed.get("hp", 0))
					eu.hp = eu.max_hp
					if ed.has("regen"):
						eu.st["regen"] = 1
					if ed.has("shield"):
						eu.st["shield"] = 1
						eu.st["shield_max"] = 1
				budget -= 3
				placed_e += 1
			var guard3 := 0
			while budget > 0 and placed_e < count_cap and not spawn_cells.is_empty() and guard3 < 50:
				guard3 += 1
				var k2: String = pool[rng.randi_range(0, pool.size() - 1)]
				var cost := int(EnemyData.ENEMIES[k2]["cost"])
				if cost > budget and budget < 3:
					var cheap := []
					for k3 in pool:
						if int(EnemyData.ENEMIES[k3]["cost"]) <= budget:
							cheap.append(k3)
					if cheap.is_empty():
						break
					k2 = cheap[rng.randi_range(0, cheap.size() - 1)]
					cost = int(EnemyData.ENEMIES[k2]["cost"])
				b.spawn_enemy(k2, spawn_cells.pop_back(), "", hp_bonus, 1 if floor_i >= 2 else 0)
				budget -= cost
				placed_e += 1
			if placed_e == 0:
				b.spawn_enemy(pool[0], spawn_cells.pop_back(), "", hp_bonus)
		for e in b.enemies():
			e.facing = Vector2i(0, 1)
		return b
	# 실패 시 빈 방
	var fb := Board.new(W, H)
	fb.biome = biome
	fb.objective = {"type": "annihilate"}
	fb.spawn_player(Vector2i(3, H - 1), int(p.get("player_hp", 7)), int(p.get("player_max", 7)), int(p.get("player_move", 2)))
	fb.spawn_enemy("rat", Vector2i(3, 1))
	return fb


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for k in weights.keys():
		total += int(weights[k])
	var r := rng.randi_range(0, total - 1)
	for k in weights.keys():
		r -= int(weights[k])
		if r < 0:
			return k
	return weights.keys()[0]


static func _place(b: Board, rng: RandomNumberGenerator, t: int, n: int, reserved: Dictionary, ymin: int = 1, ymax: int = H - 2) -> void:
	var guard := 0
	var placed := 0
	while placed < n and guard < 200:
		guard += 1
		var c := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(ymin, ymax))
		if reserved.has(c) or b.tile(c) != Board.FLOOR:
			continue
		# 장애물끼리 너무 뭉치지 않게
		var near := 0
		for d in Board.DIRS4:
			var tt := b.tile(c + d)
			if tt != Board.FLOOR and tt != Board.WATER and b.in_bounds(c + d):
				near += 1
		if near >= 2:
			continue
		b.set_tile(c, t)
		placed += 1


static func _connected(b: Board, start: Vector2i) -> bool:
	var seen := b.reachable_ground(start)
	for c in b.all_cells():
		if Board.is_ground(b.tile(c)) and not seen.has(c):
			return false
	return true


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
