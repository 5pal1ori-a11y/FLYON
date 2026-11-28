class_name LanternDiagram
extends Control
## 등불이 그림자를 어떻게 드리우는지 보여 주는 작은 그림. 실제 규칙 엔진으로 계산한다.

const N := 5
var lantern_id := "candle"
var lights: Array = []
var shadow := {}
var lit := {}
var mode := "point"


static func make(id: String, px: float = 170.0) -> LanternDiagram:
	var d := LanternDiagram.new()
	d.custom_minimum_size = Vector2(px, px)
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_lantern(id)
	return d


func set_lantern(id: String) -> void:
	lantern_id = id
	var def: Dictionary = GearData.LANTERNS[id]
	mode = def["mode"]
	var b := Board.new(N, N)
	b.spawn_player(Vector2i(2, 2), 5, 5, 2)
	b.set_tile(Vector2i(3, 2), Board.PILLAR)
	var cells := [Vector2i(2, 4)]
	if int(def["count"]) == 2:
		cells = [Vector2i(1, 4), Vector2i(3, 4)]
	lights = Combat.build_lights(b, cells, {"mods": {}, "lantern": def})
	shadow = {}
	lit = {}
	var blocked := {}
	for li in lights:
		for s in Shadows.cast_light(b, li, blocked):
			for c in s["cells"]:
				shadow[c] = true
		for c in b.all_cells():
			if Combat.light_covers(li, c):
				lit[c] = true
	queue_redraw()


func _draw() -> void:
	var cs := size.x / N
	var def: Dictionary = GearData.LANTERNS[lantern_id]
	var lc: Color = def["color"]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.24, 0.12, 0.1))
	for y in N:
		for x in N:
			var c := Vector2i(x, y)
			var r := Rect2(Vector2(c) * cs, Vector2(cs, cs)).grow(-1.5)
			if mode == "inverse":
				if lit.has(c) and not shadow.has(c):
					draw_rect(r, Color(0.48, 0.25, 0.8, 0.5))
				elif shadow.has(c):
					draw_rect(r, Color(0.2, 0.14, 0.1, 0.16))
			else:
				if lit.has(c):
					draw_rect(r, Color(1.0, 0.7, 0.25, 0.2 if mode != "directional" else 0.1))
				if shadow.has(c):
					draw_rect(r, Color(0.2, 0.1, 0.36, 0.78))
	for i in N + 1:
		draw_line(Vector2(i * cs, 0), Vector2(i * cs, size.y), Color(0.3, 0.2, 0.1, 0.16), 1)
		draw_line(Vector2(0, i * cs), Vector2(size.x, i * cs), Color(0.3, 0.2, 0.1, 0.16), 1)
	# 기둥
	var pc := (Vector2(3, 2) + Vector2(0.5, 0.5)) * cs
	draw_rect(Rect2(pc - Vector2(cs, cs) * 0.3, Vector2(cs, cs) * 0.6), Color("7a6a58"))
	draw_rect(Rect2(pc - Vector2(cs, cs) * 0.3, Vector2(cs * 0.6, cs * 0.14)), Color("9a8a76"))
	# 등불지기
	var kc := (Vector2(2, 2) + Vector2(0.5, 0.5)) * cs
	draw_colored_polygon(PackedVector2Array([kc + Vector2(-0.24, 0.34) * cs, kc + Vector2(0.24, 0.34) * cs, kc + Vector2(0.12, -0.1) * cs, kc + Vector2(-0.12, -0.1) * cs]), UI.INK)
	draw_circle(kc + Vector2(0, -0.2) * cs, cs * 0.16, UI.INK)
	# 등불
	for li in lights:
		if not li["main"]:
			continue
		var c2 := (Vector2(li["cell"]) + Vector2(0.5, 0.5)) * cs
		draw_circle(c2, cs * 0.42, Color(lc, 0.35))
		draw_rect(Rect2(c2 - Vector2(cs, cs) * 0.2, Vector2(cs, cs) * 0.4), UI.WOOD)
		draw_rect(Rect2(c2 - Vector2(cs, cs) * 0.12, Vector2(cs, cs) * 0.24), lc.lerp(Color.WHITE, 0.25))
