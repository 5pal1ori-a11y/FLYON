class_name Shadows
## 칸 단위 그림자 계산.
## 광원에서 각 그림자 드리우는 것(기둥·상자·유닛)을 지나는 반직선을 따라, 반대편으로 length 칸만큼 그림자가 뻗는다.
## 벽·거울·화로에 막히고, 화로/도깨비 주변 한 칸에는 그림자가 들지 않는다.


static func blocked_cells(b: Board) -> Dictionary:
	var out := {}
	var centers := b.cells_of(Board.BRAZIER)
	for u in b.units:
		if not u.dead and u.has_aura():
			centers.append(u.pos)
	for c in centers:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out[c + Vector2i(dx, dy)] = true
	return out


## 그림자를 드리우는 것들: {cell, team, uid(-1이면 지형), is_player}
static func casters(b: Board) -> Array:
	var out := []
	for y in b.h:
		for x in b.w:
			var c := Vector2i(x, y)
			var t := b.tile(c)
			if Board.is_obstacle_caster(t) and b.unit_at(c) == null:
				out.append({"cell": c, "team": Unit.TEAM_PLAYER, "uid": -1, "is_player": false})
	for u in b.units:
		if u.dead or not u.casts_shadow():
			continue
		out.append({"cell": u.pos, "team": u.team, "uid": u.id, "is_player": u.is_player()})
	return out


static func cast_light(b: Board, light: Dictionary, blocked: Dictionary, caster_list: Array = []) -> Array:
	if caster_list.is_empty():
		caster_list = casters(b)
	var res := []
	var lp: Vector2 = light["pos"]
	var directional: bool = light.get("directional", false)
	var length: int = int(light["length"])
	var radius: float = float(light.get("radius", 0.0))
	for c in caster_list:
		var cell: Vector2i = c["cell"]
		if not directional and cell == light["cell"]:
			continue
		var cp := Vector2(cell)
		var dir: Vector2
		if directional:
			dir = light["dir"]
		else:
			var off := cp - lp
			if off.length() < 0.01 or off.length() > radius + 0.01:
				continue
			dir = off.normalized()
		var cells := []
		var dists := []
		var t := 0.5
		var last := cell
		while t <= float(length) + 0.01:
			var p := cp + dir * t
			var nc := Vector2i(roundi(p.x), roundi(p.y))
			if nc != last:
				if not b.in_bounds(nc):
					break
				var tt := b.tile(nc)
				if tt == Board.WALL or tt == Board.MIRROR or tt == Board.BRAZIER:
					break
				if blocked.has(nc):
					break
				if nc != cell and not cells.has(nc):
					cells.append(nc)
					dists.append(int(ceil(t)))
				last = nc
			t += 0.5
		if not cells.is_empty():
			res.append({"caster": c, "cells": cells, "dists": dists, "dir": dir, "flood": []})
	return res


## 물에 닿은 그림자는 이어진 물 전체(4방향)로 번진다.
static func flood(b: Board, cells: Array) -> Array:
	var seen := {}
	for c in cells:
		seen[c] = true
	var added := []
	var q := []
	for c in cells:
		if b.tile(c) == Board.WATER:
			q.append(c)
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for d in Board.DIRS4:
			var n: Vector2i = c + d
			if not seen.has(n) and b.tile(n) == Board.WATER:
				seen[n] = true
				added.append(n)
				q.append(n)
	return added


static func snap8(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2(0, -1)
	var ang := v.angle()
	var step := PI / 4.0
	var snapped_ang: float = round(ang / step) * step
	return Vector2(cos(snapped_ang), sin(snapped_ang)).normalized()
