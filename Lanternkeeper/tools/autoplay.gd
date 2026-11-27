extends Node
## 실제 화면 위에서 봇이 탐험을 끝까지 플레이한다 (런타임 오류 점검용).
## 실행: xvfb-run godot --path . -- --demo=autoplay:3

var runs_left := 2
var main: Control
var log_lines: Array = []
var steps := 0
var max_steps := 4000
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
	Game.new_run(modes[mi], "keeper", GearData.LANTERN_ORDER[randi() % 6], 0)
	while steps < max_steps:
		steps += 1
		await get_tree().create_timer(0.05).timeout
		var cur: Control = main.current
		if cur == null:
			continue
		var script_path: String = cur.get_script().resource_path
		var name := script_path.get_file().get_basename()
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
				await _play_turn(cur, bt)
			"reward_screen":
				await _shot("reward")
				if not cur.choices.is_empty() and cur.body.get_child_count() > 0 and cur.body.get_child(0) is Label and cur.body.get_child(0).text.begins_with("각인"):
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
