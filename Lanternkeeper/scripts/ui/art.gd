class_name Art
## 모든 캐릭터·적·지형을 코드로 그린다 (외부 그림 파일 없음).


static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


static func eyes(ci: CanvasItem, c: Vector2, gap: float, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-gap, 0), r, col)
	ci.draw_circle(c + Vector2(gap, 0), r, col)
	ci.draw_circle(c + Vector2(-gap, 0), r * 2.4, Color(col, 0.18))
	ci.draw_circle(c + Vector2(gap, 0), r * 2.4, Color(col, 0.18))


static func blob(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, n: int = 20, wob: float = 0.0, t: float = 0.0) -> void:
	var pts := []
	for i in n:
		var a := TAU * i / n
		var w := 1.0 + wob * sin(a * 3.0 + t * 2.0)
		pts.append(c + Vector2(cos(a) * rx * w, sin(a) * ry * w))
	poly(ci, pts, col)


## opts: facing(Vector2i), t(float), elite(String), alpha(float), flash(float), frozen(bool), skin(Color)
static func unit(ci: CanvasItem, kind: String, s: float, opts: Dictionary) -> void:
	var t: float = opts.get("t", 0.0)
	var f: Vector2i = opts.get("facing", Vector2i(0, 1))
	var fv := Vector2(f)
	var bob := sin(t * 2.2) * s * 0.02
	var k := s / 96.0
	var dark := Color(0.08, 0.06, 0.1)
	match kind:
		"player":
			var lantern_col: Color = opts.get("skin", Color(1.0, 0.72, 0.35))
			ci.draw_circle(Vector2(0, s * 0.3), s * 0.28, Color(0, 0, 0, 0.35))
			poly(ci, [Vector2(-22, 34) * k, Vector2(22, 34) * k, Vector2(14, -6) * k, Vector2(-14, -6) * k], Color(0.22, 0.18, 0.3))
			ci.draw_circle(Vector2(0, -14 + bob) * k, 17 * k, Color(0.25, 0.2, 0.34))
			ci.draw_circle(Vector2(0, -11 + bob) * k, 11 * k, Color(0.05, 0.04, 0.07))
			eyes(ci, Vector2(0, -11 + bob) * k, 4.5 * k, 1.8 * k, Color(1, 0.9, 0.7))
			poly(ci, [Vector2(-22, 34) * k, Vector2(-6, 34) * k, Vector2(-12, 0) * k], Color(0.17, 0.13, 0.24))
			var lp := Vector2(24, 8 + bob) * k
			ci.draw_line(Vector2(12, 2) * k, lp + Vector2(0, -8) * k, Color(0.3, 0.25, 0.2), 2.5 * k)
			ci.draw_circle(lp, 14 * k, Color(lantern_col, 0.25))
			ci.draw_rect(Rect2(lp - Vector2(6, 7) * k, Vector2(12, 14) * k), Color(0.15, 0.1, 0.08))
			ci.draw_rect(Rect2(lp - Vector2(4, 5) * k, Vector2(8, 10) * k), lantern_col)
		"beacon":
			ci.draw_circle(Vector2(0, s * 0.3), s * 0.25, Color(0, 0, 0, 0.35))
			ci.draw_rect(Rect2(Vector2(-6, -10) * k, Vector2(12, 46) * k), Color(0.3, 0.25, 0.22))
			ci.draw_circle(Vector2(0, -20) * k, 26 * k, Color(1, 0.8, 0.4, 0.18 + 0.06 * sin(t * 3)))
			ci.draw_rect(Rect2(Vector2(-12, -32) * k, Vector2(24, 24) * k), Color(0.2, 0.14, 0.1))
			ci.draw_rect(Rect2(Vector2(-8, -28) * k, Vector2(16, 16) * k), Color(1, 0.82, 0.5))
		"rat":
			ci.draw_circle(Vector2(0, 22) * k, 22 * k, Color(0, 0, 0, 0.3))
			var pts := []
			ci.draw_polyline(PackedVector2Array([Vector2(18, 14) * k, Vector2(32, 8) * k, Vector2(38, -4) * k]), dark, 3 * k, true)
			blob(ci, Vector2(0, 8 + bob) * k, 26 * k, 17 * k, Color(0.2, 0.17, 0.26))
			ci.draw_circle(Vector2(-14, -8 + bob) * k, 8 * k, Color(0.25, 0.2, 0.3))
			ci.draw_circle(Vector2(8, -8 + bob) * k, 8 * k, Color(0.25, 0.2, 0.3))
			eyes(ci, Vector2(-3, 4 + bob) * k, 7 * k, 2.6 * k, Color(1, 0.3, 0.3))
		"moth":
			var flap := 0.75 + 0.25 * sin(t * 12.0)
			blob(ci, Vector2(-18 * flap, -2 + bob * 3) * k, 18 * flap * k, 24 * k, Color(0.45, 0.42, 0.38, 0.92))
			blob(ci, Vector2(18 * flap, -2 + bob * 3) * k, 18 * flap * k, 24 * k, Color(0.45, 0.42, 0.38, 0.92))
			ci.draw_circle(Vector2(-18 * flap, -6 + bob * 3) * k, 6 * k, Color(0.25, 0.22, 0.2))
			ci.draw_circle(Vector2(18 * flap, -6 + bob * 3) * k, 6 * k, Color(0.25, 0.22, 0.2))
			blob(ci, Vector2(0, 0 + bob * 3) * k, 7 * k, 18 * k, Color(0.2, 0.18, 0.15))
			ci.draw_line(Vector2(-3, -16) * k, Vector2(-10, -30) * k, dark, 2 * k)
			ci.draw_line(Vector2(3, -16) * k, Vector2(10, -30) * k, dark, 2 * k)
			eyes(ci, Vector2(0, -10 + bob * 3) * k, 4 * k, 2.2 * k, Color(1, 0.9, 0.4))
		"mist", "mistling":
			var sc := 1.0 if kind == "mist" else 0.6
			for i in 5:
				var a := TAU * i / 5.0 + t * 0.4
				blob(ci, Vector2(cos(a), sin(a) * 0.6) * 14 * sc * k + Vector2(0, bob) * k, 18 * sc * k, 16 * sc * k, Color(0.6, 0.78, 0.74, 0.32))
			blob(ci, Vector2(0, bob) * k, 22 * sc * k, 18 * sc * k, Color(0.65, 0.82, 0.78, 0.55), 20, 0.08, t)
			eyes(ci, Vector2(0, -2 + bob) * k, 7 * sc * k, 2.6 * sc * k, Color(0.1, 0.2, 0.2))
		"bomber":
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			ci.draw_circle(Vector2(0, bob) * k, 30 * k, Color(1, 0.5, 0.15, 0.12 + 0.12 * pulse))
			blob(ci, Vector2(-14, -10 + bob) * k, 10 * k, 6 * k, Color(0.8, 0.8, 0.7, 0.6))
			blob(ci, Vector2(14, -10 + bob) * k, 10 * k, 6 * k, Color(0.8, 0.8, 0.7, 0.6))
			ci.draw_circle(Vector2(0, bob) * k, 17 * k, Color(0.25, 0.12, 0.05))
			ci.draw_circle(Vector2(0, 4 + bob) * k, 11 * k, Color(1, 0.6 + 0.3 * pulse, 0.2))
			eyes(ci, Vector2(0, -6 + bob) * k, 5 * k, 2 * k, Color(1, 1, 0.8))
		"spider":
			for i in 4:
				for sg in [-1, 1]:
					var a0 := Vector2(sg * 8, -4 + i * 5) * k
					var a1 := Vector2(sg * (26 + i % 2 * 4), -16 + i * 12 + sin(t * 5 + i) * 2) * k
					var a2 := Vector2(sg * (34 + i * 1.5), 8 + i * 8) * k
					ci.draw_polyline(PackedVector2Array([a0, a1, a2]), dark, 2.6 * k, true)
			blob(ci, Vector2(0, 8) * k, 16 * k, 18 * k, Color(0.15, 0.1, 0.18))
			ci.draw_circle(Vector2(0, -10) * k, 11 * k, Color(0.18, 0.12, 0.22))
			for e in [Vector2(-5, -13), Vector2(5, -13), Vector2(-3, -8), Vector2(3, -8)]:
				ci.draw_circle(e * k, 2 * k, Color(1, 0.25, 0.3))
		"ghost":
			var pts2 := []
			for i in 13:
				var a := PI + PI * i / 12.0
				pts2.append(Vector2(cos(a) * 22, sin(a) * 24 - 4) * k)
			for i in 7:
				var x := 22 - i * 44.0 / 6.0
				pts2.append(Vector2(x, 26 + (6 if i % 2 == 0 else 0) + sin(t * 4 + i) * 2) * k)
			for i in pts2.size():
				pts2[i] = pts2[i] + Vector2(0, bob * 2)
			poly(ci, pts2, Color(0.85, 0.9, 1.0, 0.55))
			eyes(ci, Vector2(0, -8 + bob * 2) * k, 8 * k, 4 * k, Color(0.05, 0.05, 0.1))
		"knight", "mirrorlord":
			var big := 1.3 if kind == "mirrorlord" else 1.0
			var kk := k * big
			ci.draw_circle(Vector2(0, 26) * kk, 22 * kk, Color(0, 0, 0, 0.3))
			poly(ci, [Vector2(-18, 30) * kk, Vector2(18, 30) * kk, Vector2(14, -6) * kk, Vector2(-14, -6) * kk], Color(0.55, 0.57, 0.66))
			ci.draw_circle(Vector2(0, -16) * kk, 14 * kk, Color(0.62, 0.64, 0.74))
			ci.draw_rect(Rect2(Vector2(-9, -18) * kk, Vector2(18, 4) * kk), Color(0.05, 0.05, 0.08))
			if kind == "mirrorlord":
				ci.draw_circle(Vector2(0, -16) * kk, 10 * kk, Color(0.85, 0.9, 1.0, 0.8))
				for i in 5:
					var a3 := -PI / 2 + (i - 2) * 0.35
					ci.draw_line(Vector2(cos(a3), sin(a3)) * 16 * kk + Vector2(0, -16) * kk, Vector2(cos(a3), sin(a3)) * 26 * kk + Vector2(0, -16) * kk, Color(0.9, 0.9, 1.0), 3 * kk)
			# 방패: 바라보는 방향
			var sp := fv * 24 * kk + Vector2(0, 6) * kk
			var perp := Vector2(-fv.y, fv.x)
			poly(ci, [sp + perp * 18 * kk, sp - perp * 18 * kk, sp - perp * 14 * kk + fv * 8 * kk, sp + perp * 14 * kk + fv * 8 * kk],
				Color(0.85, 0.88, 1.0))
			ci.draw_line(sp + perp * 18 * kk, sp - perp * 18 * kk, Color(1, 1, 1), 2 * kk)
		"archer":
			ci.draw_circle(Vector2(0, 26) * k, 20 * k, Color(0, 0, 0, 0.3))
			poly(ci, [Vector2(-16, 30) * k, Vector2(16, 30) * k, Vector2(0, -26) * k], Color(0.22, 0.32, 0.22))
			ci.draw_circle(Vector2(0, -12) * k, 9 * k, Color(0.05, 0.07, 0.05))
			eyes(ci, Vector2(0, -12) * k, 3.5 * k, 1.6 * k, Color(1, 0.85, 0.4))
			var bc := fv * 20 * k
			ci.draw_arc(bc, 18 * k, fv.angle() - 1.2, fv.angle() + 1.2, 12, Color(0.6, 0.45, 0.25), 3 * k, true)
		"shield":
			ci.draw_circle(Vector2(0, 26) * k, 22 * k, Color(0, 0, 0, 0.3))
			ci.draw_circle(Vector2(0, -14) * k, 11 * k, Color(0.35, 0.3, 0.28))
			poly(ci, [Vector2(-24, -6) * k, Vector2(24, -6) * k, Vector2(20, 26) * k, Vector2(0, 36) * k, Vector2(-20, 26) * k], Color(0.45, 0.38, 0.3))
			poly(ci, [Vector2(-17, -1) * k, Vector2(17, -1) * k, Vector2(14, 22) * k, Vector2(0, 29) * k, Vector2(-14, 22) * k], Color(0.62, 0.52, 0.38))
			ci.draw_line(Vector2(0, -1) * k, Vector2(0, 29) * k, Color(0.4, 0.33, 0.25), 3 * k)
		"healer":
			ci.draw_circle(Vector2(0, 26) * k, 20 * k, Color(0, 0, 0, 0.3))
			poly(ci, [Vector2(-18, 32) * k, Vector2(18, 32) * k, Vector2(9, -10) * k, Vector2(-9, -10) * k], Color(0.82, 0.8, 0.72))
			ci.draw_circle(Vector2(0, -16 + bob) * k, 10 * k, Color(0.75, 0.72, 0.65))
			ci.draw_circle(Vector2(0, 8) * k, 16 * k, Color(0.4, 1, 0.5, 0.15 + 0.1 * sin(t * 3)))
			ci.draw_rect(Rect2(Vector2(-3, -1) * k, Vector2(6, 18) * k), Color(0.3, 0.85, 0.4))
			ci.draw_rect(Rect2(Vector2(-9, 5) * k, Vector2(18, 6) * k), Color(0.3, 0.85, 0.4))
		"summoner":
			ci.draw_arc(Vector2(0, 28) * k, 30 * k, t, t + TAU * 0.8, 24, Color(0.75, 0.4, 1.0, 0.7), 2.5 * k, true)
			poly(ci, [Vector2(-20, 32) * k, Vector2(20, 32) * k, Vector2(6, -30) * k, Vector2(-6, -30) * k], Color(0.3, 0.16, 0.42))
			ci.draw_circle(Vector2(0, -14) * k, 9 * k, Color(0.06, 0.03, 0.08))
			eyes(ci, Vector2(0, -14) * k, 3.5 * k, 1.6 * k, Color(0.85, 0.55, 1.0))
			ci.draw_circle(Vector2(0, -38 + bob * 2) * k, 5 * k, Color(0.85, 0.55, 1.0))
		"charger":
			var a4 := fv.angle()
			var rot := func(v: Vector2) -> Vector2: return v.rotated(a4)
			ci.draw_circle(Vector2(0, 20) * k, 24 * k, Color(0, 0, 0, 0.3))
			poly(ci, [rot.call(Vector2(30, 0) * k), rot.call(Vector2(-14, -20) * k), rot.call(Vector2(-26, 0) * k), rot.call(Vector2(-14, 20) * k)], Color(0.3, 0.2, 0.2))
			poly(ci, [rot.call(Vector2(4, -12) * k), rot.call(Vector2(-4, -26) * k), rot.call(Vector2(-6, -10) * k)], Color(0.25, 0.15, 0.15))
			poly(ci, [rot.call(Vector2(4, 12) * k), rot.call(Vector2(-4, 26) * k), rot.call(Vector2(-6, 10) * k)], Color(0.25, 0.15, 0.15))
			ci.draw_circle(rot.call(Vector2(14, -6) * k), 2.8 * k, Color(1, 0.3, 0.2))
			ci.draw_circle(rot.call(Vector2(14, 6) * k), 2.8 * k, Color(1, 0.3, 0.2))
		"creeper":
			for i in 6:
				var a5 := TAU * i / 6.0 + sin(t + i) * 0.2
				ci.draw_line(Vector2.ZERO, Vector2(cos(a5), sin(a5)) * 36 * k, Color(0.3, 0.1, 0.4, 0.8), 4 * k, true)
			blob(ci, Vector2(0, bob) * k, 22 * k, 20 * k, Color(0.18, 0.06, 0.24), 20, 0.12, t)
			ci.draw_circle(Vector2(0, -2 + bob) * k, 6 * k, Color(0.9, 0.3, 1.0))
		"goblin":
			if opts.get("aura", true):
				ci.draw_circle(Vector2.ZERO, s * 1.4, Color(1, 0.85, 0.4, 0.07))
			ci.draw_circle(Vector2(0, 24) * k, 18 * k, Color(0, 0, 0, 0.3))
			blob(ci, Vector2(0, 12) * k, 16 * k, 18 * k, Color(0.45, 0.25, 0.2))
			ci.draw_circle(Vector2(0, -10 + bob) * k, 15 * k, Color(1, 0.78, 0.3) if opts.get("aura", true) else Color(0.4, 0.3, 0.2))
			poly(ci, [Vector2(-12, -18) * k, Vector2(-20, -36) * k, Vector2(-5, -22) * k], Color(0.85, 0.8, 0.7))
			poly(ci, [Vector2(12, -18) * k, Vector2(20, -36) * k, Vector2(5, -22) * k], Color(0.85, 0.8, 0.7))
			eyes(ci, Vector2(0, -10 + bob) * k, 5 * k, 2.2 * k, Color(0.2, 0.05, 0.0))
		"statue":
			ci.draw_circle(Vector2(0, 26) * k, 24 * k, Color(0, 0, 0, 0.35))
			poly(ci, [Vector2(-22, 34) * k, Vector2(22, 34) * k, Vector2(16, -8) * k, Vector2(-16, -8) * k], Color(0.42, 0.42, 0.44))
			poly(ci, [Vector2(-13, -8) * k, Vector2(13, -8) * k, Vector2(10, -34) * k, Vector2(-10, -34) * k], Color(0.5, 0.5, 0.52))
			ci.draw_polyline(PackedVector2Array([Vector2(-6, 0) * k, Vector2(2, 10) * k, Vector2(-2, 22) * k]), Color(0.25, 0.25, 0.27), 2 * k)
			eyes(ci, Vector2(0, -22) * k, 5 * k, 2.2 * k, Color(1, 0.4, 0.3) if not opts.get("still", false) else Color(0.35, 0.35, 0.35))
		"queen":
			for i in 7:
				var a6 := TAU * i / 7.0 + t * 0.3
				blob(ci, Vector2(cos(a6), sin(a6) * 0.6) * 24 * k, 26 * k, 22 * k, Color(0.6, 0.78, 0.74, 0.28))
			blob(ci, Vector2(0, bob) * k, 32 * k, 28 * k, Color(0.7, 0.86, 0.82, 0.6), 24, 0.08, t)
			for i in 5:
				var x2 := -16 + i * 8
				poly(ci, [Vector2(x2 - 4, -26) * k, Vector2(x2 + 4, -26) * k, Vector2(x2, -40 - (6 if i % 2 == 0 else 0)) * k], Color(0.9, 0.95, 0.9))
			eyes(ci, Vector2(0, -4 + bob) * k, 10 * k, 3.5 * k, Color(0.1, 0.25, 0.25))
		"archivist":
			ci.draw_circle(Vector2(0, 28) * k, 30 * k, Color(0.3, 0.6, 0.9, 0.2))
			poly(ci, [Vector2(-26, 36) * k, Vector2(26, 36) * k, Vector2(10, -24) * k, Vector2(-10, -24) * k], Color(0.15, 0.25, 0.4))
			ci.draw_circle(Vector2(0, -28) * k, 13 * k, Color(0.1, 0.15, 0.25))
			eyes(ci, Vector2(0, -28) * k, 5 * k, 2 * k, Color(0.6, 0.9, 1.0))
			var bp := Vector2(30, -14 + sin(t * 2) * 5) * k
			ci.draw_rect(Rect2(bp - Vector2(12, 9) * k, Vector2(24, 18) * k), Color(0.7, 0.62, 0.45))
			ci.draw_line(bp + Vector2(0, -9) * k, bp + Vector2(0, 9) * k, Color(0.4, 0.3, 0.2), 2 * k)
		"eclipse":
			for i in 16:
				var a7 := TAU * i / 16.0 + t * 0.2
				var r1 := 40 + 6 * sin(t * 3 + i)
				ci.draw_line(Vector2(cos(a7), sin(a7)) * 34 * k, Vector2(cos(a7), sin(a7)) * r1 * k, Color(1, 0.6, 0.3, 0.8), 3 * k, true)
			ci.draw_circle(Vector2.ZERO, 34 * k, Color(1, 0.55, 0.25, 0.9))
			ci.draw_circle(Vector2(4, -2) * k, 32 * k, Color(0.02, 0.01, 0.02))
			eyes(ci, Vector2(4, -4) * k, 10 * k, 3 * k, Color(1, 0.5, 0.3))
		_:
			blob(ci, Vector2.ZERO, 20 * k, 20 * k, Color(0.3, 0.3, 0.3))


