class_name BoardView
extends Control
## 전투 보드 렌더링 + 터치 입력 + 연출.

signal cell_pressed(cell: Vector2i)
signal cell_dragged(cell: Vector2i)
signal cell_released(cell: Vector2i)
signal player_hp(hp: int)


class DrawLayer:
	extends Control
	var fn: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		fn.call(self)


var b: Board
var cell: float = 96.0
var biome: Dictionary = {}
var t: float = 0.0
var spd: float = 1.0
var puzzle: bool = false
var colorblind: bool = false
var lantern_color := Color(1, 0.72, 0.35)
var skin_color := Color(1, 0.72, 0.35)
var prism := false

var root: Control
var tiles_layer: DrawLayer
var shadow_layer: DrawLayer
var units_layer: Control
var dark: ColorRect
var marks_layer: DrawLayer
var fx_layer: Control

var views := {}
var move_cells: Dictionary = {}
var lantern_cells: Array = []
var preview: Dictionary = {}
var preview_cells: Array = []
var locked_cells: Array = []
var shadow_sets: Array = []
var shadow_k: float = 1.0
var shadow_alpha: float = 1.0
var cast_lights: Array = []
var light_k: float = 0.0
var temp_lines: Array = []
var animating: bool = false
var show_intents: bool = true
var _press_cell := Vector2i(-1, -1)
var _last_drag := Vector2i(-1, -1)


func setup(board: Board) -> void:
	b = board
	biome = BiomeData.get_def(b.biome)
	colorblind = Save.setting("colorblind", false)
	spd = 0.55 if Save.setting("fast", false) else 1.0
	var sk: String = Save.meta.get("skin", "amber")
	prism = sk == "prism"
	skin_color = GearData.SKINS.get(sk, GearData.SKINS["amber"])["color"]
	custom_minimum_size = Vector2(cell * b.w, cell * b.h)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = custom_minimum_size
	add_child(root)
	tiles_layer = _layer(_draw_tiles)
	dark = ColorRect.new()
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.size = custom_minimum_size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/darkness.gdshader")
	dark.material = mat
	root.add_child(dark)
	shadow_layer = _layer(_draw_shadows)
	units_layer = Control.new()
	units_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	units_layer.size = custom_minimum_size
	root.add_child(units_layer)
	marks_layer = _layer(_draw_marks)
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.size = custom_minimum_size
	root.add_child(fx_layer)
	sync_units()


func _layer(fn: Callable) -> DrawLayer:
	var l := DrawLayer.new()
	l.fn = fn
	l.size = custom_minimum_size
	root.add_child(l)
	return l


func center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))


func _process(d: float) -> void:
	t += d
	var expired := []
	for l in temp_lines:
		l["life"] -= d
		if l["life"] <= 0:
			expired.append(l)
	for l in expired:
		temp_lines.erase(l)
	tiles_layer.queue_redraw()
	shadow_layer.queue_redraw()
	marks_layer.queue_redraw()
	_update_lights()


# ───────────────────── 입력 ─────────────────────
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		var c := cell_at(e.position)
		if e.pressed:
			_press_cell = c
			_last_drag = c
			if b.in_bounds(c):
				cell_pressed.emit(c)
		else:
			if b.in_bounds(c):
				cell_released.emit(c)
			_press_cell = Vector2i(-1, -1)
		accept_event()
	elif e is InputEventScreenDrag or (e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		var c2 := cell_at(e.position)
		if c2 != _last_drag and b.in_bounds(c2):
			_last_drag = c2
			cell_dragged.emit(c2)
		accept_event()


# ───────────────────── 유닛 동기화 ─────────────────────
func sync_units() -> void:
	var alive := {}
	var p := b.player()
	for u in b.units:
		if u.dead:
			continue
		alive[u.id] = true
		var v: UnitView = views.get(u.id)
		if v == null:
			v = UnitView.new()
			v.cell = cell
			v.colorblind = colorblind
			v.skin_col = skin_color
			v.prism = prism
			units_layer.add_child(v)
			views[u.id] = v
		v.from_unit(u, b)
		v.position = center(u.pos)
		v.modulate.a = 1.0
		v.scale = Vector2.ONE
		v.hidden_fog = _fog_hidden(u, p)
		v.z_index = u.pos.y
	for id in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)


