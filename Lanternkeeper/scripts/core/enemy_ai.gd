class_name EnemyAI
## 적 턴. 모든 행동은 결정적이라 미리보기와 실제 결과가 같다.

const MAX_ENEMIES := 10


static func run(b: Board, ctx: Dictionary) -> Dictionary:
	var mods: Dictionary = ctx["mods"]
	var res := Combat.new_result()
	var p := b.player()
	b.ward_left = int(Combat.mv(mods, "ward"))
	if int(Combat.mv(mods, "ward_frozen")) > 0:
		for e in b.enemies():
			if e.frozen():
				b.ward_left += int(Combat.mv(mods, "ward_frozen"))
				break
	var order := b.enemies()
	order.sort_custom(func(a, c): return a.id < c.id)
	for u in order:
		if u.dead:
			continue
		if p.dead:
			break
		if u.frozen():
			u.st["frozen"] = int(u.st["frozen"]) - 1
			res["events"].append({"type": "frozen", "id": u.id, "pos": u.pos})
			continue
		_act(b, u, ctx, res)
		Combat.process_deaths(b, res, mods, false)
	if not p.dead:
		_end_phase(b, ctx, res)
	b.cleanup_dead()
	b.turn += 1
	return res


static func target_of(b: Board, u: Unit) -> Unit:
	var p := b.player()
	var bc := b.beacon()
	if bc != null and Board.manhattan(u.pos, bc.pos) < Board.manhattan(u.pos, p.pos):
		return bc
	return p


static func _face(u: Unit, toward: Vector2i) -> void:
	var d := toward - u.pos
	if d == Vector2i.ZERO:
		return
	if abs(d.x) >= abs(d.y):
		u.facing = Vector2i(sign(d.x), 0)
	else:
		u.facing = Vector2i(0, sign(d.y))


static func _move_along(b: Board, u: Unit, steps: Array, res: Dictionary, web: bool = false) -> void:
	var path := []
	for s in steps:
		if not b.is_free(s, u.flying):
			break
		var prev := u.pos
		u.pos = s
		path.append(s)
		if web and b.tile(prev) == Board.FLOOR:
			b.set_tile(prev, Board.WEB)
	if not path.is_empty():
		res["events"].append({"type": "move", "id": u.id, "path": path})


static func _attack(b: Board, u: Unit, t: Unit, ctx: Dictionary, res: Dictionary, src: String = "melee") -> void:
	var mods: Dictionary = ctx["mods"]
	_face(u, t.pos)
	res["events"].append({"type": "attack", "id": u.id, "from": u.pos, "to": t.pos, "target": t.id})
	Combat.damage(b, t, u.atk, res, mods, src)
	if t.is_player() and int(Combat.mv(mods, "thorns")) > 0 and not u.dead:
		Combat.damage(b, u, int(Combat.mv(mods, "thorns")), res, mods, "thorns")


static func _melee(b: Board, u: Unit, ctx: Dictionary, res: Dictionary, web: bool = false) -> void:
	var t := target_of(b, u)
	if Board.manhattan(u.pos, t.pos) == 1:
		_attack(b, u, t, ctx, res)
		return
	if u.move <= 0:
		return
	var path := b.path_toward(u.pos, t.pos, u.flying)
	_move_along(b, u, path.slice(0, u.move), res, web)
	_face(u, t.pos)
	if Board.manhattan(u.pos, t.pos) == 1:
		_attack(b, u, t, ctx, res)


static func _step_away(b: Board, u: Unit, from: Vector2i, res: Dictionary) -> void:
	var best := u.pos
	var bd := Board.manhattan(u.pos, from)
	for d in Board.DIRS4:
		var n: Vector2i = u.pos + d
		if b.is_free(n, u.flying) and Board.manhattan(n, from) > bd:
			best = n
			bd = Board.manhattan(n, from)
	if best != u.pos:
		_move_along(b, u, [best], res)


