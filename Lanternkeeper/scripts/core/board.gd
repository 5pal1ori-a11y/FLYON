class_name Board
extends RefCounted
## 한 방의 전투 상태. 순수 데이터라 복제해서 미리보기 시뮬레이션에 쓴다.

enum { FLOOR, WALL, PILLAR, CRATE, MIRROR, GLASS, WATER, BRAZIER, BRAZIER_OUT, WEB, DARK, CANDLE, CANDLE_LIT, EXIT }

const TILE_NAMES := {
	FLOOR: "바닥", WALL: "벽", PILLAR: "돌기둥", CRATE: "나무 상자", MIRROR: "거울", GLASS: "유리 기둥",
	WATER: "물", BRAZIER: "화로", BRAZIER_OUT: "꺼진 화로", WEB: "거미줄", DARK: "어둠",
	CANDLE: "꺼진 초", CANDLE_LIT: "켜진 초", EXIT: "출구",
}
const TILE_DESC := {
	PILLAR: "그림자를 드리운다. 그 그림자도 적을 벤다.",
	CRATE: "그림자를 드리운다. 밀어서 옮길 수 있다.",
	MIRROR: "등불 빛 안에 들면 빛을 반사해 두 번째 광원이 된다.",
	GLASS: "그림자가 없다. 그림자가 지나가면 깨지며 주변 적에게 파편 피해.",
	WATER: "그림자가 닿으면 이어진 물 전체로 번진다.",
	BRAZIER: "주변 한 칸에는 그림자가 들지 않는다. 부딪쳐서 끌 수 있다.",
	WEB: "들어서면 이동이 멈춘다.",
	DARK: "여기서 턴을 마치면 피해 1.",
	CANDLE: "등불 빛 안에 들면 켜진다.",
	EXIT: "여기에 도달하면 탈출한다.",
}

const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var w: int = 7
var h: int = 9
var tiles: PackedInt32Array = PackedInt32Array()
var units: Array = []
var next_id: int = 1
var turn: int = 1
var biome: String = "fog"
var objective: Dictionary = {"type": "annihilate"}
var radius_penalty: float = 0.0
var last_player_shadow: Array = []
var lingering: Array = []
var last_lit: Dictionary = {}
var last_cells: Array = []
var casts: int = 0
var ward_left: int = 0
var revive_used: bool = false
var oil_gained: int = 0
var spawn_rng_state: int = 1234
var flags: Dictionary = {}


func _init(width: int = 7, height: int = 9) -> void:
	w = width
	h = height
	tiles.resize(w * h)
	tiles.fill(FLOOR)


# ── 타일 ──
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func tile(c: Vector2i) -> int:
	if not in_bounds(c):
		return WALL
	return tiles[c.y * w + c.x]


