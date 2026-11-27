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
	var y := cell * 0.42
	if max_hp <= 8:
		var w := 9.0
		var total := max_hp * w + (max_hp - 1) * 3.0
		for i in max_hp:
			var x := -total / 2.0 + i * (w + 3.0)
			draw_rect(Rect2(x, y, w, 7), Color(1, 0.35, 0.3) if i < hp else Color(0.25, 0.2, 0.2))
	else:
		var bw := cell * 0.7
		draw_rect(Rect2(-bw / 2, y, bw, 8), Color(0.25, 0.2, 0.2))
		draw_rect(Rect2(-bw / 2, y, bw * clampf(hp / float(max_hp), 0, 1), 8), Color(1, 0.35, 0.3))
		draw_string(UI.font_bold, Vector2(-bw / 2, y - 4), "%d/%d" % [hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.8, 0.75))
	# 상태 아이콘
	var ix := cell * 0.28
	var iy := -cell * 0.42
	for key in ["burn", "poison", "shield"]:
		var n := int(st.get(key, 0))
		if n <= 0:
			continue
		var col := Color(1, 0.55, 0.2)
		var glyph := "화"
		if key == "poison":
			col = Color(0.5, 0.95, 0.45)
			glyph = "독"
		elif key == "shield":
			col = Color(0.8, 0.8, 0.85)
			glyph = "막"
		draw_circle(Vector2(ix, iy), 13, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(Vector2(ix, iy), 13, 0, TAU, 16, col, 2)
		draw_string(UI.font_bold, Vector2(ix - 9, iy + 6), glyph if n == 1 else str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		iy += 28
