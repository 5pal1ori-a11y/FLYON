extends Node
## 게임 진행 관리 (자동 로드: Game): 화면 전환, 탐험 흐름, 보상, 불씨 정산.

signal screen_requested(name: String, params: Dictionary)
signal toast_requested(text: String, kind: String)

var run: RunState = null
var battle: Battle = null
var room: Dictionary = {}
var safe_top: int = 0
var safe_bottom: int = 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	RunState.fac = Save.meta["facilities"]
	Save.unlocked.connect(_on_unlocked)


func _on_unlocked(kind: String, _id: String, title: String) -> void:
	var pre := {"ach": "업적 달성", "story": "이야기 조각", "skin": "등불 꾸미기", "char": "새 동료"}
	toast_requested.emit("%s · %s" % [pre.get(kind, ""), title], kind)


func goto(screen: String, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)


func toast(text: String, kind: String = "info") -> void:
	toast_requested.emit(text, kind)


func has_saved_run() -> bool:
	return Save.meta.get("run") is Dictionary


# ───────────────────────── 탐험 시작/저장 ─────────────────────────
static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func week_index() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0 + 3) / 7


func new_run(mode: String, character: String, lantern: String, asc: int) -> void:
	RunState.fac = Save.meta["facilities"]
	var r := RunState.new()
	r.mode = mode
	r.character = character
	r.lantern = lantern
	r.asc = asc
	match mode:
		"daily":
			r.date_key = today_key()
			r.seed = int(hash("daily" + r.date_key)) & 0x7fffffff
			r.character = "keeper"
			var wd: int = Time.get_date_dict_from_system()["weekday"]
			r.lantern = GearData.LANTERN_ORDER[wd % GearData.LANTERN_ORDER.size()]
			r.asc = 3
			r.floors_total = 1
		"weekly":
			var wk := week_index()
			r.date_key = str(wk)
			r.seed = int(hash("weekly" + str(wk))) & 0x7fffffff
			var wr := RandomNumberGenerator.new()
			wr.seed = r.seed
			var a := wr.randi_range(0, RunState.WEEKLY_MODS.size() - 1)
			var b := (a + 1 + wr.randi_range(0, RunState.WEEKLY_MODS.size() - 2)) % RunState.WEEKLY_MODS.size()
			r.weekly = [a, b]
			r.floors_total = 2
			r.asc = 0
		"endless":
			r.seed = rng.randi() & 0x7fffffff
			r.floors_total = 9999
		_:
			r.seed = rng.randi() & 0x7fffffff
			r.floors_total = 4
	var m := r.mods()
	r.oil = max(0, 30 + 15 * Save.facility_level("oilstore") + int(m.get("start_oil", 0)))
	var forge := Save.facility_level("forge")
	if forge >= 1:
		r.add_inscription(roll_inscriptions(1, 0, [], 0)[0])
	if forge >= 2:
		r.add_inscription(roll_inscriptions(1, 0, r.inscriptions, 1)[0])
	if int(m.get("start_curse", 0)) > 0:
		var cs := UpgradeData.curse_ids()
		r.add_relic(cs[rng.randi_range(0, cs.size() - 1)])
	r.undo = max(0, 3 + int(r.mods().get("undo", 0)))
	r.hp = r.max_hp()
	r.new_floor_map()
	run = r
	Save.stat_add("runs")
	Save.meta["last"] = {"char": character, "lantern": lantern, "asc": asc}
	save_run()
	Save.check_unlocks()
	goto("map", {"new_floor": true})


func save_run() -> void:
	Save.meta["run"] = run.to_dict() if run != null else null
	Save.save_meta()


func load_saved_run() -> void:
	RunState.fac = Save.meta["facilities"]
	run = RunState.from_dict(Save.meta["run"])


func continue_run() -> void:
	if not has_saved_run():
		return
	load_saved_run()
	if run.pending_node >= 0:
		var n := MapGen.node(run.map, run.pending_node)
		if not n.is_empty() and n["type"] in ["battle", "elite", "boss"]:
			_start_battle(n)
			return
	goto("map")


# ───────────────────────── 지도 ─────────────────────────
func enter_node(id: int) -> void:
	var n := MapGen.node(run.map, id)
	if n.is_empty():
		return
	run.cur_node = id
	run.visited.append(id)
	run.pending_node = id
	save_run()
	match n["type"]:
		"battle", "elite", "boss":
			_start_battle(n)
		"event":
			goto("event", {"id": pick_event()})
		"shop":
			goto("shop", {"node": id})
		"rest":
			goto("rest")
		"treasure":
			goto("reward", {"mode": "treasure"})