## 지형 그리기 (rect는 칸 영역)
static func tile(ci: CanvasItem, t: int, r: Rect2, biome: Dictionary, time: float, cell: Vector2i) -> void:
	var c := r.get_center()
	var s := r.size.x
	var k := s / 96.0
	match t:
		Board.WALL:
			ci.draw_rect(r, Color(0.03, 0.03, 0.04))
		Board.PILLAR:
			ci.draw_circle(c + Vector2(4, 30) * k, 26 * k, Color(0, 0, 0, 0.35))
			ci.draw_rect(Rect2(c + Vector2(-20, -24) * k, Vector2(40, 52) * k), Color(0.36, 0.34, 0.33))
			ci.draw_rect(Rect2(c + Vector2(-20, -24) * k, Vector2(10, 52) * k), Color(0.44, 0.42, 0.4))
			Art._ellipse(ci, c + Vector2(0, -24) * k, 24 * k, 9 * k, Color(0.5, 0.48, 0.45))
			Art._ellipse(ci, c + Vector2(0, 28) * k, 24 * k, 8 * k, Color(0.3, 0.28, 0.27))
		Board.CRATE:
			ci.draw_circle(c + Vector2(4, 28) * k, 26 * k, Color(0, 0, 0, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-28, -24) * k, Vector2(56, 52) * k), Color(0.42, 0.28, 0.16))
			for i in 3:
				ci.draw_line(c + Vector2(-28, -24 + 17 * i + 8) * k, c + Vector2(28, -24 + 17 * i + 8) * k, Color(0.3, 0.19, 0.1), 2 * k)
			ci.draw_rect(Rect2(c + Vector2(-28, -24) * k, Vector2(56, 52) * k), Color(0.25, 0.15, 0.08), false, 3 * k)
		Board.MIRROR:
			ci.draw_rect(Rect2(c + Vector2(-22, -34) * k, Vector2(44, 64) * k), Color(0.3, 0.26, 0.2))
			Art._ellipse(ci, c + Vector2(0, -2) * k, 17 * k, 27 * k, Color(0.7, 0.78, 0.9))
			var sh := fmod(time * 0.4 + cell.x * 0.3, 1.0)
			ci.draw_line(c + Vector2(-10 + sh * 20, -20) * k, c + Vector2(-16 + sh * 20, 10) * k, Color(1, 1, 1, 0.7), 3 * k)
		Board.GLASS:
			poly(ci, [c + Vector2(-16, 30) * k, c + Vector2(16, 30) * k, c + Vector2(12, -30) * k, c + Vector2(-12, -30) * k], Color(0.6, 0.9, 1.0, 0.35))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-16, 30) * k, c + Vector2(-12, -30) * k, c + Vector2(12, -30) * k, c + Vector2(16, 30) * k]), Color(0.8, 0.95, 1.0, 0.8), 2 * k)
			ci.draw_line(c + Vector2(-4, -24) * k, c + Vector2(-6, 20) * k, Color(1, 1, 1, 0.5), 2 * k)
		Board.WATER:
			ci.draw_rect(r.grow(-1), Color(0.1, 0.2, 0.3))
			for i in 3:
				var y := c.y + (-24 + i * 22) * k
				var ph := time * 1.5 + i + cell.x
				ci.draw_line(Vector2(r.position.x + 12 * k + sin(ph) * 6 * k, y), Vector2(r.position.x + 40 * k + sin(ph) * 6 * k, y), Color(0.4, 0.6, 0.8, 0.5), 2 * k)
		Board.BRAZIER, Board.BRAZIER_OUT:
			ci.draw_circle(c + Vector2(0, 22) * k, 20 * k, Color(0, 0, 0, 0.3))
			poly(ci, [c + Vector2(-22, -2) * k, c + Vector2(22, -2) * k, c + Vector2(12, 18) * k, c + Vector2(-12, 18) * k], Color(0.3, 0.22, 0.16))
			ci.draw_rect(Rect2(c + Vector2(-4, 18) * k, Vector2(8, 14) * k), Color(0.25, 0.18, 0.12))
			if t == Board.BRAZIER:
				var fl := 1.0 + 0.15 * sin(time * 9 + cell.x)
				poly(ci, [c + Vector2(-14, -2) * k, c + Vector2(14, -2) * k, c + Vector2(0, -30 * fl) * k], Color(1, 0.55, 0.2))
				poly(ci, [c + Vector2(-7, -2) * k, c + Vector2(7, -2) * k, c + Vector2(0, -18 * fl) * k], Color(1, 0.9, 0.5))
			else:
				ci.draw_circle(c + Vector2(0, -4) * k, 5 * k, Color(0.3, 0.3, 0.3))
		Board.WEB:
			for i in 4:
				var a := PI * i / 4.0
				ci.draw_line(c - Vector2(cos(a), sin(a)) * 40 * k, c + Vector2(cos(a), sin(a)) * 40 * k, Color(0.8, 0.8, 0.85, 0.35), 1.5 * k)
			ci.draw_arc(c, 18 * k, 0, TAU, 16, Color(0.8, 0.8, 0.85, 0.3), 1.5 * k)
			ci.draw_arc(c, 32 * k, 0, TAU, 20, Color(0.8, 0.8, 0.85, 0.25), 1.5 * k)
		Board.DARK:
			ci.draw_rect(r.grow(-1), Color(0.14, 0.04, 0.2, 0.9))
			for i in 3:
				var a2 := time * 0.7 + i * 2.1
				ci.draw_arc(c, (12 + i * 10) * k, a2, a2 + 2.0, 10, Color(0.5, 0.2, 0.7, 0.4), 2 * k)
		Board.CANDLE, Board.CANDLE_LIT:
			ci.draw_rect(Rect2(c + Vector2(-6, -10) * k, Vector2(12, 30) * k), Color(0.9, 0.86, 0.75))
			ci.draw_rect(Rect2(c + Vector2(-10, 18) * k, Vector2(20, 6) * k), Color(0.4, 0.3, 0.2))
			if t == Board.CANDLE_LIT:
				var fl2 := 1.0 + 0.2 * sin(time * 11 + cell.y)
				ci.draw_circle(c + Vector2(0, -18) * k, 22 * k, Color(1, 0.75, 0.4, 0.15))
				poly(ci, [c + Vector2(-5, -10) * k, c + Vector2(5, -10) * k, c + Vector2(0, -26 * fl2) * k], Color(1, 0.8, 0.4))
			else:
				ci.draw_line(c + Vector2(0, -10) * k, c + Vector2(0, -16) * k, Color(0.15, 0.15, 0.15), 2 * k)
		Board.EXIT:
			var g := 0.5 + 0.5 * sin(time * 2)
			ci.draw_rect(r.grow(-6), Color(0.9, 0.8, 0.5, 0.15 + 0.1 * g))
			ci.draw_arc(c + Vector2(0, 10) * k, 26 * k, PI, TAU, 16, Color(1, 0.85, 0.5), 4 * k)
			ci.draw_line(c + Vector2(-26, 10) * k, c + Vector2(-26, 34) * k, Color(1, 0.85, 0.5), 4 * k)
			ci.draw_line(c + Vector2(26, 10) * k, c + Vector2(26, 34) * k, Color(1, 0.85, 0.5), 4 * k)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	blob(ci, c, rx, ry, col, 24)


