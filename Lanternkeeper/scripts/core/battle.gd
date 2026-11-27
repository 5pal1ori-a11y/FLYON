class_name Battle
extends RefCounted
## 한 방의 턴 진행: 이동 → 등불 놓기(미리보기) → 점화 → 적 턴. 되돌리기와 목표 판정 포함.

var b: Board
var mods: Dictionary
var lantern_id: String
var lantern: Dictionary
var ctx: Dictionary
var phase: String = "move"    # move | aim | over
var undo_left: int = 3
var history: Array = []
var result: String = ""       # "" | win | lose | fail
var puzzle: bool = false
var stats: Dictionary = {}
var start_hp: int = 0


func _init(board: Board, mods_: Dictionary, lantern_id_: String, undo_charges: int, is_puzzle: bool = false) -> void:
	b = board
	mods = mods_
	lantern_id = lantern_id_
	lantern = GearData.LANTERNS[lantern_id]
	ctx = {"mods": mods, "lantern": lantern}
	undo_left = undo_charges
	puzzle = is_puzzle
	stats = {"kills": 0, "casts": 0, "damage_taken": 0, "max_kill_cast": 0, "freezes": 0, "chains": 0,
		"glass": 0, "floods": 0, "burn_kills": 0, "poison_kills": 0, "sets": 0}
	start_hp = b.player().hp
	_room_start_effects()
	_push()


func _room_start_effects() -> void:
	if puzzle:
		return
	var sp := int(mods.get("start_poison", 0))
	var sf := int(mods.get("start_freeze", 0))
	for e in b.enemies():
		if sp > 0:
			e.st["poison"] = int(e.st.get("poison", 0)) + sp
		if sf > 0 and not e.boss:
			e.st["frozen"] = max(int(e.st.get("frozen", 0)), sf)
	if int(mods.get("hp_loss_room", 0)) > 0:
		var p := b.player()
		p.hp = max(1, p.hp - int(mods["hp_loss_room"]))


func _push() -> void:
	history.append({"board": b.clone(), "stats": stats.duplicate()})
	if history.size() > 12:
		history.pop_front()


func player() -> Unit:
	return b.player()


func move_range() -> int:
	return max(1, player().move)


func throw_range() -> int:
	return max(1, 3 + int(mods.get("range", 0)))


## 이동 가능한 칸: cell -> {type, path}
func reachable() -> Dictionary:
	var out := {}
	if phase != "move" or result != "":
		return out
	var p := player()
	var maxd := move_range()
	var dist := {p.pos: 0}
	var prev := {}
	var q := [p.pos]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		if c != p.pos and b.tile(c) == Board.WEB:
			continue
		if dist[c] >= maxd:
			continue
		for d in Board.DIRS4:
			var n: Vector2i = c + d
			if dist.has(n) or not b.is_free(n):
				continue
			dist[n] = dist[c] + 1
			prev[n] = c
			q.append(n)
	for c in dist.keys():
		if c == p.pos:
			continue
		var path := []
		var cur: Vector2i = c
		while cur != p.pos:
			path.push_front(cur)
			cur = prev[cur]
		out[c] = {"type": "walk", "path": path}
	# 상자 밀기, 화로 끄기
	for d in Board.DIRS4:
		var n: Vector2i = p.pos + d
		if b.tile(n) == Board.CRATE and b.unit_at(n) == null:
			var beyond: Vector2i = n + d
			if b.is_free(beyond) and b.tile(beyond) != Board.EXIT:
				out[n] = {"type": "push", "path": [n], "dir": d}
		elif b.tile(n) == Board.BRAZIER:
			out[n] = {"type": "douse", "path": []}
	# 그림자 걸음
	if int(mods.get("shadow_step", 0)) > 0:
		for c in b.last_player_shadow:
			if not out.has(c) and b.is_free(c) and c != p.pos:
				out[c] = {"type": "step", "path": [c]}
	return out


func move_to(cell: Vector2i) -> Dictionary:
	var r := reachable()
	if not r.has(cell):
		return {}
	var info: Dictionary = r[cell]
	var p := player()
	var ev := {"type": info["type"], "from": p.pos, "path": info["path"], "cell": cell}
	match info["type"]:
		"walk", "step":
			p.pos = cell
		"push":
			var d: Vector2i = info["dir"]
			b.set_tile(cell, Board.FLOOR)
			b.set_tile(cell + d, Board.CRATE)
			p.pos = cell
			ev["crate_to"] = cell + d
		"douse":
			b.set_tile(cell, Board.BRAZIER_OUT)
	if info["type"] != "douse" and ev["path"].size() > 0:
		var last: Vector2i = ev["path"][-1]
		var before: Vector2i = ev["path"][-2] if ev["path"].size() > 1 else ev["from"]
		var fd := last - before
		if fd != Vector2i.ZERO:
			p.facing = Vector2i(sign(fd.x), sign(fd.y))
	phase = "aim"
	_check("move")
	return ev


func skip_move() -> void:
	if phase == "move":
		phase = "aim"


## 등불을 놓을 수 있는 칸
func lantern_cells(exclude: Array = []) -> Array:
	var out := []
	if result != "":
		return out
	var p := player()
	var r := throw_range()
	for y in range(p.pos.y - r, p.pos.y + r + 1):
		for x in range(p.pos.x - r, p.pos.x + r + 1):
			var c := Vector2i(x, y)
			if c == p.pos or exclude.has(c) or not b.in_bounds(c):
				continue
			if not Board.is_ground(b.tile(c)) or b.unit_at(c) != null:
				continue
			out.append(c)
	return out