func _start_battle(n: Dictionary, force_kind: String = "") -> void:
	var kind: String = force_kind if force_kind != "" else n["type"]
	var m := run.mods()
	var params := {"biome": run.biome(), "kind": kind, "floor": run.tier_floor(), "row": int(n.get("row", 3)),
		"seed": run.node_seed(int(n.get("id", 0)) + (1000 if force_kind != "" else 0)), "mods": m,
		"player_hp": run.hp, "player_max": run.max_hp(), "player_move": run.move(), "level": run.level()}
	var board := RoomGen.generate(params)
	if board.biome == "fog" and (int(n.get("row", 0)) > 0 or run.floor > 0):
		board.flags["fog"] = true
	battle = Battle.new(board, m, run.lantern, run.undo)
	room = {"node": int(n.get("id", -1)), "kind": kind, "row": int(n.get("row", 0)), "puzzle": -1,
		"boss": board.boss_unit().kind if board.boss_unit() != null else ""}
	for e in board.enemies():
		Save.codex_add("enemies", e.kind)
	goto("battle")


func pick_event() -> String:
	var pool := []
	var rescue := []
	for k in EventData.EVENTS.keys():
		var ev: Dictionary = EventData.EVENTS[k]
		if ev.has("rescue"):
			if not Save.meta["npcs"].has(ev["rescue"]):
				rescue.append(k)
		elif not run.seen_events.has(k):
			pool.append(k)
	if not rescue.is_empty() and rng.randf() < 0.3:
		return rescue[rng.randi_range(0, rescue.size() - 1)]
	if pool.is_empty():
		pool = ["e_campfire", "e_well"]
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	run.seen_events.append(pick)
	return pick


# ───────────────────────── 전투 종료 ─────────────────────────
func finish_battle() -> void:
	var bt := battle
	if room.get("puzzle", -1) >= 0:
		return
	var st := bt.stats
	for k in ["kills", "casts", "freezes", "chains", "glass", "floods", "burn_kills", "poison_kills"]:
		Save.stat_add(k, int(st.get(k, 0)))
		run.stats[k] = int(run.stats.get(k, 0)) + int(st.get(k, 0))
	Save.stat_max("max_kill_cast", int(st.get("max_kill_cast", 0)))
	run.undo = bt.undo_left
	run.turns += bt.b.turn
	var res := bt.result
	if res == "lose":
		run.hp = 0
		end_run(false)
		return
	run.hp = clampi(bt.player().hp, 1, run.max_hp())
	run.room_count += 1
	var m := run.mods()
	run.heal(int(m.get("heal_on_room", 0)))
	if int(m.get("garden2", 0)) > 0 and run.room_count % 2 == 0:
		run.heal(1)
	var oil_extra := bt.b.oil_gained
	if res == "fail":
		run.hp = max(1, run.hp - 2)
		run.add_oil(oil_extra)
		toast("목표 실패 · 체력 -2", "bad")
		complete_node()
		return
	Save.stat_add("rooms")
	run.stats["rooms"] = int(run.stats.get("rooms", 0)) + 1
	if int(st.get("damage_taken", 0)) == 0:
		Save.stat_add("perfect_rooms")
	match bt.b.objective.get("type", ""):
		"candles":
			Save.stat_add("candle_rooms")
		"escape":
			Save.stat_add("escape_rooms")
		"protect":
			Save.stat_add("protect_rooms")
	var kind: String = room.get("kind", "battle")
	var oil := 0
	match kind:
		"battle":
			oil = rng.randi_range(12, 20)
		"elite":
			oil = rng.randi_range(28, 36)
			Save.stat_add("elites")
			run.stats["elites"] = int(run.stats.get("elites", 0)) + 1
		"boss":
			oil = rng.randi_range(55, 70)
			Save.stat_add("boss_" + str(room.get("boss", "")))
			Save.stat_add("bosses")
			run.stats["bosses"] = int(run.stats.get("bosses", 0)) + 1
	var gained := run.add_oil(oil + oil_extra)
	Save.stat_max("oil_max", run.oil)
	save_run()
	Save.check_unlocks()
	goto("reward", {"mode": kind, "oil": gained})


func complete_node() -> void:
	var was_boss := false
	if run.pending_node >= 0:
		var n := MapGen.node(run.map, run.pending_node)
		was_boss = n.get("type", "") == "boss"
	run.pending_node = -1
	if was_boss:
		next_floor()
		return
	save_run()
	goto("map")


func next_floor() -> void:
	run.floor += 1
	if run.floor >= run.floors_total:
		end_run(true)
		return
	run.heal(int(ceil((run.max_hp() - run.hp) * 0.5)))
	run.new_floor_map()
	if run.mode == "endless":
		Save.stat_max("endless_depth", run.floor + 1)
	save_run()
	Save.check_unlocks()
	goto("map", {"new_floor": true})