func _fog_hidden(u: Unit, p: Unit) -> bool:
	return b.flags.get("fog", false) and u.is_enemy() and p != null and Board.manhattan(u.pos, p.pos) > 4 and not puzzle


# ───────────────────── 빛 ─────────────────────
func _update_lights() -> void:
	var mat: ShaderMaterial = dark.material
	var arr := PackedVector4Array()
	var tints := PackedVector4Array()
	var add := func(c: Vector2, r_cells: float, w: float, col: Color):
		if arr.size() >= 16:
			return
		arr.append(Vector4(c.x, c.y, r_cells * cell, w))
		tints.append(Vector4(col.r, col.g, col.b, 1.0))
	var p := b.player()
	if p != null and not p.dead:
		var pv: UnitView = views.get(p.id)
		var pp: Vector2 = pv.position if pv != null else center(p.pos)
		add.call(pp, 1.8, 1.0, skin_color)
	for c in b.cells_of(Board.BRAZIER):
		add.call(center(c), 1.9, 1.0, Color(1, 0.55, 0.25))
	for c in b.cells_of(Board.CANDLE_LIT):
		add.call(center(c), 1.3, 0.9, Color(1, 0.75, 0.4))
	for c in b.cells_of(Board.EXIT):
		add.call(center(c), 1.4, 0.8, Color(1, 0.9, 0.6))
	for u in b.units:
		if u.dead:
			continue
		if u.has_aura():
			add.call(center(u.pos), 1.7, 0.9, Color(1, 0.8, 0.4))
		elif u.kind == "beacon":
			add.call(center(u.pos), 1.7, 0.9, Color(1, 0.8, 0.45))
	var ambient := 0.0
	var lights: Array = []
	var k := 1.0
	if not cast_lights.is_empty():
		lights = cast_lights
		k = light_k
	elif not preview.is_empty():
		lights = preview["cast"]["lights"]
	for li in lights:
		if li.get("directional", false):
			ambient = max(ambient, 0.55 * k)
			continue
		var col: Color = Color(0.7, 0.8, 1.0) if li["mirror"] else lantern_color
		add.call(center(li["cell"]), (float(li["radius"]) + 0.6) * k, 1.0, col)
	mat.set_shader_parameter("lights", arr)
	mat.set_shader_parameter("tints", tints)
	mat.set_shader_parameter("light_count", arr.size())
	mat.set_shader_parameter("time", t)
	mat.set_shader_parameter("rect_size", custom_minimum_size)
	mat.set_shader_parameter("ambient", ambient)
	var dc: Color = biome.get("fog", Color(0.02, 0.02, 0.04))
	dc.a = 0.88 if b.flags.get("fog", false) else 0.82
	mat.set_shader_parameter("dark_color", dc)


# ───────────────────── 그리기 ─────────────────────
func _draw_tiles(ci: CanvasItem) -> void:
	var f1: Color = biome.get("floor", Color(0.1, 0.1, 0.12))
	var f2: Color = biome.get("floor2", Color(0.12, 0.12, 0.14))
	for y in b.h:
		for x in b.w:
			var c := Vector2i(x, y)
			var r := Rect2(Vector2(c) * cell, Vector2(cell, cell))
			ci.draw_rect(r, f1 if (x + y) % 2 == 0 else f2)
			ci.draw_rect(r, Color(1, 1, 1, 0.025), false, 1)
	for y in b.h:
		for x in b.w:
			var c2 := Vector2i(x, y)
			var tt := b.tile(c2)
			if tt != Board.FLOOR:
				Art.tile(ci, tt, Rect2(Vector2(c2) * cell, Vector2(cell, cell)), biome, t, c2)


func _shadow_cell(ci: CanvasItem, c: Vector2i, col: Color, hatch: bool) -> void:
	var r := Rect2(Vector2(c) * cell, Vector2(cell, cell)).grow(-5)
	ci.draw_rect(r, col)
	if hatch:
		for i in 4:
			var o := i * cell * 0.25
			ci.draw_line(r.position + Vector2(o, 0), r.position + Vector2(0, o), Color(1, 1, 1, 0.25), 2)