static func _summon(b: Board, u: Unit, kind: String, count: int, res: Dictionary) -> void:
	var p := b.player()
	var cands := []
	for d in Board.DIRS8:
		var c: Vector2i = u.pos + d
		if b.is_free(c):
			cands.append(c)
	cands.sort_custom(func(a, c): return Board.manhattan(a, p.pos) < Board.manhattan(c, p.pos))
	for i in min(count, cands.size()):
		if b.enemies().size() >= MAX_ENEMIES:
			break
		var s := b.spawn_enemy(kind, cands[i])
		res["spawns"].append({"id": s.id, "kind": kind, "pos": cands[i], "from": u.pos})
		res["events"].append({"type": "spawn", "id": s.id, "kind": kind, "pos": cands[i], "from": u.pos})


static func _blocks_projectile(t: int) -> bool:
	return not Board.is_ground(t)


static func line_cells(b: Board, from: Vector2i, dir: Vector2i, rng: int) -> Array:
	var out := []
	var c := from + dir
	for i in rng:
		if not b.in_bounds(c) or _blocks_projectile(b.tile(c)):
			break
		out.append(c)
		if b.unit_at(c) != null:
			break
		c += dir
	return out


static func _aligned_dir(b: Board, from: Vector2i, to: Vector2i, rng: int) -> Vector2i:
	if from.x != to.x and from.y != to.y:
		return Vector2i.ZERO
	var d := Vector2i(sign(to.x - from.x), sign(to.y - from.y))
	if d == Vector2i.ZERO:
		return d
	var cells := line_cells(b, from, d, rng)
	if cells.has(to):
		return d
	return Vector2i.ZERO


