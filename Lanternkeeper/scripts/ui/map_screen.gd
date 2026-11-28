extends Screen
## 층 지도: 갈 수 있는 방은 불 켜진 등처럼 밝다.

const ROW_H := 150.0
const ICONS := {"battle": "sword", "elite": "horn", "event": "question", "shop": "coin", "rest": "fire", "treasure": "chest", "boss": "crown"}
const TINT := {"battle": Color("b9b2c8"), "elite": Color("ee6a56"), "event": Color("8fb4ff"), "shop": Color("ffd36a"),
	"rest": Color("ff9a4a"), "treasure": Color("ffd36a"), "boss": Color("ff5a4a")}


class MapView:
	extends Control
	var map: Dictionary
	var available: Array
	var visited: Array
	var cur: int
	var on_pick: Callable
	var t := 0.0
	var accent: Color

	var _slots := {}

	func _build_slots() -> void:
		var rows := {}
		for n in map["nodes"]:
			var r := int(n["row"])
			if not rows.has(r):
				rows[r] = []
			rows[r].append(n)
		for r in rows.keys():
			var arr: Array = rows[r]
			arr.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
			for i in arr.size():
				var jitter := (float((int(arr[i]["id"]) * 37) % 11) / 11.0 - 0.5) * 0.05
				_slots[int(arr[i]["id"])] = (i + 1.0) / (arr.size() + 1.0) + jitter

	func node_pos(n: Dictionary) -> Vector2:
		if _slots.is_empty():
			_build_slots()
		var rows: int = map["rows"]
		var y := size.y - 110 - float(n["row"]) * ROW_H
		var x := 30 + float(_slots.get(int(n["id"]), 0.5)) * (size.x - 60)
		if n["type"] == "boss":
			y = size.y - 110 - rows * ROW_H - 30
			x = size.x * 0.5
		return Vector2(x, y)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		for n in map["nodes"]:
			var a := node_pos(n)
			for l in n["links"]:
				var b := node_pos(MapGen.node(map, l))
				var walked: bool = visited.has(int(n["id"])) and visited.has(int(l))
				var open: bool = int(n["id"]) == cur and available.has(int(l))
				var col := Color(1, 1, 1, 0.16)
				if walked:
					col = Color(UI.BRASS, 0.55)
				elif open:
					col = Color(UI.AMBER, 0.6 + 0.25 * sin(t * 4))
				var dist := a.distance_to(b)
				var steps := int(dist / 16.0)
				for i in steps:
					var f := (i + 0.5) / steps
					if a.lerp(b, f).distance_to(a) < 46 or a.lerp(b, f).distance_to(b) < 46:
						continue
					draw_circle(a.lerp(b, f), 3.0 if (walked or open) else 2.2, col)
		for n in map["nodes"]:
			var p := node_pos(n)
			var id := int(n["id"])
			var type: String = n["type"]
			var tint: Color = TINT.get(type, Color.WHITE)
			var r := 40.0 if type != "boss" else 58.0
			var avail := available.has(id)
			var done := visited.has(id)
			if avail:
				var pulse := 0.5 + 0.5 * sin(t * 3.5)
				for i in 12:
					draw_circle(p, r + (26.0 + 10.0 * pulse) * (i + 1) / 12.0, Color(1.0, 0.66, 0.26, 0.035))
				draw_circle(p, r, Color("e9d6ab"))
				draw_circle(p - Vector2(0, r * 0.12), r * 0.86, Color("f7ecd3"))
				draw_arc(p, r, 0, TAU, 48, UI.WOOD, 3.5, true)
				Icon.paint(self, ICONS.get(type, "sword"), p, r * 0.95, UI.INK)
				var name: String = MapGen.TYPE_NAMES.get(type, "")
				var w := UI.font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				draw_string(UI.font_bold, p + Vector2(-w / 2, r + 28), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.AMBER)
			elif done:
				draw_circle(p, r, Color(0.1, 0.095, 0.17))
				draw_arc(p, r, 0, TAU, 48, Color(UI.BRASS, 0.55), 2, true)
				Icon.paint(self, "check" if id != cur else ICONS.get(type, "sword"), p, r * 0.8, Color(UI.BRASS, 0.8))
				if id == cur:
					draw_arc(p, r + 7, t, t + PI * 1.4, 24, Color(UI.AMBER, 0.8), 2.5, true)
			else:
				draw_circle(p, r, Color(0.085, 0.08, 0.145))
				draw_arc(p, r, 0, TAU, 48, Color(tint, 0.3), 2, true)
				Icon.paint(self, ICONS.get(type, "sword"), p, r * 0.85, Color(tint, 0.6))

	func _gui_input(e: InputEvent) -> void:
		if not UI.is_tap(e):
			return
		for n in map["nodes"]:
			if available.has(int(n["id"])) and node_pos(n).distance_to(e.position) < 64:
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
	var v := UI.screen_frame(self, "", Callable(), r.biome())
	hud = RunHud.make(self)
	hud.place.text = hud.place.text.split("  ")[0]
	v.add_child(hud)
	var head := UI.vbox(2)
	head.add_child(UI.title(bd["name"], 34, bd["accent"]))
	head.add_child(UI.label(bd["rule"], 20, UI.SUB))
	v.add_child(head)
	var mv := MapView.new()
	mv.map = r.map
	mv.available = r.available_nodes()
	mv.visited = r.visited
	mv.cur = r.cur_node
	mv.accent = bd["accent"]
	mv.on_pick = func(id: int):
		Sfx.play("ui_confirm")
		Game.enter_node(id)
	mv.custom_minimum_size = Vector2(0, 240 + (int(r.map["rows"]) + 1) * ROW_H)
	mv.mouse_filter = Control.MOUSE_FILTER_PASS
	var sc := UI.scroll(mv)
	v.add_child(sc)
	await get_tree().process_frame
	var cur_row := 0
	if r.cur_node >= 0:
		cur_row = int(MapGen.node(r.map, r.cur_node)["row"])
	sc.scroll_vertical = int(max(0, mv.custom_minimum_size.y - sc.size.y - cur_row * ROW_H + 110))
	if p.get("new_floor", false):
		_floor_banner(bd)


func _floor_banner(bd: Dictionary) -> void:
	var r := Game.run
	var c := ColorRect.new()
	c.color = Color(0.02, 0.02, 0.05, 0.86)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cc)
	var v := UI.vbox(14)
	cc.add_child(v)
	var head := "%d층" % (r.floor + 1)
	if r.mode == "daily":
		head = "일일 도전  " + r.date_key
	v.add_child(UI.label(head, 26, UI.SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.title(bd["name"], 72, bd["accent"], HORIZONTAL_ALIGNMENT_CENTER))
	var rl := UI.label(bd["rule"], 23, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	rl.custom_minimum_size = Vector2(560, 0)
	v.add_child(rl)
	Sfx.play("banner")
	var tw := create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(c, "modulate:a", 0.0, 0.6)
	tw.tween_callback(c.queue_free)
