class_name Combat
## 점화 한 번의 결과를 계산하고 보드에 적용한다. 미리보기에서는 복제 보드에 같은 함수를 쓴다.


static func new_result() -> Dictionary:
	return {"lights": [], "shadows": [], "hits": [], "kills": [], "frozen": [], "shattered": [],
		"chains": [], "lit": [], "heals": [], "fx": [], "deflects": [], "spawns": [], "events": [],
		"pending": [], "enemies_hit": 0, "status": []}


static func mv(mods: Dictionary, key: String, def = 0):
	return mods.get(key, def)


static func build_lights(b: Board, cells: Array, ctx: Dictionary) -> Array:
	var lan: Dictionary = ctx["lantern"]
	var mods: Dictionary = ctx["mods"]
	var p := b.player()
	var r: float = max(1.0, float(lan["radius"]) + float(mv(mods, "radius", 0.0)) - b.radius_penalty)
	var length: int = max(1, int(lan["length"]) + int(mv(mods, "length", 0)))
	var lights := []
	var mode: String = lan["mode"]
	if cells.is_empty():
		return lights
	if mode == "directional":
		var c: Vector2i = cells[0]
		var dir := Shadows.snap8(Vector2(p.pos - c))
		lights.append({"pos": Vector2(c), "cell": c, "radius": 99.0, "length": length, "directional": true,
			"dir": dir, "mirror": false, "main": true})
	else:
		var mains := []
		for c in cells:
			mains.append(c)
		if mode == "swing":
			var off: Vector2i = cells[0] - p.pos
			var rc: Vector2i = p.pos + Vector2i(-off.y, off.x)
			if b.in_bounds(rc) and b.tile(rc) != Board.WALL and not mains.has(rc):
				mains.append(rc)
		if int(mv(mods, "mirror_copy")) > 0:
			for c in mains.duplicate():
				var mc: Vector2i = p.pos * 2 - c
				if b.in_bounds(mc) and b.tile(mc) != Board.WALL and not mains.has(mc):
					mains.append(mc)
		for c in mains:
			lights.append({"pos": Vector2(c), "cell": c, "radius": r, "length": length, "directional": false,
				"mirror": false, "main": true})
	var pm := int(mv(mods, "player_mirror"))
	if pm > 0 and mode != "directional":
		lights.append({"pos": Vector2(p.pos), "cell": p.pos, "radius": 1.5 + 0.5 * (pm - 1),
			"length": max(1, length - 1), "directional": false, "mirror": true, "main": false})
	var mr: float = 2.0 + float(mv(mods, "mirror_radius", 0.0))
	var main_lights := lights.duplicate()
	for mc in b.cells_of(Board.MIRROR):
		var on := false
		for li in main_lights:
			if not li["main"]:
				continue
			if li["directional"] or Vector2(mc).distance_to(li["pos"]) <= float(li["radius"]) + 0.01:
				on = true
				break
		if on:
			lights.append({"pos": Vector2(mc), "cell": mc, "radius": mr, "length": max(1, length - 1),
				"directional": false, "mirror": true, "main": false})
	return lights


static func light_covers(light: Dictionary, c: Vector2i) -> bool:
	if light["directional"]:
		return true
	return Vector2(c).distance_to(light["pos"]) <= float(light["radius"]) + 0.01