# ───────────────────────── 보상 ─────────────────────────
func roll_inscriptions(n: int, bias: int, owned: Array, min_rarity: int = 0) -> Array:
	var weights := [70, 25, 5]
	if bias == 1:
		weights = [45, 40, 15]
	if run != null and int(run.mods().get("rare_down", 0)) > 0:
		weights = [weights[0] + 10, max(5, weights[1] - 7), max(1, weights[2] - 3)]
	var by_r := [[], [], []]
	for k in UpgradeData.INSCRIPTIONS.keys():
		var d: Dictionary = UpgradeData.INSCRIPTIONS[k]
		var r := int(d["rarity"])
		if r == 2 and owned.has(k):
			continue
		by_r[r].append(k)
	var out := []
	var guard := 0
	while out.size() < n and guard < 100:
		guard += 1
		var roll := rng.randi_range(0, weights[0] + weights[1] + weights[2] - 1)
		var r2 := 0 if roll < weights[0] else (1 if roll < weights[0] + weights[1] else 2)
		r2 = max(r2, min_rarity)
		var arr: Array = by_r[r2]
		if arr.is_empty():
			continue
		var pick: String = arr[rng.randi_range(0, arr.size() - 1)]
		if not out.has(pick):
			out.append(pick)
	for k in out:
		Save.codex_add("insc", k)
	return out


func roll_relic(exclude: Array = []) -> String:
	var pool := []
	for k in UpgradeData.normal_relic_ids():
		if not run.relics.has(k) and not exclude.has(k):
			pool.append(k)
	if pool.is_empty():
		return ""
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	Save.codex_add("relics", pick)
	return pick


func gain_inscription(id: String) -> void:
	var new_sets := run.add_inscription(id)
	Save.codex_add("insc", id)
	for s in new_sets:
		Save.stat_add("sets")
		toast("세트 효과 · %s %d: %s" % [UI.tag_name(s["tag"]), s["n"], s["desc"]], "set")
	if run.max_hp() < run.hp:
		run.hp = run.max_hp()


func gain_relic(id: String) -> void:
	if id == "":
		return
	run.add_relic(id)
	Save.codex_add("relics", id)
	if id == "r_hourglass":
		run.undo += 2
	elif UpgradeData.relic(id)["fx"].has("undo"):
		run.undo = max(0, run.undo + int(UpgradeData.relic(id)["fx"]["undo"]))


## 이벤트 결과 적용 → 사람이 읽을 결과 문장 목록
func apply_outcomes(list: Array) -> Array:
	var msgs := []
	for o in list:
		var kind: String = o[0]
		var v = o[1]
		match kind:
			"hp":
				var before := run.hp
				run.hp = clampi(run.hp + int(v), 1, run.max_hp())
				msgs.append("체력 %+d" % (run.hp - before))
			"max_hp":
				run.extra_max_hp += int(v)
				if int(v) > 0:
					run.hp += int(v)
				run.clamp_hp()
				run.hp = max(1, run.hp)
				msgs.append("최대 체력 %+d" % int(v))
			"oil":
				var g := run.add_oil(int(v))
				msgs.append("기름 %+d" % g)
			"heal_pct":
				var h := run.heal(int(ceil(run.max_hp() * int(v) / 100.0)))
				msgs.append("체력 +%d" % h)
			"insc":
				var spec: String = v
				var pick := ""
				if spec == "rare":
					pick = roll_inscriptions(1, 1, run.inscriptions, 1)[0]
				elif spec.begins_with("tag:"):
					var tag := spec.substr(4)
					var cands := []
					for k in UpgradeData.INSCRIPTIONS.keys():
						var d: Dictionary = UpgradeData.INSCRIPTIONS[k]
						if d["tag"] == tag and not (int(d["rarity"]) == 2 and run.inscriptions.has(k)):
							cands.append(k)
					pick = cands[rng.randi_range(0, cands.size() - 1)]
				else:
					pick = roll_inscriptions(1, 0, run.inscriptions)[0]
				gain_inscription(pick)
				msgs.append("각인 획득: " + UpgradeData.inscription(pick)["name"])
			"relic":
				var rid: String = v if UpgradeData.RELICS.has(v) else roll_relic()
				if rid != "":
					gain_relic(rid)
					msgs.append("유물 획득: " + UpgradeData.relic(rid)["name"])
			"curse":
				var cs := []
				for k in UpgradeData.curse_ids():
					if not run.relics.has(k):
						cs.append(k)
				if not cs.is_empty():
					var cid: String = cs[rng.randi_range(0, cs.size() - 1)]
					gain_relic(cid)
					msgs.append("저주를 받았다: " + UpgradeData.relic(cid)["name"])
			"remove_insc":
				if not run.inscriptions.is_empty():
					var idx := rng.randi_range(0, run.inscriptions.size() - 1)
					var rem: String = run.inscriptions[idx]
					run.inscriptions.remove_at(idx)
					run.dirty()
					run.clamp_hp()
					run.hp = max(1, run.hp)
					msgs.append("각인을 잃었다: " + UpgradeData.inscription(rem)["name"])
			"fight":
				room["after_event_fight"] = true
				msgs.append("전투가 시작된다!")
			"embers":
				Save.add_embers(int(v))
				msgs.append("불씨 +%d" % int(v))
			"rescue":
				if not Save.meta["npcs"].has(v):
					Save.meta["npcs"].append(v)
					msgs.append("%s 구출! 오두막에 합류한다." % GearData.NPCS[v]["name"])
			"undo":
				run.undo += int(v)
				msgs.append("되돌리기 +%d" % int(v))
			"chance":
				var arr: Array = v
				if rng.randi_range(1, 100) <= int(arr[0]):
					msgs.append("— 운이 따랐다 —")
					msgs += apply_outcomes(arr[1])
				else:
					msgs.append("— 운이 없었다 —")
					msgs += apply_outcomes(arr[2])
	return msgs


