extends Screen
## 층 지도: 갈림길을 골라 다음 방으로.

const ROW_H := 150.0
const COLORS := {"battle": Color(0.85, 0.8, 0.75), "elite": Color(1, 0.45, 0.4), "event": Color(0.55, 0.8, 1.0),
	"shop": Color(1, 0.85, 0.35), "rest": Color(1, 0.6, 0.3), "treasure": Color(0.95, 0.75, 0.3), "boss": Color(1, 0.35, 0.3)}


class MapView:
	extends Control
	var map: Dictionary
	var available: Array
	var visited: Array
	var cur: int
	var on_pick: Callable
	var t := 0.0
	var accent: Color

	func node_pos(n: Dictionary) -> Vector2:
		var rows: int = map["rows"]
		var y := size.y - 90 - float(n["row"]) * ROW_H
		var x := 70 + float(n["x"]) * (size.x - 140)
		if n["type"] == "boss":
			y = size.y - 90 - rows * ROW_H - 20
			x = size.x * 0.5
		return Vector2(x, y)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		for n in map["nodes"]:
			var a := node_pos(n)
			for l in n["links"]:
				var m := MapGen.node(map, l)
				var b := node_pos(m)
				var col := Color(1, 1, 1, 0.12)
				if visited.has(int(n["id"])) and (visited.has(int(l)) or (int(n["id"]) == cur and available.has(int(l)))):
					col = Color(accent, 0.7)
				var steps := 10
				for i in steps:
					if i % 2 == 0:
						draw_line(a.lerp(b, i / float(steps)), a.lerp(b, (i + 1) / float(steps)), col, 3)
		for n in map["nodes"]:
			var p := node_pos(n)
			var id := int(n["id"])
			var col: Color = COLORS.get(n["type"], Color.WHITE)
			var r := 38.0 if n["type"] != "boss" else 58.0
			var avail := available.has(id)
			var done := visited.has(id)
			if avail:
				draw_circle(p, r + 10 + 4 * sin(t * 4), Color(accent, 0.22))
			draw_circle(p, r, Color(0.1, 0.09, 0.13))
			draw_arc(p, r, 0, TAU, 32, col if (avail or done) else Color(col, 0.35), 3, true)
			Art.node_icon(self, n["type"], p, r, col if (avail or not done) else Color(col, 0.4))
			if done:
				draw_circle(p + Vector2(r * 0.7, -r * 0.7), 9, accent)

	func _gui_input(e: InputEvent) -> void:
		var pressed: bool = (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
		if not pressed:
			return
		for n in map["nodes"]:
			if available.has(int(n["id"])) and node_pos(n).distance_to(e.position) < 60:
				on_pick.call(int(n["id"]))
				return


var hud: RunHud


func build(p: Dictionary) -> void:
	var r := Game.run
	if r == null:
		Game.goto("title")
		return
	var bd := BiomeData.get_def(r.biome())
	Sfx.music(bd["music"])
	var v := UI.screen_frame(self, "")
	hud = RunHud.make(self)
	v.add_child(hud)
	var rule := UI.label(bd["rule"], 22, bd["accent"])
	v.add_child(rule)
	var mv := MapView.new()
	mv.map = r.map
	mv.available = r.available_nodes()
	mv.visited = r.visited
	mv.cur = r.cur_node
	mv.accent = bd["accent"]
	mv.on_pick = func(id: int):
		Sfx.play("ui_confirm")
		Game.enter_node(id)
	mv.custom_minimum_size = Vector2(0, 180 + (int(r.map["rows"]) + 1) * ROW_H)
	mv.mouse_filter = Control.MOUSE_FILTER_PASS
	var sc := UI.scroll(mv)
	v.add_child(sc)
	var legend := UI.label("× 전투  ◆ 엘리트  ? 이벤트  ○ 상점  ▲ 휴식  □ 보물  ★ 보스", 20, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(legend)
	await get_tree().process_frame
	var cur_row := 0
	if r.cur_node >= 0:
		cur_row = int(MapGen.node(r.map, r.cur_node)["row"])
	sc.scroll_vertical = int(max(0, mv.custom_minimum_size.y - sc.size.y - cur_row * ROW_H + 100))
	if p.get("new_floor", false):
		_floor_banner(bd)


func _floor_banner(bd: Dictionary) -> void:
	var r := Game.run
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 0.75)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cc)
	var v := UI.vbox(10)
	cc.add_child(v)
	var head := "%d층" % (r.floor + 1)
	if r.mode == "daily":
		head = "일일 도전 · " + r.date_key
	v.add_child(UI.label(head, 30, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(bd["name"], 64, bd["accent"], true, HORIZONTAL_ALIGNMENT_CENTER))
	var rl := UI.label(bd["rule"], 24, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	rl.custom_minimum_size = Vector2(600, 0)
	v.add_child(rl)
	Sfx.play("banner")
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(c, "modulate:a", 0.0, 0.6)
	tw.tween_callback(c.queue_free)
