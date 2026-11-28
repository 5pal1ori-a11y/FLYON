extends Node
## 실제 화면 위에서 봇이 탐험을 끝까지 플레이한다 (런타임 오류 점검용).
## 실행: xvfb-run godot --path . -- --demo=autoplay:3

var runs_left := 2
var main: Control
var log_lines: Array = []
var steps := 0
var max_steps := 4000 if OS.get_environment("AUTOPLAY_STEPS") == "" else int(OS.get_environment("AUTOPLAY_STEPS"))
var screenshot_dir := ""
var shots := 0


func _ready() -> void:
	Engine.time_scale = 6.0
	Save.meta["settings"]["fast"] = true
	screenshot_dir = OS.get_environment("AUTOPLAY_SHOTS")
	_loop()


func _log(s: String) -> void:
	print("[autoplay] ", s)


func _shot(tag: String) -> void:
	if screenshot_dir == "" or shots >= 40:
		return
	shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [screenshot_dir, shots, tag])


func _loop() -> void:
	var modes := ["normal", "normal", "daily", "weekly", "endless"]
	var mi := 0
	var first: String = OS.get_environment("AUTOPLAY_LANTERN") if OS.get_environment("AUTOPLAY_LANTERN") != "" else GearData.LANTERN_ORDER[randi() % 6]
	Game.new_run(modes[mi], "keeper", first, 0)
	while steps < max_steps:
		steps += 1
		await get_tree().create_timer(0.05).timeout
		var cur: Control = main.current
		if cur == null:
			continue
		var script_path: String = cur.get_script().resource_path
		var name := script_path.get_file().get_basename()
		if steps % 150 == 0:
			var extra := ""
			if name == "battle_screen":
				extra = " busy=%s phase=%s result=%s turn=%d obj=%s p=%s hp=%d" % [cur.busy, cur.bt.phase, cur.bt.result, cur.bt.b.turn, cur.bt.b.objective, cur.bt.player().pos, cur.bt.player().hp]
				for e in cur.bt.b.enemies():
					extra += " [%s %s hp%d st%s]" % [e.kind, e.pos, e.hp, e.st]
			_log("단계 %d 화면 %s%s" % [steps, name, extra])
		match name:
			"map_screen":
				if Game.run == null:
					continue
				await _shot("map")
				var av := Game.run.available_nodes()
				if av.is_empty():
					_log("갈 곳이 없음!")
					break
				Game.enter_node(av[randi() % av.size()])
			"battle_screen":
				if cur.busy:
					continue
				var bt: Battle = cur.bt
				if bt.result != "":
					continue
				if bt.b.turn > 90:
					_log("봇이 방을 끝내지 못해 탐험을 접음 (%s)" % [bt.b.objective.get("type", "")])
					Game.end_run(false, true)
					continue
				await _play_turn(cur, bt)
			"reward_screen":
				await _shot("reward")
				if cur.step_kind == "insc" and not cur.choices.is_empty():
					Game.gain_inscription(cur.choices[0])
					cur.choices = []
					cur._next()
				else:
					var rid := Game.roll_relic()
					if rid != "":
						Game.gain_relic(rid)
					cur._next()
			"shop_screen":
				await _shot("shop")
				if Game.run.oil >= 40 and not cur.stock["insc"].is_empty():
					cur._buy("insc", cur.stock["insc"][0], 0)
				Game.complete_node()
			"event_screen":
				await _shot("event")
				var ev: Dictionary = cur.ev
				var picked := false
				for ch in ev["choices"]:
					var req: Dictionary = ch.get("req", {})
					if req.has("oil") and Game.run.oil < int(req["oil"]):
						continue
					cur._choose(ch)
					picked = true
					break
				await get_tree().create_timer(0.1).timeout
				Game.finish_event()
			"rest_screen":
				Game.run.heal(3)
				cur._done()
			"result_screen":
				await _shot("result")
				_log("탐험 종료 → %s" % [cur.params.get("victory", false)])
				runs_left -= 1
				mi += 1
				if runs_left <= 0 or mi >= modes.size():
					break
				Game.new_run(modes[mi], "keeper", "candle", 0)
			"title_screen", "hub_screen":
				Game.new_run("normal", "keeper", "candle", 0)
	_log("끝 (단계 %d)" % steps)
	get_tree().quit()


func _play_turn(cur, bt: Battle) -> void:
	# 봇이 고른 수를 화면 함수로 실행한다
	var p := bt.player()
	var reach := bt.reachable()
	var best_move := p.pos
	var best_cells := []
	var best_score := -INF
	var moves := [p.pos]
	for c in reach.keys():
		if reach[c]["type"] == "walk":
			moves.append(c)
	moves.shuffle()
	moves = moves.slice(0, 5)
	if not moves.has(p.pos):
		moves.append(p.pos)
	for mv in moves:
		var cb := bt.b.clone()
		cb.player().pos = mv
		if cb.objective.get("type", "") == "escape" and mv == cb.objective["exit"]:
			best_move = mv
			best_cells = []
			best_score = INF
			break
		var cells := Bot._lantern_cells(cb, bt)
		cells.shuffle()
		for c in cells.slice(0, 8):
			var choice := [c]
			if bt.needs_cells() == 2:
				for c2 in cells:
					if c2 != c:
						choice.append(c2)
						break
			var sc := Bot._eval(bt, cb, choice)
			if sc > best_score:
				best_score = sc
				best_move = mv
				best_cells = choice
	# 화로 곁의 적은 그림자가 닿지 않는다. 오래 끌면 화로를 끄러 간다.
	var braziers := bt.b.cells_of(Board.BRAZIER)
	if bt.b.turn > 12 and not braziers.is_empty():
		for c in reach.keys():
			if reach[c]["type"] == "douse":
				await cur._do_move(c)
				best_move = p.pos
				break
		if bt.phase == "move":
			var bd := 999
			for c in reach.keys():
				if reach[c]["type"] == "walk" and Board.manhattan(c, braziers[0]) < bd:
					bd = Board.manhattan(c, braziers[0])
					best_move = c
	elif best_score <= 0.5 and not bt.b.enemies().is_empty():
		# 얻을 게 없는 턴이면 가장 가까운 적 쪽으로 걸어간다
		var best_d := 999
		for c in reach.keys():
			if reach[c]["type"] != "walk":
				continue
			var d := 999
			for e in bt.b.enemies():
				d = min(d, abs(Board.manhattan(c, e.pos) - 2))
			if d < best_d:
				best_d = d
				best_move = c
	if bt.phase == "move":
		if best_move != p.pos and reach.has(best_move):
			await cur._do_move(best_move)
		else:
			cur._on_skip_move()
	if bt.result != "" or best_cells.is_empty():
		if bt.result == "" and best_cells.is_empty():
			best_cells = [bt.lantern_cells()[0]]
		else:
			return
	for c in best_cells:
		if not bt.lantern_cells(cur.locked).has(c):
			var lc := bt.lantern_cells(cur.locked)
			if lc.is_empty():
				return
			c = lc[0]
		cur._set_preview(c)
		if randf() < 0.1:
			await _shot("preview")
		await cur._on_fire()
