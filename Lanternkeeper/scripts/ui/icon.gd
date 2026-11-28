class_name Icon
extends Control
## 코드로 그리는 선 아이콘. 24칸 격자 기준(-12..12)으로 그린다.

var kind := "heart"
var col := Color.WHITE
var px := 28.0
var badge := Color(0, 0, 0, 0)


static func make(k: String, size: float = 28.0, c: Color = Color.WHITE) -> Icon:
	var i := Icon.new()
	i.kind = k
	i.px = size
	i.col = c
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i


## 동그란 바탕 위의 아이콘
static func make_badge(k: String, size: float, bg: Color, fg: Color) -> Icon:
	var i := make(k, size * 0.56, fg)
	i.badge = bg
	i.custom_minimum_size = Vector2(size, size)
	return i


func _draw() -> void:
	var c := size * 0.5
	if badge.a > 0.0:
		draw_circle(c, minf(size.x, size.y) * 0.5, badge)
		draw_arc(c, minf(size.x, size.y) * 0.5 - 2.5, 0, TAU, 40, Color(col, 0.35), 1.5, true)
	Icon.paint(self, kind, c, px, col)


static func _pl(ci: CanvasItem, c: Vector2, u: float, pts: Array, col: Color, w: float, closed: bool = false) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(c + Vector2(q[0], q[1]) * u)
	if closed:
		p.append(p[0])
	ci.draw_polyline(p, col, w, true)


