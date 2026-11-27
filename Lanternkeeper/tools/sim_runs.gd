extends SceneTree
## 밸런스 점검: 봇이 실제 체력으로 탐험 전체를 진행했을 때 어디서 쓰러지는지 센다.
## 실행: godot --headless --path . -s tools/sim_runs.gd

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var deaths := {}
	var wins := 0
	var N := int(OS.get_environment("SIM_RUNS")) if OS.get_environment("SIM_RUNS") != "" else 20
	var lantern: String = OS.get_environment("SIM_LANTERN") if OS.get_environment("SIM_LANTERN") != "" else "candle"
	var rooms_total := 0
	for run_i in N:
		var r := RunState.new()
		r.seed = rng.randi()
		r.lantern = lantern
		r.hp = r.max_hp()
		var died := false
		for f in 4:
			r.floor = f
			r.new_floor_map()
			var cur := -1
			while true:
				var av := r.available_nodes()
				if av.is_empty():
					break
				var nid: int = av[rng.randi_range(0, av.size() - 1)]
				r.cur_node = nid
				var n := MapGen.node(r.map, nid)
				var t: String = n["type"]
				if t in ["battle", "elite", "boss"]:
					var m := r.mods()
					var b := RoomGen.generate({"biome": r.biome(), "kind": t, "floor": f, "row": int(n["row"]), "seed": r.node_seed(nid),
						"mods": m, "player_hp": r.hp, "player_max": r.max_hp(), "player_move": r.move()})
					var bt := Battle.new(b, m, r.lantern, r.undo)
					var turns := 0
					while bt.result == "" and turns < 30:
						turns += 1
						Bot.play_turn(bt, 5, 10)
					rooms_total += 1
					if bt.result == "lose" or (bt.result == "" and bt.player().hp <= 0):
						var key := "%d층 %s" % [f + 1, t]
						deaths[key] = int(deaths.get(key, 0)) + 1
						died = true
						break
					r.hp = clampi(bt.player().hp, 1, r.max_hp())
					if bt.result == "fail":
						r.hp = max(1, r.hp - 2)
					else:
						# 보상: 무작위 각인 하나
						var keys := UpgradeData.INSCRIPTIONS.keys()
						r.add_inscription(keys[rng.randi_range(0, keys.size() - 1)])
						if t != "battle":
							var rel := UpgradeData.normal_relic_ids()
							r.add_relic(rel[rng.randi_range(0, rel.size() - 1)])
						if t == "boss":
							r.heal(int(ceil(r.max_hp() * 0.3)))
				elif t == "rest":
					r.heal(int(ceil(r.max_hp() * 0.35)))
				elif t == "treasure":
					var rel2 := UpgradeData.normal_relic_ids()
					r.add_relic(rel2[rng.randi_range(0, rel2.size() - 1)])
				if t == "boss":
					break
			if died:
				break
			r.heal(int(ceil((r.max_hp() - r.hp) * 0.5)))
		if not died:
			wins += 1
	print("등불 %s · 탐험 %d회 · 정복 %d회 (%.0f%%)" % [lantern, N, wins, 100.0 * wins / N])
	var ks := deaths.keys()
	ks.sort()
	for k in ks:
		print("  쓰러진 곳 %s: %d" % [k, deaths[k]])
	quit()