## 점화. cells = 플레이어가 고른 등불 칸(쌍둥이 램프는 2칸).
static func resolve(b: Board, cells: Array, ctx: Dictionary) -> Dictionary:
	var mods: Dictionary = ctx["mods"]
	var lan: Dictionary = ctx["lantern"]
	var echo: bool = ctx.get("echo", false)
	var res := new_result()
	var p := b.player()
	if p == null or cells.is_empty():
		return res
	var lights := build_lights(b, cells, ctx)
	res["lights"] = lights
	var blocked := Shadows.blocked_cells(b)
	var caster_list := Shadows.casters(b)
	var shadows := []
	for i in lights.size():
		for s in Shadows.cast_light(b, lights[i], blocked, caster_list):
			s["light"] = i
			shadows.append(s)

	# 넓은 그림자: 내 그림자의 처음 두 칸 양옆
	if int(mv(mods, "player_wide")) > 0 and not echo:
		for s in shadows:
			if not s["caster"]["is_player"]:
				continue
			var perp := Vector2(-s["dir"].y, s["dir"].x)
			var add := []
			for i in min(2, s["cells"].size()):
				for sgn in [-1, 1]:
					var pc: Vector2 = Vector2(s["cells"][i]) + perp * sgn
					var nc := Vector2i(roundi(pc.x), roundi(pc.y))
					var tt := b.tile(nc)
					if b.in_bounds(nc) and tt != Board.WALL and tt != Board.MIRROR and not blocked.has(nc) \
							and not s["cells"].has(nc) and not add.has(nc) and nc != p.pos:
						add.append(nc)
			for nc in add:
				s["cells"].append(nc)
				s["dists"].append(1)

	# 물길 번짐 (아군 그림자만)
	for s in shadows:
		if s["caster"]["team"] != Unit.TEAM_PLAYER:
			continue
		var fl := Shadows.flood(b, s["cells"])
		if not fl.is_empty():
			s["flood"] = fl
			for c in fl:
				s["cells"].append(c)
				s["dists"].append(99)
			res["fx"].append({"type": "flood", "cells": fl})
	res["shadows"] = shadows

	# 초 켜기 & 빛 닿은 칸 기록
	b.last_lit = {}
	for y in b.h:
		for x in b.w:
			var c := Vector2i(x, y)
			for li in lights:
				if light_covers(li, c):
					b.last_lit[c] = true
					break
	if not echo:
		for c in b.cells_of(Board.CANDLE):
			if b.last_lit.has(c):
				b.set_tile(c, Board.CANDLE_LIT)
				res["lit"].append(c)
				b.objective["lit"] = int(b.objective.get("lit", 0)) + 1

	# ── 적중 판정 ──
	var per := {}     # uid -> {dmg, count, from_pillar, flooded}
	var order := []
	if lan["mode"] == "inverse" and not echo:
		var dark := {}
		for s in shadows:
			for c in s["cells"]:
				dark[c] = true
		for li in lights:
			for e in b.enemies():
				if dark.has(e.pos) or not light_covers(li, e.pos) or e.pos == li["cell"]:
					continue
				var d := _base_damage(b, e, p, ctx, li, null, 0)
				_add_hit(per, order, e.id, d, false, false)
	else:
		for s in shadows:
			if s["caster"]["team"] != Unit.TEAM_PLAYER:
				continue
			var seen := {}
			for idx in s["cells"].size():
				var cell: Vector2i = s["cells"][idx]
				var u := b.unit_at(cell)
				if u == null or not u.is_enemy() or seen.has(u.id):
					continue
				seen[u.id] = true
				if u.front_guard and not u.frozen() and not echo:
					if s["dir"].dot(Vector2(u.facing)) < -0.3:
						res["deflects"].append({"id": u.id, "pos": u.pos})
						continue
				var d: int
				if echo:
					d = 1
				else:
					d = _base_damage(b, u, p, ctx, lights[s["light"]], s, idx)
				var flooded: bool = s["flood"].has(cell)
				_add_hit(per, order, u.id, d, s["caster"]["uid"] == -1, flooded)

	var n_hit := order.size()
	res["enemies_hit"] = n_hit
	var to_damage := []
	for i in order.size():
		var uid: int = order[i]
		var u := b.unit_by_id(uid)
		var h: Dictionary = per[uid]
		var total: int = h["dmg"]
		if not echo:
			if n_hit >= 3:
				total += int(mv(mods, "dmg_crowd"))
			if n_hit == 1:
				total += int(mv(mods, "solo_dmg"))
		if u.cap > 0:
			total = min(total, u.cap)
		to_damage.append([u, total])
		if echo:
			continue
		var burn := int(lan.get("burn", 0)) + int(mv(mods, "burn_on_hit"))
		if h["from_pillar"]:
			burn += int(mv(mods, "pillar_burn"))
		if burn > 0:
			u.st["burn"] = int(u.st.get("burn", 0)) + burn
			res["status"].append({"id": uid, "type": "burn"})
		var poison := int(mv(mods, "poison_on_hit"))
		if h["flooded"]:
			poison += int(mv(mods, "water_poison"))
		if poison > 0:
			u.st["poison"] = int(u.st.get("poison", 0)) + poison
			res["status"].append({"id": uid, "type": "poison"})
		if int(mv(mods, "freeze_on_multi")) > 0 and int(h["count"]) >= 2:
			_freeze(u, mods, res)
		if i == 0 and int(mv(mods, "freeze_first")) > 0:
			_freeze(u, mods, res)

	if not echo:
		# 등불 곁 화상
		var lb := int(mv(mods, "lantern_burn"))
		if lb > 0:
			for e in b.enemies():
				for li in lights:
					if li["main"] and not li["directional"] and Board.cheb(e.pos, li["cell"]) <= 1:
						e.st["burn"] = int(e.st.get("burn", 0)) + lb
						res["status"].append({"id": e.id, "type": "burn"})
						break
		# 그림자 밟기 → 굳음
		var mine := {}
		var any_ally := int(mv(mods, "freeze_any_shadow")) > 0
		for s in shadows:
			if s["caster"]["is_player"] or (any_ally and s["caster"]["team"] == Unit.TEAM_PLAYER):
				for c in s["cells"]:
					mine[c] = true
		for s in shadows:
			if s["caster"]["team"] != Unit.TEAM_ENEMY:
				continue
			for c in s["cells"]:
				if mine.has(c):
					var eu := b.unit_by_id(s["caster"]["uid"])
					if eu != null and not eu.dead:
						_freeze(eu, mods, res)
					break
		# 유리 파편
		var glass := {}
		for s in shadows:
			if s["caster"]["team"] != Unit.TEAM_PLAYER:
				continue
			for c in s["cells"]:
				if b.tile(c) == Board.GLASS:
					glass[c] = true
		for g in glass.keys():
			b.set_tile(g, Board.FLOOR)
			res["shattered"].append(g)
			var gd := 1 + int(mv(mods, "glass_dmg"))
			for e in b.enemies():
				if Board.cheb(e.pos, g) <= 1:
					to_damage.append([e, gd])

	for pair in to_damage:
		damage(b, pair[0], pair[1], res, mods, "shadow")
	process_deaths(b, res, mods, not echo)

	if not echo:
		var kills := 0
		for k in res["kills"]:
			if k["team"] == Unit.TEAM_ENEMY:
				kills += 1
		var heal := 0
		if n_hit >= 2:
			heal += int(mv(mods, "heal_multi"))
		if kills >= 2:
			heal += int(mv(mods, "heal_on_kill_multi"))
		if kills >= 1:
			heal += int(mv(mods, "heal_on_kill"))
		if heal > 0:
			heal_unit(p, heal, res)
		var pcells := []
		var all_cells := {}
		for s in shadows:
			if s["caster"]["is_player"]:
				for c in s["cells"]:
					if not pcells.has(c):
						pcells.append(c)
			if s["caster"]["team"] == Unit.TEAM_PLAYER:
				for c in s["cells"]:
					all_cells[c] = true
		b.last_player_shadow = pcells
		b.lingering = all_cells.keys() if int(mv(mods, "linger")) > 0 else []
		b.last_cells = cells.duplicate()
		b.casts += 1
	b.cleanup_dead()
	return res