static func _pg(ci: CanvasItem, c: Vector2, u: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(c + Vector2(q[0], q[1]) * u)
	ci.draw_colored_polygon(p, col)


static func paint(ci: CanvasItem, k: String, c: Vector2, s: float, col: Color) -> void:
	var u := s / 24.0
	var w := maxf(1.6, 2.1 * u)
	match k:
		"heart":
			var p := PackedVector2Array()
			for i in 28:
				var t := TAU * i / 28.0
				p.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) - 1.5) * u * 0.62)
			ci.draw_colored_polygon(p, col)
		"oil":
			var p2 := PackedVector2Array([c + Vector2(0, -10.5) * u])
			for i in 15:
				var a := deg_to_rad(-38.0 + 256.0 * i / 14.0)
				p2.append(c + Vector2(0, 3) * u + Vector2(cos(a), sin(a)) * 7.2 * u)
			ci.draw_colored_polygon(p2, col)
			ci.draw_arc(c + Vector2(0, 3) * u, 4.2 * u, 0.5, 1.9, 8, Color(1, 1, 1, 0.45), 1.4 * u, true)
		"flame":
			_pg(ci, c, u, [[0.5, -11], [5, -4.5], [7.5, 2], [5.5, 8], [0, 10.5], [-5.5, 8], [-7.5, 2], [-4.5, -2], [-2.5, -6]], col)
			_pg(ci, c, u, [[0, 0], [3, 5], [0, 8.5], [-3, 5]], Color(1, 1, 1, 0.45))
		"undo":
			ci.draw_arc(c + Vector2(1, 1.5) * u, 7.5 * u, -PI * 0.95, PI * 0.55, 20, col, w, true)
			_pg(ci, c, u, [[-10.5, -2], [-3.5, -3.5], [-7.5, 3.5]], col)
		"bag":
			ci.draw_arc(c + Vector2(0, -4) * u, 4.5 * u, PI, TAU, 12, col, w, true)
			_pg(ci, c, u, [[-8, -4], [8, -4], [9.5, 9], [-9.5, 9]], col)
			_pl(ci, c, u, [[-4, 0.5], [4, 0.5]], Color(0, 0, 0, 0.3), w)
		"menu":
			for y in [-6, 0, 6]:
				_pl(ci, c, u, [[-8, y], [8, y]], col, w)
		"back":
			_pl(ci, c, u, [[4, -8], [-4, 0], [4, 8]], col, w * 1.2)
		"next":
			_pl(ci, c, u, [[-4, -8], [4, 0], [-4, 8]], col, w * 1.2)
		"close":
			_pl(ci, c, u, [[-7, -7], [7, 7]], col, w)
			_pl(ci, c, u, [[7, -7], [-7, 7]], col, w)
		"check":
			_pl(ci, c, u, [[-8, 0], [-2.5, 6], [8, -6]], col, w * 1.3)
		"gear":
			ci.draw_arc(c, 5.2 * u, 0, TAU, 24, col, w, true)
			for i in 8:
				var a2 := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a2), sin(a2)) * 7.5 * u, c + Vector2(cos(a2), sin(a2)) * 10.5 * u, col, w * 1.3, true)
		"book":
			_pl(ci, c, u, [[0, -6], [-9, -8], [-9, 7], [0, 9], [9, 7], [9, -8], [0, -6], [0, 9]], col, w)
		"crown":
			_pg(ci, c, u, [[-9.5, 7], [-9.5, -4], [-4.5, 1.5], [0, -8], [4.5, 1.5], [9.5, -4], [9.5, 7]], col)
		"star":
			var sp := PackedVector2Array()
			for i in 10:
				var a3 := -PI * 0.5 + TAU * i / 10.0
				sp.append(c + Vector2(cos(a3), sin(a3)) * (10.5 if i % 2 == 0 else 4.6) * u)
			ci.draw_colored_polygon(sp, col)
		"sword":
			_pl(ci, c, u, [[-8, 8], [7, -7]], col, w * 1.2)
			_pl(ci, c, u, [[8, 8], [-7, -7]], col, w * 1.2)
			_pl(ci, c, u, [[-9.5, 2.5], [-3, 9]], col, w)
			_pl(ci, c, u, [[9.5, 2.5], [3, 9]], col, w)
		"horn":
			_pg(ci, c, u, [[0, -4], [7, 1], [5, 8], [0, 10.5], [-5, 8], [-7, 1]], col)
			_pg(ci, c, u, [[-6.5, -1], [-10.5, -10.5], [-2.5, -4.5]], col)
			_pg(ci, c, u, [[6.5, -1], [10.5, -10.5], [2.5, -4.5]], col)
			ci.draw_circle(c + Vector2(-2.6, 3) * u, 1.3 * u, Color(0, 0, 0, 0.55))
			ci.draw_circle(c + Vector2(2.6, 3) * u, 1.3 * u, Color(0, 0, 0, 0.55))
		"question":
			ci.draw_arc(c + Vector2(0, -3.5) * u, 4.8 * u, PI * 1.05, TAU + PI * 0.55, 14, col, w * 1.2, true)
			_pl(ci, c, u, [[0.6, 0.8], [0, 4.2]], col, w * 1.2)
			ci.draw_circle(c + Vector2(0, 8.6) * u, 1.6 * u, col)
		"coin":
			ci.draw_arc(c, 8.6 * u, 0, TAU, 28, col, w, true)
			_pl(ci, c, u, [[-3, -3], [3, -3], [3, 3], [-3, 3]], col, w * 0.9, true)
		"fire":
			_pl(ci, c, u, [[-9, 9.5], [7, 4.5]], col, w * 1.2)
			_pl(ci, c, u, [[9, 9.5], [-7, 4.5]], col, w * 1.2)
			_pg(ci, c, u, [[0.5, -11], [4.5, -5], [6, 0], [4, 4.5], [0, 6], [-4, 4.5], [-6, 0], [-3.5, -3.5]], col)
		"chest":
			_pg(ci, c, u, [[-9, -1], [9, -1], [9, 8.5], [-9, 8.5]], col)
			ci.draw_arc(c + Vector2(0, -1) * u, 9.0 * u, PI, TAU, 14, col, w, true)
			ci.draw_circle(c + Vector2(0, 2.6) * u, 2.0 * u, Color(0, 0, 0, 0.5))
		"lock":
			ci.draw_arc(c + Vector2(0, -2.5) * u, 4.8 * u, PI, TAU, 12, col, w, true)
			_pg(ci, c, u, [[-7, -2.5], [7, -2.5], [7, 9], [-7, 9]], col)
		"snow":
			for i in 3:
				var a4 := PI * i / 3.0 + PI * 0.5
				var d := Vector2(cos(a4), sin(a4))
				ci.draw_line(c - d * 10 * u, c + d * 10 * u, col, w, true)
				for sg in [-1.0, 1.0]:
					var tip: Vector2 = c + d * 6.5 * u * sg
					ci.draw_line(tip, tip + d.rotated(0.9) * 3.4 * u * sg, col, w * 0.8, true)
					ci.draw_line(tip, tip + d.rotated(-0.9) * 3.4 * u * sg, col, w * 0.8, true)
		"bolt":
			_pg(ci, c, u, [[3, -11], [-7, 1.5], [-1, 1.5], [-3.5, 11], [7.5, -2.5], [1, -2.5]], col)
		"mirror":
			var mp := PackedVector2Array()
			for i in 25:
				var a5 := TAU * i / 24.0
				mp.append(c + Vector2(cos(a5) * 6.4, sin(a5) * 8.6 - 1.5) * u)
			ci.draw_polyline(mp, col, w, true)
			_pl(ci, c, u, [[0, 7], [0, 11]], col, w)
			_pl(ci, c, u, [[-4, 11], [4, 11]], col, w)
			_pl(ci, c, u, [[-2.5, -5.5], [1.5, -1.5]], col, w * 0.8)
		"moon":
			# 초승달: 바깥 원과 안쪽 원 사이를 삼각형으로 채운다
			var n := 16
			var oc := c + Vector2(-1.5, 0) * u
			var ic := c + Vector2(3.6, 0) * u
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in n + 1:
				var f := float(i) / n
				var ao := deg_to_rad(52.0 + 256.0 * f)
				var ai := deg_to_rad(78.0 + 204.0 * f)
				var po := oc + Vector2(cos(ao), sin(ao)) * 10.0 * u
				var pi := ic + Vector2(cos(ai), sin(ai)) * 8.0 * u
				if pi.distance_to(oc) > 10.0 * u:
					pi = oc + (pi - oc).normalized() * 10.0 * u
				outer.append(po)
				inner.append(pi)
			var cols := PackedColorArray([col, col, col])
			var uvs := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
			for i in n:
				ci.draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1]]), cols, uvs)
				ci.draw_primitive(PackedVector2Array([outer[i], inner[i + 1], inner[i]]), cols, uvs)
		"poison":
			ci.draw_circle(c + Vector2(-3.5, 4) * u, 5.2 * u, col)
			ci.draw_circle(c + Vector2(5, -1) * u, 3.4 * u, col)
			ci.draw_circle(c + Vector2(-1.5, -7) * u, 2.2 * u, col)
		"shield":
			_pg(ci, c, u, [[0, -10], [8.5, -6.5], [8, 2.5], [0, 10.5], [-8, 2.5], [-8.5, -6.5]], col)
		"tower":
			_pg(ci, c, u, [[-6, 10.5], [-4, -6], [0, -11], [4, -6], [6, 10.5]], col)
			_pg(ci, c, u, [[-1.3, -2.5], [1.3, -2.5], [1.3, 1.5], [-1.3, 1.5]], Color(0, 0, 0, 0.55))
			_pg(ci, c, u, [[-1.3, 4.5], [1.3, 4.5], [1.3, 8], [-1.3, 8]], Color(0, 0, 0, 0.55))
		"calendar":
			_pl(ci, c, u, [[-8.5, -6.5], [8.5, -6.5], [8.5, 9.5], [-8.5, 9.5]], col, w, true)
			_pl(ci, c, u, [[-8.5, -1.5], [8.5, -1.5]], col, w)
			_pl(ci, c, u, [[-4, -10], [-4, -5]], col, w)
			_pl(ci, c, u, [[4, -10], [4, -5]], col, w)
		"infinity":
			ci.draw_arc(c + Vector2(-5.2, 0) * u, 4.8 * u, 0, TAU, 20, col, w, true)
			ci.draw_arc(c + Vector2(5.2, 0) * u, 4.8 * u, 0, TAU, 20, col, w, true)
		"scroll":
			_pl(ci, c, u, [[-7, -9.5], [7, -9.5], [7, 9.5], [-7, 9.5]], col, w, true)
			for y2 in [-4, 0.5, 5]:
				_pl(ci, c, u, [[-3.5, y2], [3.5, y2]], col, w * 0.8)
		"stay":
			ci.draw_arc(c, 8.6 * u, 0, TAU, 28, col, w, true)
			ci.draw_circle(c, 3.0 * u, col)
		"house":
			_pg(ci, c, u, [[0, -10.5], [10.5, -1], [-10.5, -1]], col)
			_pg(ci, c, u, [[-7.5, -1], [7.5, -1], [7.5, 9.5], [-7.5, 9.5]], col)
			_pg(ci, c, u, [[-2.2, 2.5], [2.2, 2.5], [2.2, 9.5], [-2.2, 9.5]], Color(0, 0, 0, 0.5))
		"person":
			ci.draw_circle(c + Vector2(0, -5.5) * u, 4.4 * u, col)
			_pg(ci, c, u, [[-8.5, 10], [-6, 2], [0, 0], [6, 2], [8.5, 10]], col)
		"lantern":
			ci.draw_arc(c + Vector2(0, -8) * u, 2.6 * u, PI, TAU, 8, col, w, true)
			_pg(ci, c, u, [[-6, -6.5], [6, -6.5], [7, 8], [-7, 8]], col)
			_pg(ci, c, u, [[-3, -3], [3, -3], [3.5, 5], [-3.5, 5]], Color(1, 1, 1, 0.5))
		"flag":
			_pl(ci, c, u, [[-6, -10], [-6, 10.5]], col, w * 1.2)
			_pg(ci, c, u, [[-6, -9.5], [8.5, -5.5], [-6, -0.5]], col)
		"brush":
			_pl(ci, c, u, [[8, -9], [-1.5, 1.5]], col, w * 1.3)
			_pg(ci, c, u, [[-1, -1.5], [3.5, 3], [-5, 9.5], [-8.5, 9], [-8.5, 5.5]], col)
		_:
			ci.draw_circle(c, 6 * u, col)
