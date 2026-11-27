class_name RunState
extends RefCounted
## 한 번의 탐험(런) 상태. 방과 방 사이에서 저장된다.

const WEEKLY_MODS := [
	{"name": "강철 그림자", "desc": "그림자 피해 +1, 적 체력 +2", "fx": {"dmg": 1, "enemy_hp": 2}},
	{"name": "넓은 빛", "desc": "등불 반경 +1, 그림자 길이 -1", "fx": {"radius": 1.0, "length": -1}},
	{"name": "번개 폭풍", "desc": "연쇄가 모든 적에게 번진다, 최대 체력 -2", "fx": {"chain": 1, "chain_all": 1, "max_hp": -2}},
	{"name": "불타는 밤", "desc": "그림자에 맞은 적에게 화상 2, 적 체력 +1", "fx": {"burn_on_hit": 2, "enemy_hp": 1}},
	{"name": "영원한 겨울", "desc": "겹친 그림자는 적을 굳힌다, 굳는 시간 +1, 적 체력 +1", "fx": {"freeze_on_multi": 1, "freeze_duration": 1, "enemy_hp": 1}},
	{"name": "황금의 탑", "desc": "얻는 기름 +100%, 상점 가격 +50%", "fx": {"oil_gain": 100, "shop_price": 50}},
	{"name": "독의 계절", "desc": "독 2, 독이 줄지 않음, 최대 체력 -3", "fx": {"poison_on_hit": 2, "poison_no_decay": 1, "max_hp": -3}},
	{"name": "거울 미궁", "desc": "등불의 거울상, 방마다 거울 +2, 등불 반경 -0.5", "fx": {"mirror_copy": 1, "extra_mirrors": 2, "radius": -0.5}},
	{"name": "긴 밤", "desc": "그림자가 남는다, 그림자 길이 +1, 적 체력 +1", "fx": {"linger": 1, "length": 1, "enemy_hp": 1}},
	{"name": "유리 폭풍", "desc": "방마다 유리 +3, 파편 피해 +2", "fx": {"extra_glass": 3, "glass_dmg": 2}},
]

var mode: String = "normal"       # normal | daily | weekly | endless
var seed: int = 1
var character: String = "keeper"
var lantern: String = "candle"
var asc: int = 0
var hp: int = 7
var oil: int = 0
var inscriptions: Array = []
var relics: Array = []
var floor: int = 0
var floors_total: int = 4
var map: Dictionary = {}
var cur_node: int = -1
var visited: Array = []
var rerolls: int = 0
var undo: int = 3
var weekly: Array = []
var stats: Dictionary = {}
var room_count: int = 0
var turns: int = 0
var date_key: String = ""
var extra_max_hp: int = 0
var pending_node: int = -1
var seen_events: Array = []
var _mods_cache: Dictionary = {}
var _mods_dirty: bool = true


## 오두막 시설 레벨 (게임이 시작할 때 Save에서 채워 넣는다. 테스트에서는 비어 있다)
static var fac: Dictionary = {}


func facilities() -> Dictionary:
	return fac


func mods() -> Dictionary:
	if _mods_dirty:
		_mods_cache = Mods.build(character, inscriptions, relics, asc, facilities())
		for w in weekly:
			Mods.add_fx(_mods_cache, WEEKLY_MODS[int(w)]["fx"])
		_mods_dirty = false
	return _mods_cache


func dirty() -> void:
	_mods_dirty = true


func max_hp() -> int:
	return max(2, Mods.max_hp_for(character, mods()) + extra_max_hp)


func move() -> int:
	return Mods.move_for(character, mods())


func biome() -> String:
	if mode == "daily":
		return BiomeData.ORDER[(seed / 7) % 4]
	return BiomeData.for_floor(floor)


func level() -> int:
	if mode == "endless":
		return max(0, floor - 3)
	return 0


func tier_floor() -> int:
	if mode == "daily":
		return 1
	return min(floor, 3)


func node_seed(node_id: int) -> int:
	return int(hash(str(seed) + ":" + str(floor) + ":" + str(node_id))) & 0x7fffffff