func set_tile(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		tiles[c.y * w + c.x] = t


func all_cells() -> Array:
	var out := []
	for y in h:
		for x in w:
			out.append(Vector2i(x, y))
	return out


func cells_of(t: int) -> Array:
	var out := []
	for y in h:
		for x in w:
			if tiles[y * w + x] == t:
				out.append(Vector2i(x, y))
	return out


static func is_ground(t: int) -> bool:
	return t == FLOOR or t == WATER or t == WEB or t == DARK or t == EXIT


static func is_obstacle_caster(t: int) -> bool:
	return t == PILLAR or t == CRATE


## 걸어서 설 수 있는가 (유닛 점유 무시)
func walkable(c: Vector2i, flying: bool = false) -> bool:
	var t := tile(c)
	if is_ground(t):
		return true
	if flying:
		return t == PILLAR or t == CRATE or t == GLASS or t == CANDLE or t == CANDLE_LIT or t == BRAZIER_OUT
	return false


func is_free(c: Vector2i, flying: bool = false) -> bool:
	return walkable(c, flying) and unit_at(c) == null


# ── 유닛 ──
func unit_at(c: Vector2i) -> Unit:
	for u in units:
		if not u.dead and u.pos == c:
			return u
	return null


func unit_by_id(uid: int) -> Unit:
	for u in units:
		if u.id == uid:
			return u
	return null


func player() -> Unit:
	for u in units:
		if u.kind == "player":
			return u
	return null


func beacon() -> Unit:
	for u in units:
		if u.kind == "beacon" and not u.dead:
			return u
	return null


func enemies() -> Array:
	var out := []
	for u in units:
		if u.team == Unit.TEAM_ENEMY and not u.dead:
			out.append(u)
	return out


func boss_unit() -> Unit:
	for u in units:
		if u.boss and not u.dead:
			return u
	return null


func add_unit(u: Unit) -> Unit:
	u.id = next_id
	next_id += 1
	units.append(u)
	return u


func spawn_player(c: Vector2i, hp: int, max_hp: int, move: int) -> Unit:
	var u := Unit.new()
	u.kind = "player"
	u.team = Unit.TEAM_PLAYER
	u.pos = c
	u.hp = hp
	u.max_hp = max_hp
	u.move = move
	u.atk = 0
	u.facing = Vector2i(0, -1)
	return add_unit(u)


func spawn_beacon(c: Vector2i, hp: int = 3) -> Unit:
	var u := Unit.new()
	u.kind = "beacon"
	u.team = Unit.TEAM_PLAYER
	u.pos = c
	u.hp = hp
	u.max_hp = hp
	u.move = 0
	u.atk = 0
	return add_unit(u)


func spawn_enemy(kind: String, c: Vector2i, elite: String = "", hp_bonus: int = 0, atk_bonus: int = 0) -> Unit:
	var d: Dictionary = EnemyData.get_def(kind)
	var u := Unit.new()
	u.kind = kind
	u.team = Unit.TEAM_ENEMY
	u.pos = c
	u.max_hp = max(1, int(d["hp"]) + hp_bonus)
	u.move = int(d["move"])
	u.atk = int(d["atk"]) + (atk_bonus if int(d["atk"]) > 0 else 0)
	u.flying = d.get("flying", false)
	u.no_shadow = d.get("no_shadow", false)
	u.boss = d.get("boss", false)
	u.front_guard = d.get("front_guard", false)
	u.aura = d.get("aura", false)
	u.cap = int(d.get("cap", 0))
	u.facing = Vector2i(0, 1)
	if elite != "":
		var e: Dictionary = EnemyData.ELITES[elite]
		u.elite = elite
		u.move += int(e.get("move", 0))
		u.max_hp += int(e.get("hp", 0))
		if e.has("shield"):
			u.st["shield"] = int(e["shield"])
			u.st["shield_max"] = int(e["shield"])
		if e.has("regen"):
			u.st["regen"] = int(e["regen"])
	u.hp = u.max_hp
	if d["ai"] == "summoner":
		u.ai["cd"] = 2
	elif d["ai"] == "creeper":
		u.ai["cd"] = 1
	elif u.boss:
		u.ai["cd"] = 1
		u.ai["t"] = 0
	return add_unit(u)


func cleanup_dead() -> void:
	var keep := []
	for u in units:
		if not u.dead or u.kind == "player":
			keep.append(u)
	units = keep


# ── 기하 ──
static func cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## 결정적 의사난수 (소환 위치 등). 미리보기와 실제 결과가 같도록 보드 상태에 저장된다.
func rand_int(n: int) -> int:
	spawn_rng_state = int((spawn_rng_state * 1103515245 + 12345) % 2147483648)
	if n <= 0:
		return 0
	return spawn_rng_state % n


## BFS 거리 맵 (유닛이 있는 칸은 통과 불가, 단 goal_ok 칸은 도착 가능)
func distance_map(from: Vector2i, flying: bool, ignore_ids: Array = []) -> Dictionary:
	var dist := {from: 0}
	var q := [from]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if dist.has(n) or not walkable(n, flying):
				continue
			var occ := unit_at(n)
			if occ != null and not ignore_ids.has(occ.id):
				continue
			dist[n] = dist[c] + 1
			q.append(n)
	return dist


## from에서 target 옆 칸으로 가는 최단 경로 (from 제외). 없으면 거리를 줄이는 한 걸음.
func path_toward(from: Vector2i, target: Vector2i, flying: bool) -> Array:
	var prev := {from: from}
	var q := [from]
	var qi := 0
	var goal := Vector2i(-99, -99)
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		if manhattan(c, target) == 1:
			goal = c
			break
		for d in DIRS4:
			var n: Vector2i = c + d
			if prev.has(n) or not walkable(n, flying) or unit_at(n) != null:
				continue
			prev[n] = c
			q.append(n)
	if goal.x == -99:
		var best := from
		var best_d := manhattan(from, target)
		for d in DIRS4:
			var n: Vector2i = from + d
			if is_free(n, flying) and manhattan(n, target) < best_d:
				best = n
				best_d = manhattan(n, target)
		return [] if best == from else [best]
	var path := []
	var cur := goal
	while cur != from:
		path.push_front(cur)
		cur = prev[cur]
	return path


func reachable_ground(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q := [from]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if not seen.has(n) and walkable(n):
				seen[n] = true
				q.append(n)
	return seen


func clone() -> Board:
	var b := Board.new(w, h)
	b.tiles = tiles.duplicate()
	for u in units:
		b.units.append(u.clone())
	b.next_id = next_id
	b.turn = turn
	b.biome = biome
	b.objective = objective.duplicate(true)
	b.radius_penalty = radius_penalty
	b.last_player_shadow = last_player_shadow.duplicate()
	b.lingering = lingering.duplicate()
	b.last_lit = last_lit.duplicate()
	b.last_cells = last_cells.duplicate()
	b.casts = casts
	b.ward_left = ward_left
	b.revive_used = revive_used
	b.oil_gained = oil_gained
	b.spawn_rng_state = spawn_rng_state
	b.flags = flags.duplicate(true)
	return b


func to_dict() -> Dictionary:
	var us := []
	for u in units:
		us.append(u.to_dict())
	return {"w": w, "h": h, "tiles": Array(tiles), "units": us, "next_id": next_id, "turn": turn,
		"biome": biome, "objective": objective, "radius_penalty": radius_penalty,
		"spawn_rng_state": spawn_rng_state, "flags": flags}


static func from_dict(d: Dictionary) -> Board:
	var b := Board.new(int(d["w"]), int(d["h"]))
	var t := PackedInt32Array()
	for v in d["tiles"]:
		t.append(int(v))
	b.tiles = t
	for ud in d["units"]:
		b.units.append(Unit.from_dict(ud))
	b.next_id = int(d["next_id"])
	b.turn = int(d["turn"])
	b.biome = d["biome"]
	b.objective = d["objective"]
	for k in ["turns", "lit", "total"]:
		if b.objective.has(k):
			b.objective[k] = int(b.objective[k])
	if b.objective.has("exit"):
		var e = b.objective["exit"]
		b.objective["exit"] = Vector2i(int(e[0]), int(e[1])) if e is Array else e
	b.radius_penalty = float(d["radius_penalty"])
	b.spawn_rng_state = int(d["spawn_rng_state"])
	b.flags = d.get("flags", {})
	return b