static func _act(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	var mods: Dictionary = ctx["mods"]
	var d: Dictionary = EnemyData.get_def(u.kind)
	var p := b.player()
	match d["ai"]:
		"melee":
			_melee(b, u, ctx, res)
		"spider":
			_melee(b, u, ctx, res, true)
		"statue":
			if b.last_lit.has(u.pos):
				res["events"].append({"type": "still", "id": u.id, "pos": u.pos})
			else:
				_melee(b, u, ctx, res)
		"bomber":
			var t := target_of(b, u)
			if Board.manhattan(u.pos, t.pos) > 1:
				_move_along(b, u, b.path_toward(u.pos, t.pos, u.flying).slice(0, u.move), res)
			if Board.manhattan(u.pos, t.pos) <= 1:
				_explode_self(b, u, ctx, res)
		"archer":
			_archer(b, u, ctx, res, int(d.get("range", 5)))
		"charger":
			_charger(b, u, ctx, res)
		"healer":
			for v in b.enemies():
				if v != u and Board.cheb(v.pos, u.pos) <= 1 and v.hp < v.max_hp:
					Combat.heal_unit(v, 1, res)
			if Board.manhattan(u.pos, p.pos) <= 2:
				_step_away(b, u, p.pos, res)
			else:
				var friend: Unit = null
				var fd := 999
				for v in b.enemies():
					if v != u and Board.manhattan(v.pos, u.pos) < fd:
						friend = v
						fd = Board.manhattan(v.pos, u.pos)
				if friend != null and fd > 1:
					_move_along(b, u, b.path_toward(u.pos, friend.pos, u.flying).slice(0, 1), res)
		"summoner":
			u.ai["cd"] = int(u.ai.get("cd", 3)) - 1
			if int(u.ai["cd"]) <= 0:
				_summon(b, u, "rat", 1, res)
				u.ai["cd"] = 3
			var md := Board.manhattan(u.pos, p.pos)
			if md < 3:
				_step_away(b, u, p.pos, res)
			elif md > 5:
				_move_along(b, u, b.path_toward(u.pos, p.pos, u.flying).slice(0, 1), res)
		"creeper":
			var t2 := target_of(b, u)
			if Board.manhattan(u.pos, t2.pos) == 1:
				_attack(b, u, t2, ctx, res)
			u.ai["cd"] = int(u.ai.get("cd", 2)) - 1
			if int(u.ai["cd"]) <= 0:
				_darken(b, u.pos, 2, 2, res)
				u.ai["cd"] = 2
		"boss_queen":
			_boss_queen(b, u, ctx, res)
		"boss_mirror":
			_boss_mirror(b, u, ctx, res)
		"boss_archivist":
			_boss_archivist(b, u, ctx, res)
		"boss_eclipse":
			_boss_eclipse(b, u, ctx, res)
		_:
			_melee(b, u, ctx, res)


static func _explode_self(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	u.ai["exploded"] = true
	res["fx"].append({"type": "explode", "pos": u.pos})
	res["events"].append({"type": "explode", "id": u.id, "pos": u.pos})
	for v in b.units.duplicate():
		if v != u and not v.dead and Board.cheb(v.pos, u.pos) <= 1:
			Combat.damage(b, v, u.atk, res, ctx["mods"], "explode")
	if not u.dead:
		u.hp = 0
		u.dead = true
		res["pending"].append({"u": u, "src": "self"})


static func _darken(b: Board, center: Vector2i, rad: int, count: int, res: Dictionary) -> void:
	var p := b.player()
	var cands := []
	for y in range(center.y - rad, center.y + rad + 1):
		for x in range(center.x - rad, center.x + rad + 1):
			var c := Vector2i(x, y)
			if b.tile(c) == Board.FLOOR or b.tile(c) == Board.WEB:
				cands.append(c)
	cands.sort_custom(func(a, c): return Board.manhattan(a, p.pos) < Board.manhattan(c, p.pos) \
		or (Board.manhattan(a, p.pos) == Board.manhattan(c, p.pos) and (a.y * 10 + a.x) < (c.y * 10 + c.x)))
	var done := []
	for i in min(count, cands.size()):
		b.set_tile(cands[i], Board.DARK)
		done.append(cands[i])
	if not done.is_empty():
		res["events"].append({"type": "darken", "cells": done})


static func _archer(b: Board, u: Unit, ctx: Dictionary, res: Dictionary, rng: int) -> void:
	if u.ai.has("aim"):
		var dir: Vector2i = u.ai["aim"]
		u.ai.erase("aim")
		var cells := line_cells(b, u.pos, dir, rng)
		res["events"].append({"type": "shoot", "id": u.id, "cells": cells, "from": u.pos})
		if not cells.is_empty():
			var v := b.unit_at(cells[-1])
			if v != null:
				Combat.damage(b, v, u.atk, res, ctx["mods"], "shot")
		return
	var t := target_of(b, u)
	var ad := _aligned_dir(b, u.pos, t.pos, rng)
	if ad == Vector2i.ZERO:
		_move_along(b, u, b.path_toward(u.pos, t.pos, u.flying).slice(0, 1), res)
		ad = _aligned_dir(b, u.pos, t.pos, rng)
	if ad != Vector2i.ZERO:
		u.ai["aim"] = ad
		u.facing = ad
		res["events"].append({"type": "aim", "id": u.id, "cells": line_cells(b, u.pos, ad, rng)})


static func _charger(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	if u.ai.has("charge"):
		var dir: Vector2i = u.ai["charge"]
		u.ai.erase("charge")
		var path := []
		var c := u.pos
		var hit_unit: Unit = null
		var stunned := false
		while true:
			var n := c + dir
			if not b.in_bounds(n) or not b.walkable(n):
				stunned = true
				break
			var v := b.unit_at(n)
			if v != null:
				hit_unit = v
				break
			c = n
			path.append(n)
		if not path.is_empty():
			u.pos = c
			res["events"].append({"type": "move", "id": u.id, "path": path, "fast": true})
		if hit_unit != null:
			res["events"].append({"type": "attack", "id": u.id, "from": u.pos, "to": hit_unit.pos, "target": hit_unit.id})
			Combat.damage(b, hit_unit, u.atk, res, ctx["mods"], "charge")
		elif stunned:
			u.st["frozen"] = 1
			res["events"].append({"type": "stun", "id": u.id, "pos": u.pos})
		return
	var t := target_of(b, u)
	if Board.manhattan(u.pos, t.pos) == 1:
		_attack(b, u, t, ctx, res)
		return
	var ad := _aligned_dir(b, u.pos, t.pos, 7)
	if ad != Vector2i.ZERO:
		u.ai["charge"] = ad
		u.facing = ad
		res["events"].append({"type": "aim", "id": u.id, "cells": line_cells(b, u.pos, ad, 7), "charge": true})
		return
	_move_along(b, u, b.path_toward(u.pos, t.pos, u.flying).slice(0, u.move), res)
	_face(u, t.pos)


static func _boss_phase2(u: Unit) -> bool:
	if u.hp * 2 <= u.max_hp and not u.ai.get("p2", false):
		u.ai["p2"] = true
		return true
	return false


static func _boss_queen(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	u.ai["t"] = int(u.ai.get("t", 0)) + 1
	if _boss_phase2(u):
		b.radius_penalty += 0.5
		res["events"].append({"type": "banner", "text": "안개가 짙어진다… 빛이 줄어든다"})
	var every := 2 if u.ai.get("p2", false) else 3
	if int(u.ai["t"]) % every == 0:
		_summon(b, u, "mist", 2 if u.ai.get("p2", false) else 1, res)
	_melee(b, u, ctx, res)


static func _boss_mirror(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	u.ai["t"] = int(u.ai.get("t", 0)) + 1
	var p := b.player()
	if _boss_phase2(u):
		_summon(b, u, "knight", 1, res)
		res["events"].append({"type": "banner", "text": "거울 군주가 기사를 불러낸다"})
	if int(u.ai["t"]) % 3 == 0:
		var mirrors := b.cells_of(Board.MIRROR)
		if not mirrors.is_empty():
			mirrors.sort_custom(func(a, c): return Board.manhattan(a, p.pos) < Board.manhattan(c, p.pos))
			var target: Vector2i = mirrors[0]
			if Board.manhattan(target, p.pos) <= 1 and mirrors.size() > 1:
				target = mirrors[1]
			var old := u.pos
			b.set_tile(target, Board.FLOOR)
			u.pos = target
			if Board.is_ground(b.tile(old)):
				b.set_tile(old, Board.MIRROR)
			_face(u, p.pos)
			res["events"].append({"type": "teleport", "id": u.id, "from": old, "to": target})
			return
	_melee(b, u, ctx, res)


static func _boss_archivist(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	u.ai["t"] = int(u.ai.get("t", 0)) + 1
	var p := b.player()
	# 바닥을 물에 잠기게
	var cands := []
	for c in b.all_cells():
		if b.tile(c) == Board.FLOOR:
			cands.append(c)
	cands.sort_custom(func(a, c): return Board.manhattan(a, p.pos) < Board.manhattan(c, p.pos) \
		or (Board.manhattan(a, p.pos) == Board.manhattan(c, p.pos) and (a.y * 10 + a.x) < (c.y * 10 + c.x)))
	var flooded := []
	for i in min(2, cands.size()):
		if Board.manhattan(cands[i], p.pos) >= 2:
			b.set_tile(cands[i], Board.WATER)
			flooded.append(cands[i])
	if not flooded.is_empty():
		res["events"].append({"type": "flood_tiles", "cells": flooded})
	if _boss_phase2(u):
		res["events"].append({"type": "banner", "text": "사서가 물결을 더 자주 부른다"})
	if u.ai.has("wave"):
		var row: int = int(u.ai["wave"])
		u.ai.erase("wave")
		var cells := []
		for x in b.w:
			cells.append(Vector2i(x, row))
		res["events"].append({"type": "wave", "id": u.id, "cells": cells})
		for c in cells:
			var v := b.unit_at(c)
			if v != null and v.team == Unit.TEAM_PLAYER:
				Combat.damage(b, v, u.atk + 1, res, ctx["mods"], "wave")
		return
	if u.ai.get("p2", false) or int(u.ai["t"]) % 2 == 0:
		u.ai["wave"] = p.pos.y
		var cells2 := []
		for x in b.w:
			cells2.append(Vector2i(x, p.pos.y))
		res["events"].append({"type": "aim", "id": u.id, "cells": cells2, "wave": true})
	if int(u.ai["t"]) % 4 == 0:
		_summon(b, u, "ghost", 1, res)
	if Board.manhattan(u.pos, p.pos) < 3:
		_step_away(b, u, p.pos, res)


static func _boss_eclipse(b: Board, u: Unit, ctx: Dictionary, res: Dictionary) -> void:
	u.ai["t"] = int(u.ai.get("t", 0)) + 1
	if b.radius_penalty < 1.5:
		b.radius_penalty = min(1.5, b.radius_penalty + 0.25)
	if _boss_phase2(u):
		u.atk += 1
		res["events"].append({"type": "banner", "text": "일식이 짙어진다. 공격력 +1"})
	if int(u.ai["t"]) % 3 == 0:
		_summon(b, u, "moth" if int(u.ai["t"]) % 2 == 1 else "bomber", 2, res)
	_melee(b, u, ctx, res)


static func _end_phase(b: Board, ctx: Dictionary, res: Dictionary) -> void:
	var mods: Dictionary = ctx["mods"]
	var p := b.player()
	for u in b.enemies():
		var burn := int(u.st.get("burn", 0))
		if burn > 0:
			Combat.damage(b, u, 1 + int(Combat.mv(mods, "burn_tick")), res, mods, "burn")
			u.st["burn"] = burn - 1
		var poison := int(u.st.get("poison", 0))
		if poison > 0 and not u.dead:
			Combat.damage(b, u, poison + int(Combat.mv(mods, "poison_tick")), res, mods, "poison")
			if int(Combat.mv(mods, "poison_no_decay")) == 0:
				u.st["poison"] = poison - 1
		if u.frozen() and not u.dead and int(Combat.mv(mods, "frost_tick")) > 0:
			Combat.damage(b, u, int(Combat.mv(mods, "frost_tick")), res, mods, "frost")
		if int(u.st.get("regen", 0)) > 0 and not u.dead:
			Combat.heal_unit(u, int(u.st["regen"]), res)
		if u.st.has("shield_max"):
			u.st["shield"] = int(u.st["shield_max"])
	var lg := int(Combat.mv(mods, "linger"))
	if lg > 0:
		for c in b.lingering:
			var v := b.unit_at(c)
			if v != null and v.is_enemy():
				Combat.damage(b, v, lg, res, mods, "linger")
	b.lingering = []
	if b.tile(p.pos) == Board.DARK:
		Combat.damage(b, p, 1, res, mods, "dark")
	if b.biome == "eclipse" and b.turn % 3 == 0 and b.radius_penalty < 1.5:
		b.radius_penalty = min(1.5, b.radius_penalty + 0.5)
		res["events"].append({"type": "banner", "text": "빛이 저문다 · 등불 반경 -0.5"})
	var obj: Dictionary = b.objective
	match obj.get("type", ""):
		"survive":
			if b.turn % 2 == 0 and b.turn < int(obj["turns"]):
				var pool: Array = obj.get("pool", ["rat"])
				for i in 2:
					var cells := []
					for x in b.w:
						if b.is_free(Vector2i(x, 0)):
							cells.append(Vector2i(x, 0))
					if cells.is_empty() or b.enemies().size() >= MAX_ENEMIES:
						break
					var c: Vector2i = cells[b.rand_int(cells.size())]
					var s := b.spawn_enemy(pool[b.rand_int(pool.size())], c)
					res["spawns"].append({"id": s.id, "kind": s.kind, "pos": c, "from": c})
					res["events"].append({"type": "spawn", "id": s.id, "kind": s.kind, "pos": c, "from": c})
		"escape":
			if b.turn % 2 == 0:
				var row: int = b.h - b.turn / 2
				if row >= 0:
					var done := []
					for x in b.w:
						var c2 := Vector2i(x, row)
						var t := b.tile(c2)
						if t == Board.FLOOR or t == Board.WATER or t == Board.WEB:
							b.set_tile(c2, Board.DARK)
							done.append(c2)
					if not done.is_empty():
						res["events"].append({"type": "darken", "cells": done})
	Combat.process_deaths(b, res, mods, false)