## 지도 노드 아이콘
static func node_icon(ci: CanvasItem, type: String, c: Vector2, r: float, col: Color) -> void:
	match type:
		"battle":
			ci.draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, col, 4)
			ci.draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, col, 4)
		"elite":
			ci.draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, col, 5)
			ci.draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, col, 5)
			ci.draw_arc(c, r * 0.8, 0, TAU, 20, col, 3)
		"event":
			ci.draw_arc(c + Vector2(0, -r * 0.2), r * 0.28, PI, TAU + 0.8, 12, col, 4)
			ci.draw_line(c + Vector2(r * 0.12, r * 0.0), c + Vector2(0, r * 0.2), col, 4)
			ci.draw_circle(c + Vector2(0, r * 0.45), 3.5, col)
		"shop":
			ci.draw_circle(c, r * 0.45, col, false, 4)
			ci.draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.3), col, 3)
		"rest":
			poly(ci, [c + Vector2(-r * 0.35, r * 0.4), c + Vector2(r * 0.35, r * 0.4), c + Vector2(0, -r * 0.5)], col)
		"treasure":
			ci.draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.3), Vector2(r * 0.9, r * 0.6)), col, false, 4)
			ci.draw_line(c + Vector2(-r * 0.45, -r * 0.05), c + Vector2(r * 0.45, -r * 0.05), col, 3)
		"boss":
			for i in 3:
				var x := -r * 0.5 + i * r * 0.5
				poly(ci, [c + Vector2(x - r * 0.18, r * 0.2), c + Vector2(x + r * 0.18, r * 0.2), c + Vector2(x, -r * 0.45)], col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.2), Vector2(r * 1.1, r * 0.2)), col)