static func _add_hit(per: Dictionary, order: Array, uid: int, d: int, from_pillar: bool, flooded: bool) -> void:
	if not per.has(uid):
		per[uid] = {"dmg": 0, "count": 0, "from_pillar": false, "flooded": false}
		order.append(uid)
	per[uid]["dmg"] += d
	per[uid]["count"] += 1
	if from_pillar:
		per[uid]["from_pillar"] = true
	if flooded:
		per[uid]["flooded"] = true


static func _base_damage(b: Board, u: Unit, p: Unit, ctx: Dictionary, light: Dictionary, s, idx: int) -> int:
	var mods: Dictionary = ctx["mods"]
	var d := int(ctx["lantern"]["dmg"]) + int(mv(mods, "dmg"))
	if light["mirror"]:
		d += int(mv(mods, "mirror_dmg"))
	if s != null:
		if s["caster"]["is_player"]:
			d += int(mv(mods, "player_shadow_dmg"))
		elif s["caster"]["uid"] == -1:
			d += int(mv(mods, "pillar_dmg"))
		var dist: int = s["dists"][idx]
		if dist <= 2:
			d += int(mv(mods, "dmg_near"))
		elif dist < 99:
			d += int(mv(mods, "dmg_far"))
		if dist == 99:
			d += int(mv(mods, "water_dmg"))
	if Board.cheb(u.pos, p.pos) == 1:
		d += int(mv(mods, "dmg_adjacent"))
	if u.frozen():
		d += int(mv(mods, "dmg_vs_frozen"))
	if u.burning():
		d += int(mv(mods, "dmg_vs_burning"))
	if u.poisoned():
		d += int(mv(mods, "dmg_vs_poisoned"))
	if p.hp * 2 <= p.max_hp:
		d += int(mv(mods, "dmg_low_hp"))
	if b.casts == 0:
		d += int(mv(mods, "first_cast_dmg"))
	return max(0, d)


