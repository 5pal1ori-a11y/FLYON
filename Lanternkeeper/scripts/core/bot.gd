class_name Bot
## 자동 플레이(테스트·밸런스 점검·퍼즐 검증용). 미리보기 시뮬레이션으로 욕심쟁이 선택을 한다.


static func play_turn(bt: Battle, sample_moves: int = 6, sample_cells: int = 14) -> void:
	if bt.result != "":
		return
	var best := {"score": -INF, "move": bt.player().pos, "cells": []}
	var p := bt.player()
	var moves := [p.pos]
	var reach := bt.reachable()
	var keys := []
	for c in reach.keys():
		if reach[c]["type"] == "walk" or reach[c]["type"] == "step":
			keys.append(c)
	keys.sort_custom(func(a, c): return _move_pref(bt, a) > _move_pref(bt, c))
	for i in min(sample_moves, keys.size()):
		moves.append(keys[i])
	for mv in moves:
		var cb := bt.b.clone()
		cb.player().pos = mv
		if cb.objective.get("type", "") == "escape" and mv == cb.objective["exit"]:
			best = {"score": INF, "move": mv, "cells": []}
			break
		var cells := _lantern_cells(cb, bt)
		cells.sort_custom(func(a, c): return Board.manhattan(a, mv) < Board.manhattan(c, mv))
		var step: int = max(1, cells.size() / sample_cells)
		var i := 0
		while i < cells.size():
			var choice := [cells[i]]
			if bt.needs_cells() == 2:
				var other: Vector2i = cells[(i + cells.size() / 2) % cells.size()]
				if other != cells[i]:
					choice.append(other)
			var sc := _eval(bt, cb, choice)
			if sc > best["score"]:
				best = {"score": sc, "move": mv, "cells": choice}
			i += step
	if best["move"] != bt.player().pos:
		bt.move_to(best["move"])
	else:
		bt.skip_move()
	if bt.result != "":
		return
	if best["cells"].is_empty():
		var cl := bt.lantern_cells()
		if not cl.is_empty():
			best["cells"] = [cl[0]] if bt.needs_cells() == 1 else [cl[0], cl[-1]]
	bt.cast(best["cells"])


static func _move_pref(bt: Battle, c: Vector2i) -> int:
	var obj: Dictionary = bt.b.objective
	if obj.get("type", "") == "escape":
		return -Board.manhattan(c, obj["exit"])
	var nearest := 99
	for e in bt.b.enemies():
		nearest = min(nearest, Board.manhattan(c, e.pos))
	return -abs(nearest - 3)


static func _lantern_cells(cb: Board, bt: Battle) -> Array:
	var out := []
	var p := cb.player()
	var r := bt.throw_range()
	for y in range(p.pos.y - r, p.pos.y + r + 1):
		for x in range(p.pos.x - r, p.pos.x + r + 1):
			var c := Vector2i(x, y)
			if c != p.pos and cb.in_bounds(c) and Board.is_ground(cb.tile(c)) and cb.unit_at(c) == null:
				out.append(c)
	return out


static func _eval(bt: Battle, cb0: Board, cells: Array) -> float:
	var cb := cb0.clone()
	var hp0 := cb.player().hp
	var en0 := 0
	for e in cb.enemies():
		en0 += e.hp
	var res := Combat.resolve(cb, cells, bt.ctx)
	var kills := 0
	for k in res["kills"]:
		if k["team"] == Unit.TEAM_ENEMY:
			kills += 1
	var en1 := 0
	for e in cb.enemies():
		en1 += e.hp
	var score: float = kills * 10.0 + (en0 - en1) * 3.0 + res["frozen"].size() * 4.0 + res["lit"].size() * 25.0
	if cb.enemies().is_empty():
		score += 400.0
	var bc0 := cb.beacon()
	var bhp := bc0.hp if bc0 != null else 0
	EnemyAI.run(cb, bt.ctx)
	var p := cb.player()
	score -= (hp0 - max(0, p.hp)) * 9.0
	if p.dead:
		score -= 2000.0
	var bc := cb.beacon()
	if bc0 != null:
		score -= (bhp - (bc.hp if bc != null and not bc.dead else 0)) * 15.0
	if cb.objective.get("type", "") == "escape":
		score -= Board.manhattan(p.pos, cb.objective["exit"]) * 6.0
	return score


## 한 번의 이동+점화로 모든 적을 없애는 해답 목록 (퍼즐 생성·검증용)
static func solve_one_shot(bt: Battle, limit: int = 50) -> Array:
	var sols := []
	var p := bt.player()
	var moves := [p.pos]
	var reach := bt.reachable()
	for c in reach.keys():
		if reach[c]["type"] == "walk":
			moves.append(c)
	for mv in moves:
		var cb := bt.b.clone()
		cb.player().pos = mv
		var cells := _lantern_cells(cb, bt)
		var combos := []
		if bt.needs_cells() == 2:
			for i in cells.size():
				for j in range(i + 1, cells.size()):
					combos.append([cells[i], cells[j]])
		else:
			for c in cells:
				combos.append([c])
		for combo in combos:
			var t := cb.clone()
			Combat.resolve(t, combo, bt.ctx)
			if t.enemies().is_empty():
				sols.append({"move": mv, "cells": combo})
				if sols.size() >= limit:
					return sols
	return sols