func new_floor_map() -> void:
	var short := mode == "daily"
	map = MapGen.generate(node_seed(-1), int(mods().get("elite_more", 0)) > 0, short)
	cur_node = -1
	visited = []
	rerolls = int(facilities().get("seer", 0))


func available_nodes() -> Array:
	if cur_node < 0:
		return MapGen.starts(map)
	var n := MapGen.node(map, cur_node)
	var out := []
	for l in n.get("links", []):
		out.append(int(l))
	return out


func add_oil(n: int) -> int:
	if n > 0:
		n = int(round(n * (1.0 + int(mods().get("oil_gain", 0)) / 100.0)))
	oil = max(0, oil + n)
	stats["oil_max"] = max(int(stats.get("oil_max", 0)), oil)
	return n


func price(base: int) -> int:
	var pct := 100 + int(mods().get("shop_price", 0)) - int(mods().get("shop_discount", 0))
	return max(1, int(round(base * max(30, pct) / 100.0)))


func heal(n: int) -> int:
	var before := hp
	hp = clampi(hp + n, 1, max_hp())
	return hp - before


func clamp_hp() -> void:
	hp = clampi(hp, 0, max_hp())


func add_inscription(id: String) -> Array:
	var before := Mods.active_sets(inscriptions).size()
	inscriptions.append(id)
	dirty()
	hp = min(hp, max_hp())
	var after := Mods.active_sets(inscriptions)
	var new_sets := []
	if after.size() > before:
		new_sets = after.slice(before)
	return new_sets


func add_relic(id: String) -> void:
	var old_max := max_hp()
	relics.append(id)
	dirty()
	var nm := max_hp()
	if nm > old_max:
		hp += nm - old_max
	hp = clampi(hp, 1, nm)


func remove_relic(id: String) -> void:
	relics.erase(id)
	dirty()
	clamp_hp()


func to_dict() -> Dictionary:
	return {"mode": mode, "seed": seed, "character": character, "lantern": lantern, "asc": asc, "hp": hp,
		"oil": oil, "inscriptions": inscriptions, "relics": relics, "floor": floor, "floors_total": floors_total,
		"map": map, "cur_node": cur_node, "visited": visited, "rerolls": rerolls, "undo": undo,
		"weekly": weekly, "stats": stats, "room_count": room_count, "turns": turns, "date_key": date_key,
		"extra_max_hp": extra_max_hp, "pending_node": pending_node, "seen_events": seen_events}


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.mode = d.get("mode", "normal")
	r.seed = int(d["seed"])
	r.character = d["character"]
	r.lantern = d["lantern"]
	r.asc = int(d["asc"])
	r.hp = int(d["hp"])
	r.oil = int(d["oil"])
	r.inscriptions = Array(d["inscriptions"])
	r.relics = Array(d["relics"])
	r.floor = int(d["floor"])
	r.floors_total = int(d.get("floors_total", 4))
	r.map = _norm_map(d["map"])
	r.cur_node = int(d["cur_node"])
	r.visited = []
	for v in d["visited"]:
		r.visited.append(int(v))
	r.rerolls = int(d["rerolls"])
	r.undo = int(d["undo"])
	r.weekly = []
	for w in d.get("weekly", []):
		r.weekly.append(int(w))
	r.stats = d.get("stats", {})
	r.room_count = int(d.get("room_count", 0))
	r.turns = int(d.get("turns", 0))
	r.date_key = d.get("date_key", "")
	r.extra_max_hp = int(d.get("extra_max_hp", 0))
	r.pending_node = int(d.get("pending_node", -1))
	r.seen_events = Array(d.get("seen_events", []))
	return r


static func _norm_map(m: Dictionary) -> Dictionary:
	var out := {"rows": int(m.get("rows", 7)), "boss": int(m.get("boss", 0)), "nodes": []}
	for n in m.get("nodes", []):
		var links := []
		for l in n["links"]:
			links.append(int(l))
		out["nodes"].append({"id": int(n["id"]), "row": int(n["row"]), "x": float(n["x"]), "type": n["type"], "links": links})
	return out