func finish_event() -> void:
	Save.stat_add("events")
	if Save.facility_level("archive") > 0:
		run.add_oil(10)
	Save.check_unlocks()
	if room.get("after_event_fight", false):
		room.erase("after_event_fight")
		var n := MapGen.node(run.map, run.cur_node)
		var nn := n.duplicate()
		nn["row"] = max(2, int(n.get("row", 2)))
		_start_battle(nn, "elite")
		return
	complete_node()


# ───────────────────────── 종료 ─────────────────────────
func end_run(victory: bool, abandoned: bool = false) -> void:
	var r := run
	var m := r.mods()
	var rooms := int(r.stats.get("rooms", 0))
	var elites := int(r.stats.get("elites", 0))
	var bosses := int(r.stats.get("bosses", 0))
	var base := rooms * 2 + elites * 5 + bosses * 15 + r.floor * 5 + (40 if victory else 0)
	if r.mode == "endless":
		base += r.floor * 8
	var embers := int(round(base * (1.0 + 0.1 * r.asc) * (1.0 + int(m.get("ember_gain", 0)) / 100.0)))
	if abandoned:
		embers = embers / 2
	Save.add_embers(embers)
	if victory and r.mode != "endless":
		Save.stat_add("wins")
	elif not victory and not abandoned:
		Save.stat_add("deaths")
	if victory and r.mode == "normal":
		Save.stat_max("max_asc", r.asc)
		Save.meta["asc_unlocked"] = clampi(max(int(Save.meta["asc_unlocked"]), r.asc + 1), 0, MetaData.ASCENSION.size())
		var key := r.character
		Save.meta["best"]["asc"][key] = max(int(Save.meta["best"]["asc"].get(key, -1)), r.asc)
	var score := 0
	if r.mode == "daily" or r.mode == "weekly":
		score = (1000 if victory else 0) + int(r.stats.get("kills", 0)) * 15 + max(0, r.hp) * 25 + rooms * 40 - r.turns * 2
		score = max(0, score)
		var group := "daily" if r.mode == "daily" else "weekly"
		Save.meta["best"][group][r.date_key] = max(int(Save.meta["best"][group].get(r.date_key, 0)), score)
		Save.stat_add("dailies" if r.mode == "daily" else "weeklies")
	if r.mode == "endless":
		Save.stat_max("endless_depth", r.floor + 1)
		Save.meta["best"]["endless"] = max(int(Save.meta["best"]["endless"]), r.floor + 1)
	var summary := {"victory": victory, "abandoned": abandoned, "embers": embers, "rooms": rooms, "elites": elites,
		"bosses": bosses, "kills": int(r.stats.get("kills", 0)), "floor": r.floor, "mode": r.mode, "score": score,
		"date": r.date_key, "hp": r.hp, "character": r.character, "lantern": r.lantern, "asc": r.asc,
		"inscriptions": r.inscriptions.duplicate(), "relics": r.relics.duplicate()}
	run = null
	battle = null
	Save.meta["run"] = null
	Save.save_meta()
	var unlocks := Save.check_unlocks()
	summary["unlocks"] = unlocks
	goto("result", summary)


# ───────────────────────── 퍼즐 ─────────────────────────
func start_puzzle(i: int) -> void:
	var list := PuzzleData.load_all()
	if i < 0 or i >= list.size():
		goto("puzzles")
		return
	battle = PuzzleData.make_battle(list[i])
	room = {"puzzle": i, "kind": "puzzle"}
	goto("battle", {"puzzle": true})


func puzzle_solved(i: int) -> void:
	Save.meta["puzzles"][str(i)] = true
	Save.save_meta()
	Save.check_unlocks()
