class_name UnitView
extends Node2D
## 보드 위 유닛 하나의 그림 + 체력 + 상태 표시.

var uid: int = 0
var kind: String = ""
var facing := Vector2i(0, 1)
var hp: int = 1
var max_hp: int = 1
var st: Dictionary = {}
var elite: String = ""
var boss: bool = false
var cell: float = 96.0
var t: float = 0.0
var flash: float = 0.0
var hidden_fog: bool = false
var still: bool = false
var aura: bool = true
var colorblind: bool = false
var skin_col := Color(1.0, 0.72, 0.35)
var prism := false


func from_unit(u: Unit, b: Board) -> void:
	uid = u.id
	kind = u.kind
	facing = u.facing
	hp = u.hp
	max_hp = u.max_hp
	st = u.st.duplicate()
	elite = u.elite
	boss = u.boss
	aura = u.has_aura()
	still = kind == "statue" and b.last_lit.has(u.pos)


func _process(d: float) -> void:
	t += d
	if flash > 0:
		flash = max(0.0, flash - d * 4.0)
	queue_redraw()


func _draw() -> void:
	if hidden_fog:
		Art.blob(self, Vector2(0, 6), cell * 0.26, cell * 0.22, Color(0.25, 0.3, 0.28, 0.55), 20, 0.1, t)
		draw_string(UI.font_bold, Vector2(-10, 16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.8, 0.9, 0.85, 0.8))
		return
	var frozen := int(st.get("frozen", 0)) > 0
	if elite != "":
		var ec := Color(1, 0.4, 0.3, 0.35 + 0.15 * sin(t * 4))
		draw_arc(Vector2(0, 4), cell * 0.44, 0, TAU, 32, ec, 3, true)
	if boss:
		draw_circle(Vector2.ZERO, cell * 0.55, Color(1, 0.3, 0.2, 0.08 + 0.04 * sin(t * 2)))
	var opts := {"t": t, "facing": facing, "aura": aura, "still": still}
	if kind == "player":
		opts["skin"] = Color.from_hsv(fmod(t * 0.15, 1.0), 0.6, 1.0) if prism else skin_col
		opts["who"] = Game.run.character if Game.run != null else "keeper"
	var sc := 1.0
	if boss and kind != "mirrorlord":
		sc = 1.25
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	Art.unit(self, kind, cell, opts)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0:
		draw_circle(Vector2(0, 2), cell * 0.32, Color(1, 1, 1, flash * 0.6))
	if frozen:
		draw_circle(Vector2(0, 2), cell * 0.4, Color(0.6, 0.9, 1.0, 0.22))
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			draw_line(Vector2(cos(a), sin(a)) * cell * 0.3, Vector2(cos(a), sin(a)) * cell * 0.42, Color(0.75, 0.95, 1.0, 0.8), 2)
		if colorblind:
			draw_string(UI.font_bold, Vector2(-cell * 0.45, -cell * 0.3), "굳음", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.95, 1.0))
	if kind == "beacon" or kind == "player":
		return
	# 체력
	var y := cell * 0.4
	if max_hp <= 8:
		var w := 9.0
		var total := max_hp * w + (max_hp - 1) * 3.0
		draw_rect(Rect2(-total / 2.0 - 4, y - 3, total + 8, 13), Color(0, 0, 0, 0.55))
		for i in max_hp:
			var x := -total / 2.0 + i * (w + 3.0)
			draw_rect(Rect2(x, y, w, 7), Color(1, 0.38, 0.32) if i < hp else Color(1, 1, 1, 0.14))
	else:
		var bw := cell * 0.74
		draw_rect(Rect2(-bw / 2 - 3, y - 3, bw + 6, 14), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-bw / 2, y, bw, 8), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(-bw / 2, y, bw * clampf(hp / float(max_hp), 0, 1), 8), Color(1, 0.38, 0.32))
	# 상태 표시
	var ix := cell * 0.3
	var iy := -cell * 0.36
	for key in ["burn", "poison", "shield"]:
		var n := int(st.get(key, 0))
		if n <= 0:
			continue
		var col := Color(1, 0.55, 0.2)
		var glyph := "flame"
		if key == "poison":
			col = Color(0.5, 0.95, 0.45)
			glyph = "poison"
		elif key == "shield":
			col = Color(0.82, 0.84, 0.9)
			glyph = "shield"
		draw_circle(Vector2(ix, iy), 13, Color(0.05, 0.05, 0.08, 0.92))
		draw_arc(Vector2(ix, iy), 13, 0, TAU, 18, col, 2, true)
		Icon.paint(self, glyph, Vector2(ix, iy), 15, col)
		if n > 1:
			draw_string_outline(UI.font_bold, Vector2(ix + 8, iy + 14), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
			draw_string(UI.font_bold, Vector2(ix + 8, iy + 14), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		iy += 30