static func _freeze(u: Unit, mods: Dictionary, res: Dictionary) -> void:
	var dur := 1 + int(mv(mods, "freeze_duration"))
	if u.boss:
		dur = 1
	if int(u.st.get("frozen", 0)) < dur:
		u.st["frozen"] = dur
	u.ai.erase("aim")
	u.ai.erase("charge")
	u.ai.erase("wave")
	if not res["frozen"].has(u.id):
		res["frozen"].append(u.id)
		res["events"].append({"type": "freeze", "id": u.id, "pos": u.pos})


static func heal_unit(u: Unit, n: int, res: Dictionary) -> void:
	if u == null or u.dead or n <= 0:
		return
	var before := u.hp
	u.hp = min(u.max_hp, u.hp + n)
	if u.hp > before:
		res["heals"].append({"id": u.id, "amt": u.hp - before, "pos": u.pos})
		res["events"].append({"type": "heal", "id": u.id, "amt": u.hp - before, "pos": u.pos})


static func damage(b: Board, u: Unit, amt: int, res: Dictionary, mods: Dictionary, src: String) -> int:
	if u == null or u.dead or amt <= 0:
		return 0
	if u.team == Unit.TEAM_PLAYER and u.is_player() and b.ward_left > 0 and src != "dark":
		var a: int = min(b.ward_left, amt)
		b.ward_left -= a
		amt -= a
		res["fx"].append({"type": "ward", "id": u.id, "amt": a, "pos": u.pos})
	elif u.is_enemy() and int(u.st.get("shield", 0)) > 0:
		var a2: int = min(int(u.st["shield"]), amt)
		u.st["shield"] = int(u.st["shield"]) - a2
		amt -= a2
		res["fx"].append({"type": "shield", "id": u.id, "amt": a2, "pos": u.pos})
	if amt <= 0:
		return 0
	u.hp -= amt
	res["hits"].append({"id": u.id, "amt": amt, "pos": u.pos, "src": src, "team": u.team})
	res["events"].append({"type": "dmg", "id": u.id, "amt": amt, "pos": u.pos, "src": src, "team": u.team})
	if u.hp <= 0:
		if u.is_player() and int(mv(mods, "revive")) > 0 and not b.revive_used:
			b.revive_used = true
			u.hp = max(1, u.max_hp / 2)
			res["fx"].append({"type": "revive", "id": u.id, "pos": u.pos})
			res["events"].append({"type": "revive", "id": u.id, "pos": u.pos})
		else:
			u.hp = 0
			u.dead = true
			res["pending"].append({"u": u, "src": src})
	return amt