func needs_cells() -> int:
	return int(lantern["count"])


## 미리보기: 복제 보드에서 점화 + 적 턴을 시뮬레이션
func preview(cells: Array) -> Dictionary:
	var cb := b.clone()
	var cast := Combat.resolve(cb, cells, ctx)
	var out := {"cast": cast, "board": cb}
	var p := cb.player()
	var enemies_left := cb.enemies().size()
	out["kills"] = 0
	for k in cast["kills"]:
		if k["team"] == Unit.TEAM_ENEMY:
			out["kills"] += 1
	if puzzle:
		out["clear"] = enemies_left == 0
		return out
	var win_now := _would_win_after_cast(cb)
	out["win"] = win_now
	if not win_now and not p.dead:
		var hp_before := p.hp
		var bc := cb.beacon()
		var bhp := bc.hp if bc != null else 0
		var en := EnemyAI.run(cb, ctx)
		out["enemy"] = en
		out["player_dmg"] = hp_before - max(0, p.hp)
		out["beacon_dmg"] = (bhp - (bc.hp if bc != null and not bc.dead else 0)) if bc != null else 0
		out["dead"] = p.dead
	else:
		out["player_dmg"] = 0
		out["dead"] = p.dead
	return out


func _would_win_after_cast(cb: Board) -> bool:
	var t: String = cb.objective.get("type", "annihilate")
	if t == "annihilate" or t == "protect":
		return cb.enemies().is_empty()
	if t == "boss":
		return cb.boss_unit() == null
	if t == "candles":
		return int(cb.objective.get("lit", 0)) >= int(cb.objective.get("total", 0))
	return false


func cast(cells: Array) -> Dictionary:
	var out := {"cast": Combat.new_result(), "enemy": null, "echo": null}
	if result != "":
		return out
	var p := player()
	var hp0 := p.hp
	if not cells.is_empty():
		out["cast"] = Combat.resolve(b, cells, ctx)
		_tally(out["cast"])
		stats["casts"] += 1
	if puzzle:
		result = "win" if b.enemies().is_empty() else "fail"
		phase = "over"
		out["result"] = result
		return out
	_check("cast")
	if result == "":
		out["enemy"] = EnemyAI.run(b, ctx)
		_tally(out["enemy"])
		if int(mods.get("echo", 0)) > 0 and not p.dead and not cells.is_empty():
			var ectx := ctx.duplicate()
			ectx["echo"] = true
			out["echo"] = Combat.resolve(b, cells, ectx)
			_tally(out["echo"])
		_check("enemy")
	stats["damage_taken"] += max(0, hp0 - p.hp)
	if result == "":
		phase = "move"
		_push()
	else:
		phase = "over"
	out["result"] = result
	return out


func _tally(res: Dictionary) -> void:
	var k := 0
	for kd in res["kills"]:
		if kd["team"] != Unit.TEAM_ENEMY:
			continue
		k += 1
		if kd.get("burning", false):
			stats["burn_kills"] += 1
		if kd.get("poisoned", false):
			stats["poison_kills"] += 1
	stats["kills"] += k
	stats["max_kill_cast"] = max(int(stats["max_kill_cast"]), k)
	stats["freezes"] += res["frozen"].size()
	stats["chains"] += res["chains"].size()
	stats["glass"] += res["shattered"].size()
	for f in res["fx"]:
		if f["type"] == "flood":
			stats["floods"] += 1


func can_undo() -> bool:
	if result != "" or puzzle:
		return false
	if phase == "aim":
		return true
	return undo_left > 0 and history.size() >= 2


## 되돌리기: 이번 턴에 이동했다면 이동만 무르고(무료), 아니면 지난 턴 시작으로(1회 소모)
func undo() -> bool:
	if not can_undo():
		return false
	if phase == "aim":
		var snap: Dictionary = history[-1]
		b = snap["board"].clone()
		stats = snap["stats"].duplicate()
		phase = "move"
		return true
	history.pop_back()
	var snap2: Dictionary = history[-1]
	b = snap2["board"].clone()
	stats = snap2["stats"].duplicate()
	phase = "move"
	undo_left -= 1
	return true


func _check(after: String) -> void:
	var p := player()
	if p.dead or p.hp <= 0:
		result = "lose"
		return
	var obj: Dictionary = b.objective
	var t: String = obj.get("type", "annihilate")
	match t:
		"annihilate":
			if b.enemies().is_empty():
				result = "win"
		"boss":
			if b.boss_unit() == null:
				result = "win"
		"protect":
			var bc := b.beacon()
			if bc == null:
				result = "fail"
			elif b.enemies().is_empty():
				result = "win"
		"survive":
			if b.enemies().is_empty() and after != "move":
				result = "win"
			elif after == "enemy" and b.turn > int(obj["turns"]):
				result = "win"
		"candles":
			if int(obj.get("lit", 0)) >= int(obj.get("total", 0)):
				result = "win"
			elif after == "enemy" and b.turn > int(obj["turns"]):
				result = "fail"
		"escape":
			if p.pos == obj["exit"]:
				result = "win"
			elif after == "enemy" and b.turn > int(obj["turns"]):
				result = "fail"


func turns_left() -> int:
	var obj: Dictionary = b.objective
	if obj.has("turns"):
		return int(obj["turns"]) - b.turn + 1
	return -1