func _draw_shadows(ci: CanvasItem) -> void:
	var sets: Array = shadow_sets
	var k := shadow_k
	var a := shadow_alpha
	if sets.is_empty() and not preview.is_empty():
		sets = preview["cast"]["shadows"]
		k = 1.0
		a = 1.0
	if sets.is_empty() or a <= 0.01:
		return
	for s in sets:
		var n: int = s["cells"].size()
		var shown := int(ceil(n * k))
		var ally: bool = s["caster"]["team"] == Unit.TEAM_PLAYER
		for i in shown:
			var c: Vector2i = s["cells"][i]
			if ally:
				var col := Color(0.42, 0.2, 0.7, 0.55 * a) if s["dists"][i] != 99 else Color(0.32, 0.4, 0.85, 0.55 * a)
				_shadow_cell(ci, c, col, colorblind)
			else:
				var r := Rect2(Vector2(c) * cell, Vector2(cell, cell)).grow(-12)
				ci.draw_rect(r, Color(0.8, 0.2, 0.25, 0.4 * a), false, 2)


func _lantern_glyph(ci: CanvasItem, c: Vector2, alpha: float = 1.0) -> void:
	ci.draw_circle(c, cell * 0.36, Color(lantern_color, 0.25 * alpha))
	ci.draw_rect(Rect2(c - Vector2(12, 16), Vector2(24, 30)), Color(0.15, 0.1, 0.07, alpha))
	ci.draw_rect(Rect2(c - Vector2(8, 12), Vector2(16, 22)), Color(lantern_color, alpha))
	ci.draw_line(c + Vector2(-10, -18), c + Vector2(10, -18), Color(0.15, 0.1, 0.07, alpha), 4)
	var fl := 1.0 + 0.15 * sin(t * 10)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 4), c + Vector2(4, 4), c + Vector2(0, -8 * fl)]), Color(1, 1, 0.85, alpha))


