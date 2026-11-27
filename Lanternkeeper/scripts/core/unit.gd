class_name Unit
extends RefCounted
## 보드 위의 모든 존재(플레이어, 적, 지켜야 할 등대).

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var id: int = 0
var kind: String = ""
var team: int = TEAM_ENEMY
var pos: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1
var move: int = 1
var atk: int = 1
var flying: bool = false
var no_shadow: bool = false
var boss: bool = false
var front_guard: bool = false
var aura: bool = false
var cap: int = 0
var elite: String = ""
var facing: Vector2i = Vector2i(0, 1)
var st: Dictionary = {}   # frozen, burn, poison, shield, shield_max, regen
var ai: Dictionary = {}   # 행동 기억 (조준 방향, 쿨다운, 페이즈)
var dead: bool = false


func is_player() -> bool:
	return kind == "player"


func is_beacon() -> bool:
	return kind == "beacon"


func is_enemy() -> bool:
	return team == TEAM_ENEMY


func alive() -> bool:
	return not dead and hp > 0


func frozen() -> bool:
	return int(st.get("frozen", 0)) > 0


func burning() -> bool:
	return int(st.get("burn", 0)) > 0


func poisoned() -> bool:
	return int(st.get("poison", 0)) > 0


func casts_shadow() -> bool:
	return not no_shadow


func has_aura() -> bool:
	return aura and not frozen()


func clone() -> Unit:
	var u := Unit.new()
	u.id = id
	u.kind = kind
	u.team = team
	u.pos = pos
	u.hp = hp
	u.max_hp = max_hp
	u.move = move
	u.atk = atk
	u.flying = flying
	u.no_shadow = no_shadow
	u.boss = boss
	u.front_guard = front_guard
	u.aura = aura
	u.cap = cap
	u.elite = elite
	u.facing = facing
	u.st = st.duplicate(true)
	u.ai = ai.duplicate(true)
	u.dead = dead
	return u


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "team": team, "x": pos.x, "y": pos.y, "hp": hp, "max_hp": max_hp,
		"move": move, "atk": atk, "flying": flying, "no_shadow": no_shadow, "boss": boss,
		"front_guard": front_guard, "aura": aura, "cap": cap, "elite": elite,
		"fx": facing.x, "fy": facing.y, "st": st, "ai": _ai_to_json()}


func _ai_to_json() -> Dictionary:
	var d := {}
	for k in ai.keys():
		var v = ai[k]
		if v is Vector2i:
			d[k] = {"__v": [v.x, v.y]}
		elif v is Array:
			var arr := []
			for e in v:
				arr.append([e.x, e.y] if e is Vector2i else e)
			d[k] = {"__a": arr}
		else:
			d[k] = v
	return d


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = int(d["id"])
	u.kind = d["kind"]
	u.team = int(d["team"])
	u.pos = Vector2i(int(d["x"]), int(d["y"]))
	u.hp = int(d["hp"])
	u.max_hp = int(d["max_hp"])
	u.move = int(d["move"])
	u.atk = int(d["atk"])
	u.flying = bool(d["flying"])
	u.no_shadow = bool(d["no_shadow"])
	u.boss = bool(d["boss"])
	u.front_guard = bool(d["front_guard"])
	u.aura = bool(d["aura"])
	u.cap = int(d["cap"])
	u.elite = d["elite"]
	u.facing = Vector2i(int(d["fx"]), int(d["fy"]))
	for k in d["st"].keys():
		u.st[k] = int(d["st"][k])
	for k in d["ai"].keys():
		var v = d["ai"][k]
		if v is Dictionary and v.has("__v"):
			u.ai[k] = Vector2i(int(v["__v"][0]), int(v["__v"][1]))
		elif v is Dictionary and v.has("__a"):
			var arr := []
			for e in v["__a"]:
				arr.append(Vector2i(int(e[0]), int(e[1])) if e is Array else e)
			u.ai[k] = arr
		elif v is float:
			u.ai[k] = int(v)
		else:
			u.ai[k] = v
	return u
