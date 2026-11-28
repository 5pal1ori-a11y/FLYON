class_name FancyBox
extends StyleBox
## 위아래 그러데이션, 가는 테두리, 그림자·빛 번짐, 한지 결, 나무 창틀을 그리는 스타일 상자.

var top := Color(0.13, 0.12, 0.22, 0.94)
var bottom := Color(0.085, 0.08, 0.15, 0.94)
var line := Color(0.82, 0.68, 0.46, 0.24)
var line_w := 1.5
var radius := 16.0
var shadow := Color(0, 0, 0, 0.4)
var shadow_size := 10
var shadow_y := 5.0
var gloss := 0.0
var fibers := 0
var frame := Color(0, 0, 0, 0)
var frame_w := 0.0
var lit := 0.0

var _sb := StyleBoxFlat.new()


static func make(top_c: Color, bottom_c: Color, line_c: Color, rad: float, pad: float) -> FancyBox:
	var f := FancyBox.new()
	f.top = top_c
	f.bottom = bottom_c
	f.line = line_c
	f.radius = rad
	f.pad(pad, pad * 0.72)
	return f


func pad(h: float, v: float) -> FancyBox:
	content_margin_left = h
	content_margin_right = h
	content_margin_top = v
	content_margin_bottom = v
	return self


func with_shadow(c: Color, size: int, y: float) -> FancyBox:
	shadow = c
	shadow_size = size
	shadow_y = y
	return self


func _outline(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var seg := 6
	var centers := [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	for ci in 4:
		var a0 := PI + ci * PI * 0.5
		for i in seg + 1:
			var a := a0 + PI * 0.5 * i / seg
			pts.append(centers[ci] + Vector2(cos(a), sin(a)) * r)
	return pts


func _flat(ci: RID, rect: Rect2, border: Color, w: float, r: float) -> void:
	_sb.draw_center = false
	_sb.shadow_size = 0
	_sb.border_color = border
	_sb.set_border_width_all(int(ceil(w)))
	_sb.set_corner_radius_all(int(r))
	_sb.anti_aliasing = true
	_sb.draw(ci, rect)


func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x < 2 or rect.size.y < 2:
		return
	if shadow_size > 0 and shadow.a > 0.0:
		_sb.draw_center = false
		_sb.set_border_width_all(0)
		_sb.set_corner_radius_all(int(radius))
		_sb.shadow_color = shadow
		_sb.shadow_size = shadow_size
		_sb.shadow_offset = Vector2(0, shadow_y)
		_sb.draw(ci, rect)
	var pts := _outline(rect, radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(ci, pts, cols)
	if lit > 0.0:
		# 뒤에서 불을 밝힌 듯 가운데가 환하다
		var c := rect.get_center()
		var n := 20
		var rp := PackedVector2Array([c])
		var rc := PackedColorArray([Color(1, 0.97, 0.85, lit)])
		var idx := PackedInt32Array()
		for i in n:
			var a := TAU * i / n
			rp.append(c + Vector2(cos(a) * rect.size.x * 0.48, sin(a) * rect.size.y * 0.48))
			rc.append(Color(1, 0.97, 0.85, 0.0))
			idx.append(0)
			idx.append(1 + i)
			idx.append(1 + (i + 1) % n)
		RenderingServer.canvas_item_add_triangle_array(ci, idx, rp, rc)
	if fibers > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.size.x) * 131 + int(rect.size.y) * 17 + fibers
		for i in fibers:
			var a := Vector2(rng.randf_range(rect.position.x + 10, rect.end.x - 10), rng.randf_range(rect.position.y + 8, rect.end.y - 8))
			var ang := rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
			var b := a + Vector2(cos(ang), sin(ang)) * rng.randf_range(10, 34)
			b.x = clampf(b.x, rect.position.x + 6, rect.end.x - 6)
			b.y = clampf(b.y, rect.position.y + 6, rect.end.y - 6)
			var fc := Color(0.35, 0.22, 0.1, 0.07) if i % 3 != 0 else Color(1, 1, 1, 0.22)
			RenderingServer.canvas_item_add_line(ci, a, b, fc, 1.2, true)
	if gloss > 0.0:
		var g := Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, rect.size.y * 0.5))
		var gp := _outline(g, maxf(2.0, radius - 3))
		var gc := PackedColorArray()
		for p in gp:
			gc.append(Color(1, 1, 1, gloss * (1.0 - clampf((p.y - g.position.y) / g.size.y, 0.0, 1.0))))
		RenderingServer.canvas_item_add_polygon(ci, gp, gc)
	if frame_w > 0.0:
		_flat(ci, rect, frame, frame_w, radius)
		if line.a > 0.0:
			_flat(ci, rect.grow(-(frame_w + 3.0)), line, line_w, maxf(1.0, radius - frame_w - 2.0))
	elif line.a > 0.0 and line_w > 0.0:
		_flat(ci, rect, line, line_w, radius)