func _txt(ci: CanvasItem, c: Vector2, s: String, size: int, col: Color) -> void:
	var w := UI.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := c - Vector2(w / 2, -size * 0.35)
	ci.draw_string_outline(UI.font_bold, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.85))
	ci.draw_string(UI.font_bold, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_marks(ci: CanvasItem) -> void:
	# 이동 가능 칸
	for c in move_cells.keys():
		var info: Dictionary = move_cells[c]
		var r := Rect2(Vector2(c) * cell, Vector2(cell, cell)).grow(-8)
		var col := Color(0.45, 0.7, 1.0)
		if info["type"] == "step":
			col = Color(0.7, 0.5, 1.0)
		elif info["type"] == "push" or info["type"] == "douse":
			col = Color(1, 0.8, 0.4)
		ci.draw_rect(r, Color(col, 0.13 + 0.05 * sin(t * 3)))
		ci.draw_rect(r, Color(col, 0.6), false, 2)
		if info["type"] == "push":
			_txt(ci, center(c) + Vector2(0, cell * 0.32), "밀기", 18, col)
		elif info["type"] == "douse":
			_txt(ci, center(c) + Vector2(0, cell * 0.32), "끄기", 18, col)
	# 등불 놓을 수 있는 칸
	for c in lantern_cells:
		ci.draw_circle(center(c), 5, Color(lantern_color, 0.55))
	for c in locked_cells:
		_lantern_glyph(ci, center(c))
	for c in preview_cells:
		_lantern_glyph(ci, center(c), 0.9)
	# 적의 의도
	if show_intents and not animating:
		_draw_intents(ci)
	# 미리보기 결과
	if not preview.is_empty() and not animating:
		_draw_preview(ci)
	for l in temp_lines:
		var a: float = clampf(l["life"] / l["max"], 0, 1)
		ci.draw_line(l["a"], l["b"], Color(l["col"], a), l["w"], true)


func _draw_intents(ci: CanvasItem) -> void:
	var p := b.player()
	for u in b.enemies():
		if _fog_hidden(u, p):
			continue
		var cu := center(u.pos)
		if u.frozen():
			continue
		if u.ai.has("aim"):
			var cells := EnemyAI.line_cells(b, u.pos, u.ai["aim"], int(EnemyData.get_def(u.kind).get("range", 5)))
			for c in cells:
				var r := Rect2(Vector2(c) * cell, Vector2(cell, cell)).grow(-20)
				ci.draw_rect(r, Color(1, 0.3, 0.25, 0.3 + 0.15 * sin(t * 6)))
			_txt(ci, cu + Vector2(0, -cell * 0.5), "조준", 18, UI.RED)
		if u.ai.has("charge"):
			var c: Vector2i = u.pos
			for i in 8:
				c += Vector2i(u.ai["charge"])
				if not b.in_bounds(c) or not b.walkable(c):
					break
				var pc := center(c)
				var dv := Vector2(u.ai["charge"])
				ci.draw_colored_polygon(PackedVector2Array([pc + dv * 14, pc - dv * 8 + Vector2(-dv.y, dv.x) * 12, pc - dv * 8 - Vector2(-dv.y, dv.x) * 12]), Color(1, 0.3, 0.2, 0.55))
			_txt(ci, cu + Vector2(0, -cell * 0.5), "돌진", 18, UI.RED)
		if u.ai.has("wave"):
			var row: int = int(u.ai["wave"])
			ci.draw_rect(Rect2(0, row * cell + 6, b.w * cell, cell - 12), Color(0.3, 0.6, 1.0, 0.18 + 0.08 * sin(t * 5)))
			_txt(ci, Vector2(b.w * cell * 0.5, row * cell + cell * 0.5), "물결이 온다", 22, Color(0.6, 0.85, 1.0))
		var tg := EnemyAI.target_of(b, u)
		var ai_kind: String = EnemyData.get_def(u.kind)["ai"]
		if tg != null and Board.manhattan(u.pos, tg.pos) == 1 and int(u.atk) > 0 and ai_kind != "healer":
			var dir := (center(tg.pos) - cu).normalized()
			var m := cu + dir * cell * 0.42
			ci.draw_colored_polygon(PackedVector2Array([m + dir * 12, m + Vector2(-dir.y, dir.x) * 9, m - Vector2(-dir.y, dir.x) * 9]), Color(1, 0.3, 0.25, 0.9))
		if ai_kind == "bomber" and tg != null and Board.manhattan(u.pos, tg.pos) <= 2:
			ci.draw_arc(cu, cell * 1.45, 0, TAU, 32, Color(1, 0.55, 0.2, 0.5 + 0.3 * sin(t * 8)), 3)
		if (ai_kind == "summoner" or ai_kind == "creeper") and int(u.ai.get("cd", 9)) == 1:
			_txt(ci, cu + Vector2(0, -cell * 0.5), "소환" if ai_kind == "summoner" else "잠식", 18, UI.VIOLET)
		if u.kind == "statue" and b.last_lit.has(u.pos):
			_txt(ci, cu + Vector2(0, -cell * 0.5), "멈춤", 18, UI.SUB)


func _draw_preview(ci: CanvasItem) -> void:
	var cast: Dictionary = preview["cast"]
	if puzzle:
		return
	var dmg := {}
	for h in cast["hits"]:
		if h["team"] == Unit.TEAM_ENEMY:
			dmg[h["id"]] = int(dmg.get(h["id"], 0)) + int(h["amt"])
	var killed := {}
	for k in cast["kills"]:
		killed[k["id"]] = true
	var p := b.player()
	for u in b.enemies():
		var cu := center(u.pos)
		if _fog_hidden(u, p) and not dmg.has(u.id):
			continue
		if killed.has(u.id):
			ci.draw_arc(cu, cell * 0.42, 0, TAU, 28, Color(1, 0.85, 0.3, 0.9), 3)
			_txt(ci, cu + Vector2(0, -cell * 0.18), "처치", 24, Color(1, 0.85, 0.3))
		elif dmg.has(u.id):
			_txt(ci, cu + Vector2(0, -cell * 0.18), "-%d" % dmg[u.id], 28, Color(1, 0.45, 0.4))
		if cast["frozen"].has(u.id) and not killed.has(u.id):
			_txt(ci, cu + Vector2(0, cell * 0.2), "굳음", 20, Color(0.6, 0.9, 1.0))
	for d in cast["deflects"]:
		_txt(ci, center(d["pos"]) + Vector2(0, cell * 0.2), "막힘", 20, Color(0.85, 0.85, 0.95))
	for c in cast["lit"]:
		ci.draw_arc(center(c), cell * 0.4, 0, TAU, 24, Color(1, 0.85, 0.4, 0.9), 3)
	for g in cast["shattered"]:
		_txt(ci, center(g), "깨짐", 18, Color(0.7, 0.95, 1.0))
	var en = preview.get("enemy")
	if en != null:
		for ev in en["events"]:
			if ev["type"] == "attack":
				ci.draw_line(center(ev["from"]), center(ev["to"]), Color(1, 0.3, 0.25, 0.75), 4, true)
		var pd := int(preview.get("player_dmg", 0))
		if pd > 0 and p != null:
			var pc := center(p.pos) + Vector2(cell * 0.3, -cell * 0.38)
			ci.draw_circle(pc, 20, Color(0.6, 0.08, 0.08, 0.95))
			_txt(ci, pc + Vector2(0, -4), "-%d" % pd, 22, Color(1, 0.9, 0.9))


# ───────────────────── 연출 ─────────────────────
func wait(sec: float) -> void:
	await get_tree().create_timer(sec * spd).timeout


func float_text(pos: Vector2, text: String, col: Color, size: int = 32) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	l.position = pos - Vector2(l.get_minimum_size().x / 2, cell * 0.55)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.9 * spd)
	tw.tween_property(l, "modulate:a", 0.0, 0.9 * spd).set_delay(0.35 * spd)
	tw.chain().tween_callback(l.queue_free)