static func process_deaths(b: Board, res: Dictionary, mods: Dictionary, allow_chain: bool) -> void:
	var heal_burn_done := false
	var guard := 0
	while not res["pending"].is_empty() and guard < 200:
		guard += 1
		var entry: Dictionary = res["pending"].pop_front()
		var u: Unit = entry["u"]
		var src: String = entry["src"]
		res["kills"].append({"id": u.id, "kind": u.kind, "pos": u.pos, "boss": u.boss, "team": u.team, "elite": u.elite,
			"burning": u.burning(), "poisoned": u.poisoned(), "src": src})
		res["events"].append({"type": "death", "id": u.id, "pos": u.pos, "kind": u.kind, "team": u.team})
		if not u.is_enemy():
			continue
		var d: Dictionary = EnemyData.get_def(u.kind)
		b.oil_gained += int(mv(mods, "oil_on_kill"))
		# 분열
		if d.has("split"):
			var n := 0
			for dir in Board.DIRS8:
				if n >= 2:
					break
				var c: Vector2i = u.pos + dir
				if b.is_free(c):
					var s := b.spawn_enemy(d["split"], c)
					s.st["frozen"] = 0
					res["spawns"].append({"id": s.id, "kind": s.kind, "pos": c, "from": u.pos})
					res["events"].append({"type": "spawn", "id": s.id, "kind": s.kind, "pos": c, "from": u.pos})
					n += 1
		# 폭발
		var ex := int(d.get("explode", 0)) + (1 if u.elite == "volatile" else 0)
		if u.ai.get("exploded", false):
			ex = 0
		if ex > 0:
			res["fx"].append({"type": "explode", "pos": u.pos})
			res["events"].append({"type": "explode", "id": u.id, "pos": u.pos})
			for v in b.units.duplicate():
				if v != u and not v.dead and Board.cheb(v.pos, u.pos) <= 1 and not v.is_beacon():
					damage(b, v, ex, res, mods, "explode")
		if u.burning():
			var be := int(mv(mods, "burning_explode"))
			if be > 0:
				res["fx"].append({"type": "explode", "pos": u.pos})
				res["events"].append({"type": "explode", "id": u.id, "pos": u.pos})
				for v in b.enemies():
					if Board.cheb(v.pos, u.pos) <= 1:
						damage(b, v, be, res, mods, "explode")
			var bs := int(mv(mods, "burn_spread"))
			if bs > 0:
				for v in b.enemies():
					if Board.cheb(v.pos, u.pos) <= 1:
						v.st["burn"] = int(v.st.get("burn", 0)) + bs
						res["status"].append({"id": v.id, "type": "burn"})
			if int(mv(mods, "heal_burn_kill")) > 0 and not heal_burn_done:
				heal_burn_done = true
				heal_unit(b.player(), int(mv(mods, "heal_burn_kill")), res)
		if u.poisoned():
			var ps := int(mv(mods, "poison_spread"))
			if ps > 0:
				for v in b.enemies():
					if Board.cheb(v.pos, u.pos) <= 1:
						v.st["poison"] = int(v.st.get("poison", 0)) + ps
						res["status"].append({"id": v.id, "type": "poison"})
		if u.frozen() and int(mv(mods, "shatter")) > 0:
			for v in b.enemies():
				if Board.cheb(v.pos, u.pos) <= 1:
					_freeze(v, {"freeze_duration": 0}, res)
		# 연쇄
		var ch := int(mv(mods, "chain"))
		if allow_chain and ch > 0 and src != "chain":
			var rng := 3 + int(mv(mods, "chain_range"))
			var cb := int(mv(mods, "chain_burn"))
			if int(mv(mods, "chain_all")) > 0:
				for v in b.enemies():
					if Board.cheb(v.pos, u.pos) <= rng:
						res["chains"].append({"from": u.pos, "to": v.pos})
						res["events"].append({"type": "chain", "from": u.pos, "to": v.pos})
						if cb > 0:
							v.st["burn"] = int(v.st.get("burn", 0)) + cb
						damage(b, v, ch, res, mods, "chain")
			else:
				var cur := u.pos
				var visited := {}
				for j in 1 + int(mv(mods, "chain_jumps")):
					var best: Unit = null
					var bd := 999
					for v in b.enemies():
						if visited.has(v.id):
							continue
						var dd := Board.cheb(v.pos, cur)
						if dd <= rng and (dd < bd or (dd == bd and best != null and v.id < best.id)):
							best = v
							bd = dd
					if best == null:
						break
					visited[best.id] = true
					res["chains"].append({"from": cur, "to": best.pos})
					res["events"].append({"type": "chain", "from": cur, "to": best.pos})
					if cb > 0:
						best.st["burn"] = int(best.st.get("burn", 0)) + cb
					damage(b, best, ch, res, mods, "chain")
					cur = best.pos
