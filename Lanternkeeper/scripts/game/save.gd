extends Node
## 영구 저장: 불씨, 해금, 시설, 도감, 업적, 통계, 설정, 진행 중인 탐험.
## 기기 안(user://)에만 저장하고 외부로 보내지 않는다.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const VERSION := 1

var meta: Dictionary = {}

signal unlocked(kind: String, id: String, title: String)


func _ready() -> void:
	load_meta()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"embers": 0,
		"chars": ["keeper"],
		"lanterns": ["candle"],
		"facilities": {},
		"npcs": [],
		"story": [],
		"story_seen": [],
		"codex": {"enemies": {}, "insc": {}, "relics": {}},
		"ach": [],
		"skins": ["amber"],
		"skin": "amber",
		"stats": {},
		"best": {"asc": {}, "daily": {}, "weekly": {}, "endless": 0},
		"puzzles": {},
		"settings": {"sfx": 0.8, "music": 0.55, "fast": false, "colorblind": false, "haptics": true,
			"left": false, "tutorial": false},
		"run": null,
		"asc_unlocked": 0,
		"last": {"char": "keeper", "lantern": "candle", "asc": 0},
	}


func load_meta() -> void:
	meta = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		_merge(meta, parsed)


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]


func save_meta() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패")
		return
	f.store_string(JSON.stringify(meta))
	f.close()
	var d := DirAccess.open("user://")
	if d != null:
		if d.file_exists("save.json"):
			d.remove("save.json")
		d.rename("save.tmp", "save.json")


func reset_all() -> void:
	var keep_settings: Dictionary = meta.get("settings", {}).duplicate()
	meta = defaults()
	meta["settings"] = keep_settings
	save_meta()


# ── 설정 ──
func setting(k: String, def = null):
	return meta["settings"].get(k, def)


func set_setting(k: String, v) -> void:
	meta["settings"][k] = v
	save_meta()


# ── 통계 ──
func stat(k: String) -> int:
	return int(meta["stats"].get(k, 0))


func stat_add(k: String, n: int = 1) -> void:
	if n == 0:
		return
	meta["stats"][k] = stat(k) + n


func stat_max(k: String, v: int) -> void:
	if v > stat(k):
		meta["stats"][k] = v


func sync_derived_stats() -> void:
	meta["stats"]["lanterns_owned"] = meta["lanterns"].size()
	meta["stats"]["chars_owned"] = meta["chars"].size()
	meta["stats"]["rescues"] = meta["npcs"].size()
	meta["stats"]["puzzles"] = meta["puzzles"].size()


## 새로 열린 업적·이야기·캐릭터를 확인하고 알린다.
func check_unlocks() -> Array:
	sync_derived_stats()
	var out := []
	for a in MetaData.ACHIEVEMENTS:
		if meta["ach"].has(a["id"]):
			continue
		if stat(a["stat"]) >= int(a["goal"]):
			meta["ach"].append(a["id"])
			out.append({"kind": "ach", "id": a["id"], "title": a["name"]})
			if a.has("skin") and not meta["skins"].has(a["skin"]):
				meta["skins"].append(a["skin"])
				out.append({"kind": "skin", "id": a["skin"], "title": GearData.SKINS[a["skin"]]["name"]})
	if meta["ach"].size() * 2 >= MetaData.ACHIEVEMENTS.size() and not meta["skins"].has("prism"):
		meta["skins"].append("prism")
		out.append({"kind": "skin", "id": "prism", "title": GearData.SKINS["prism"]["name"]})
	for s in MetaData.STORY:
		if meta["story"].has(s["id"]):
			continue
		if stat(s["stat"]) >= int(s["goal"]):
			meta["story"].append(s["id"])
			out.append({"kind": "story", "id": s["id"], "title": s["title"]})
	if not meta["chars"].has("priest") and stat("boss_mirrorlord") >= 1:
		meta["chars"].append("priest")
		out.append({"kind": "char", "id": "priest", "title": GearData.CHARACTERS["priest"]["name"]})
	for o in out:
		unlocked.emit(o["kind"], o["id"], o["title"])
	if not out.is_empty():
		save_meta()
	return out


# ── 도감 ──
func codex_add(group: String, id: String) -> void:
	var g: Dictionary = meta["codex"][group]
	if not g.has(id):
		g[id] = 1


# ── 불씨/해금 ──
func add_embers(n: int) -> void:
	meta["embers"] = int(meta["embers"]) + n
	stat_add("embers_total", n)


func spend_embers(n: int) -> bool:
	if int(meta["embers"]) < n:
		return false
	meta["embers"] = int(meta["embers"]) - n
	save_meta()
	return true


func facility_level(id: String) -> int:
	return int(meta["facilities"].get(id, 0))