func burst(pos: Vector2, col: Color, amount: int = 18, speed: float = 200.0, life: float = 0.6) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = col
	var grad := Gradient.new()
	grad.set_color(0, Color(col, 1.0))
	grad.set_color(1, Color(col, 0.0))
	p.color_ramp = grad
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


func shake(amount: float = 6.0) -> void:
	var tw := root.create_tween()
	for i in 5:
		tw.tween_property(root, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
		amount *= 0.7
	tw.tween_property(root, "position", Vector2.ZERO, 0.04)


func banner(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.font_bold)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(custom_minimum_size.x - 40, 100)
	l.position = Vector2(20, custom_minimum_size.y * 0.42)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	l.modulate.a = 0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.0 * spd)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
	Sfx.play("banner")


func line_fx(a: Vector2, bpos: Vector2, col: Color, w: float = 4.0, life: float = 0.45) -> void:
	temp_lines.append({"a": a, "b": bpos, "col": col, "w": w, "life": life * spd, "max": life * spd})


func kill_view(id: int, kind: String) -> void:
	var v: UnitView = views.get(id)
	if v == null:
		return
	views.erase(id)
	var col := Color(0.6, 0.45, 0.9)
	if kind == "player":
		col = Color(1, 0.6, 0.3)
	burst(v.position, col, 22, 220)
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "modulate:a", 0.0, 0.35 * spd)
	tw.tween_property(v, "scale", Vector2(1.4, 0.4), 0.35 * spd)
	tw.chain().tween_callback(v.queue_free)


func move_view(id: int, path: Array, step: float) -> void:
	var v: UnitView = views.get(id)
	if v == null or path.is_empty():
		return
	var tw := v.create_tween()
	for c in path:
		tw.tween_property(v, "position", center(c), step * spd).set_trans(Tween.TRANS_SINE)
	await tw.finished


func spawn_view(id: int, kind: String, pos: Vector2i, from: Vector2i) -> void:
	var u := b.unit_by_id(id)
	var v := UnitView.new()
	v.cell = cell
	v.colorblind = colorblind
	if u != null:
		v.from_unit(u, b)
	else:
		v.uid = id
		v.kind = kind
	units_layer.add_child(v)
	views[id] = v
	v.position = center(from)
	v.scale = Vector2(0.2, 0.2)
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "position", center(pos), 0.2 * spd)
	tw.tween_property(v, "scale", Vector2.ONE, 0.2 * spd)
	burst(center(pos), Color(0.7, 0.5, 1.0), 10, 120)


func play_cast(res: Dictionary) -> void:
	animating = true
	cast_lights = res["lights"]
	preview_cells = []
	for li in cast_lights:
		if li["main"] and not li.get("directional", false):
			preview_cells.append(li["cell"])
		elif li.get("directional", false):
			preview_cells.append(li["cell"])
	light_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "light_k", 1.0, 0.22 * spd)
	Sfx.play("ignite")
	for c in preview_cells:
		burst(center(c), lantern_color, 14, 140, 0.5)
	await wait(0.18)
	shadow_sets = res["shadows"]
	shadow_k = 0.0
	shadow_alpha = 1.0
	var tw2 := create_tween()
	tw2.tween_property(self, "shadow_k", 1.0, 0.3 * spd)
	await wait(0.32)
	for d in res["deflects"]:
		float_text(center(d["pos"]), "막힘", Color(0.85, 0.85, 0.95), 26)
		Sfx.play("deflect")
	for g in res["shattered"]:
		burst(center(g), Color(0.7, 0.95, 1.0), 20, 240)
		Sfx.play("shatter")
	for f in res["fx"]:
		if f["type"] == "flood":
			Sfx.play("water")
	var agg := {}
	for h in res["hits"]:
		agg[h["id"]] = int(agg.get(h["id"], 0)) + int(h["amt"])
	var hurt_player := false
	for id in agg.keys():
		var v: UnitView = views.get(id)
		if v != null:
			v.flash = 1.0
			v.hp = max(0, v.hp - int(agg[id]))
			float_text(v.position, "-%d" % agg[id], Color(1, 0.45, 0.4) if v.kind != "player" else Color(1, 0.25, 0.25), 34)
			if v.kind == "player":
				hurt_player = true
	if not agg.is_empty():
		Sfx.play("hurt" if hurt_player else "hit", randf_range(0.9, 1.1))
		UI.haptic(20)
		shake(5.0)
	for f in res["frozen"]:
		var v2: UnitView = views.get(f)
		if v2 != null:
			v2.st["frozen"] = 1
			float_text(v2.position + Vector2(0, 30), "굳음", Color(0.6, 0.9, 1.0), 24)
	if not res["frozen"].is_empty():
		Sfx.play("freeze")
	await wait(0.22)
	var i := 0
	for ch in res["chains"]:
		line_fx(center(ch["from"]), center(ch["to"]), Color(1, 0.92, 0.45), 5)
		Sfx.play("chain", 1.0 + 0.12 * i)
		i += 1
		await wait(0.09)
	for f2 in res["fx"]:
		if f2["type"] == "explode":
			burst(center(f2["pos"]), Color(1, 0.55, 0.2), 26, 260)
			Sfx.play("explode")
			shake(8.0)
	var nk := 0
	for k in res["kills"]:
		kill_view(k["id"], k["kind"])
		if k["team"] == Unit.TEAM_ENEMY:
			nk += 1
	if nk > 0:
		Sfx.play("kill", 1.0 + 0.05 * min(nk, 5))
		UI.haptic(35)
	for s in res["spawns"]:
		spawn_view(s["id"], s["kind"], s["pos"], s["from"])
	for h2 in res["heals"]:
		var v3: UnitView = views.get(h2["id"])
		if v3 != null:
			float_text(v3.position, "+%d" % h2["amt"], UI.GREEN, 30)
	if not res["heals"].is_empty():
		Sfx.play("heal")
	if not res["lit"].is_empty():
		Sfx.play("heal", 1.3)
		for c in res["lit"]:
			burst(center(c), Color(1, 0.85, 0.4), 12, 120)
	for f3 in res["fx"]:
		if f3["type"] == "revive":
			float_text(center(f3["pos"]), "부활!", Color(1, 0.8, 0.4), 34)
	await wait(0.35)
	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(self, "shadow_alpha", 0.0, 0.35 * spd)
	tw3.tween_property(self, "light_k", 0.0, 0.4 * spd)
	await tw3.finished
	shadow_sets = []
	cast_lights = []
	preview_cells = []
	sync_units()
	animating = false


func play_enemy(res: Dictionary) -> void:
	animating = true
	for ev in res["events"]:
		match ev["type"]:
			"move":
				Sfx.play("enemy_step", randf_range(0.9, 1.15))
				await move_view(ev["id"], ev["path"], 0.06 if ev.get("fast", false) else 0.11)
			"attack":
				var v: UnitView = views.get(ev["id"])
				if v != null:
					var home := center(ev["from"])
					var tgt := center(ev["to"])
					var tw := v.create_tween()
					tw.tween_property(v, "position", home.lerp(tgt, 0.4), 0.08 * spd)
					tw.tween_property(v, "position", home, 0.1 * spd)
					await wait(0.08)
			"dmg":
				var tv: UnitView = views.get(ev["id"])
				if tv != null:
					tv.flash = 1.0
					tv.hp = max(0, tv.hp - int(ev["amt"]))
					var is_p: bool = ev["team"] == Unit.TEAM_PLAYER
					var srcname := {"burn": "화상", "poison": "독", "linger": "그림자", "dark": "어둠", "frost": "서리"}
					var label := "-%d" % ev["amt"]
					if srcname.has(ev["src"]):
						label = "%s -%d" % [srcname[ev["src"]], ev["amt"]]
					float_text(tv.position, label, Color(1, 0.25, 0.25) if is_p else Color(1, 0.55, 0.4), 32 if is_p else 26)
					if is_p:
						Sfx.play("hurt")
						UI.haptic(40)
						shake(7.0)
						if tv.kind == "player":
							player_hp.emit(tv.hp)
					else:
						Sfx.play("hit", randf_range(0.85, 1.05), 0.7)
					await wait(0.12)
			"death":
				kill_view(ev["id"], ev["kind"])
				Sfx.play("kill", 0.9)
				await wait(0.1)
			"heal":
				var hv: UnitView = views.get(ev["id"])
				if hv != null:
					hv.hp += int(ev["amt"])
					float_text(hv.position, "+%d" % ev["amt"], UI.GREEN, 26)
					Sfx.play("heal", 1.1, 0.7)
			"freeze":
				var fv: UnitView = views.get(ev["id"])
				if fv != null:
					fv.st["frozen"] = 1
					float_text(fv.position, "굳음", Color(0.6, 0.9, 1.0), 22)
					Sfx.play("freeze", 1.1, 0.7)
			"frozen":
				var zv: UnitView = views.get(ev["id"])
				if zv != null:
					float_text(zv.position, "…", Color(0.6, 0.9, 1.0), 26)
			"still":
				float_text(center(ev["pos"]), "멈춤", UI.SUB, 22)
			"stun":
				float_text(center(ev["pos"]), "기절", Color(1, 0.9, 0.5), 24)
				Sfx.play("deflect", 0.7)
			"aim":
				Sfx.play("deflect", 0.5, 0.5)
			"shoot":
				var cells: Array = ev["cells"]
				if not cells.is_empty():
					line_fx(center(ev["from"]), center(cells[-1]), Color(1, 0.6, 0.3), 4, 0.35)
				Sfx.play("shoot")
				await wait(0.12)
			"explode":
				burst(center(ev["pos"]), Color(1, 0.55, 0.2), 28, 280)
				Sfx.play("explode")
				shake(9.0)
				await wait(0.12)
			"spawn":
				spawn_view(ev["id"], ev["kind"], ev["pos"], ev["from"])
				await wait(0.12)
			"darken":
				Sfx.play("ignite", 0.5, 0.6)
			"flood_tiles":
				Sfx.play("water")
			"wave":
				for c in ev["cells"]:
					burst(center(c), Color(0.4, 0.7, 1.0), 6, 120, 0.4)
				Sfx.play("water", 0.8)
				shake(6.0)
				await wait(0.15)
			"teleport":
				var pv: UnitView = views.get(ev["id"])
				if pv != null:
					burst(pv.position, Color(0.8, 0.85, 1.0), 16, 160)
					pv.position = center(ev["to"])
					burst(pv.position, Color(0.8, 0.85, 1.0), 16, 160)
				Sfx.play("deflect", 1.4)
				await wait(0.15)
			"banner":
				banner(ev["text"])
				await wait(1.1)
			"chain":
				line_fx(center(ev["from"]), center(ev["to"]), Color(1, 0.92, 0.45), 5)
				Sfx.play("chain")
			"revive":
				float_text(center(ev["pos"]), "부활!", Color(1, 0.8, 0.4), 34)
				Sfx.play("heal", 0.8)
	sync_units()
	animating = false


func anim_player_move(path: Array) -> void:
	var p := b.player()
	if p == null:
		return
	for i in path.size():
		Sfx.play("step", randf_range(0.9, 1.1))
	await move_view(p.id, path, 0.09)
