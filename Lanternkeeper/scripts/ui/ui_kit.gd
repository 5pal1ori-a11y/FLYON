class_name UI
## 디자인 언어: 먹빛 밤 위에, 고를 수 있는 것은 불 켜진 한지로.
## 글꼴은 제목·이야기에 고운바탕, 조작부·숫자에 프리텐다드.

const BG := Color("0d0c17")
const PANEL := Color("17152a")
const PANEL2 := Color("211e3a")
const LINE := Color(0.82, 0.68, 0.46, 0.26)
const BRASS := Color("cfae78")
const AMBER := Color("ffb65c")
const AMBER_DIM := Color("b9813f")
const EMBER := Color("e0762f")
const PAPER := Color("f3e6c8")
const PAPER2 := Color("e2cc9f")
const INK := Color("2a1c10")
const INK_SUB := Color("6f5a43")
const WOOD := Color("3a291b")
const TEXT := Color("efe7d6")
const SUB := Color("a39bb0")
const RED := Color("ee6a56")
const GREEN := Color("7fd3a6")
const BLUE := Color("8fb4ff")
const VIOLET := Color("a57bf5")
const RARITY := ["흔함", "희귀", "전설"]
const RARITY_COL := [Color("8a7a66"), Color("3565b0"), Color("b85c12")]
const TAG_ICON := {"fire": "flame", "frost": "snow", "poison": "poison", "chain": "bolt", "mirror": "mirror", "dark": "moon"}
const TAG_INK := {"fire": Color("b0441a"), "frost": Color("2c6c9c"), "poison": Color("2f7a35"), "chain": Color("a3730c"),
	"mirror": Color("5560a8"), "dark": Color("5d3b90")}
const BACKDROPS := {
	"": [Color("090814"), Color("151226"), Color("ff9838"), 0.15],
	"fog": [Color("060d0c"), Color("0f1f1b"), Color("6fc79d"), 0.14],
	"mirror": [Color("080818"), Color("171834"), Color("9ba3ff"), 0.14],
	"library": [Color("050b14"), Color("0d1f2e"), Color("5fb4ea"), 0.14],
	"eclipse": [Color("0f0606"), Color("23100e"), Color("ff6a3a"), 0.16],
}

static var font_reg: Font
static var font_bold: Font
static var font_title: Font
static var font_story: Font


static func fonts() -> void:
	if font_reg == null:
		font_reg = load("res://assets/fonts/Pretendard-Medium.otf")
		font_bold = load("res://assets/fonts/Pretendard-Bold.otf")
		font_title = load("res://assets/fonts/GowunBatang-Bold.ttf")
		font_story = load("res://assets/fonts/GowunBatang-Regular.ttf")


# ───────────────────── 스타일 상자 ─────────────────────
static func box(bg: Color, radius: int = 18, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = true
	return s


static func sb_ink(pad: float = 18, radius: float = 16) -> FancyBox:
	return FancyBox.make(Color(0.135, 0.125, 0.225, 0.95), Color(0.085, 0.08, 0.15, 0.95), LINE, radius, pad).with_shadow(Color(0, 0, 0, 0.38), 10, 5)


static func sb_paper(pad: float = 20, glow: bool = true) -> FancyBox:
	var f := FancyBox.make(Color("f7ecd3"), Color("e3cea2"), Color(0.45, 0.3, 0.15, 0.28), 8, pad)
	f.frame = WOOD
	f.frame_w = 3.0
	f.fibers = 16
	f.lit = 0.5
	f.pad(pad + 4, pad * 0.8 + 4)
	if glow:
		f.with_shadow(Color(1.0, 0.66, 0.26, 0.2), 20, 0)
	else:
		f.with_shadow(Color(0, 0, 0, 0.35), 8, 4)
	return f


static func sb_button(kind: String, state: String, extra_left: float = 0.0) -> StyleBox:
	var f: FancyBox
	match kind:
		"primary":
			f = FancyBox.make(Color("ffd590"), Color("f09a45"), Color(1, 0.96, 0.82, 0.7), 16, 22)
			f.gloss = 0.22
			f.with_shadow(Color(1.0, 0.58, 0.18, 0.3), 16, 3)
			if state == "pressed":
				f.top = Color("f0b566")
				f.bottom = Color("d9822f")
				f.with_shadow(Color(1.0, 0.58, 0.18, 0.18), 8, 1)
			elif state == "disabled":
				f.top = Color("35323f")
				f.bottom = Color("29262f")
				f.line = Color(1, 1, 1, 0.06)
				f.gloss = 0.0
				f.with_shadow(Color(0, 0, 0, 0), 0, 0)
		"ghost":
			f = FancyBox.make(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(0.82, 0.68, 0.46, 0.3), 16, 22)
			f.with_shadow(Color(0, 0, 0, 0), 0, 0)
			if state == "pressed":
				f.top = Color(1, 1, 1, 0.06)
				f.bottom = Color(1, 1, 1, 0.06)
			elif state == "disabled":
				f.line = Color(1, 1, 1, 0.08)
		"tab_on":
			f = FancyBox.make(Color("f7ecd3"), Color("e6d2a8"), Color(0.45, 0.3, 0.15, 0.4), 14, 14)
			f.with_shadow(Color(1.0, 0.66, 0.26, 0.22), 12, 0)
		"tab_off":
			f = FancyBox.make(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 14, 14)
			f.with_shadow(Color(0, 0, 0, 0), 0, 0)
		"round":
			f = FancyBox.make(Color(0.17, 0.16, 0.28, 0.95), Color(0.11, 0.1, 0.19, 0.95), Color(0.82, 0.68, 0.46, 0.34), 999, 6)
			f.with_shadow(Color(0, 0, 0, 0.35), 8, 3)
			if state == "pressed":
				f.top = Color(0.1, 0.095, 0.17, 0.95)
		_:
			f = FancyBox.make(Color(0.175, 0.165, 0.29, 0.96), Color(0.115, 0.105, 0.2, 0.96), Color(0.82, 0.68, 0.46, 0.36), 16, 22)
			f.gloss = 0.05
			f.with_shadow(Color(0, 0, 0, 0.36), 8, 4)
			if state == "pressed":
				f.top = Color(0.11, 0.1, 0.19, 0.96)
				f.bottom = Color(0.09, 0.085, 0.16, 0.96)
				f.line = Color(1.0, 0.71, 0.36, 0.7)
			elif state == "hover":
				f.line = Color(1.0, 0.71, 0.36, 0.55)
			elif state == "disabled":
				f.top = Color(0.1, 0.095, 0.15, 0.9)
				f.bottom = Color(0.08, 0.075, 0.12, 0.9)
				f.line = Color(1, 1, 1, 0.06)
				f.gloss = 0.0
				f.with_shadow(Color(0, 0, 0, 0), 0, 0)
	f.content_margin_left += extra_left
	return f


static func make_theme() -> Theme:
	fonts()
	var t := Theme.new()
	t.default_font = font_reg
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", sb_button("secondary", st))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font_bold)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("6d6880"))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("panel", "PanelContainer", sb_ink())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 23)
	t.set_font_size("bold_font_size", "RichTextLabel", 23)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.08), 6, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area", "HSlider", box(AMBER_DIM, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AMBER, 6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.14)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	return t


# ───────────────────── 글 ─────────────────────
static func label(text: String, size: int = 24, color: Color = TEXT, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font_bold if bold else font_reg)
	l.add_theme_constant_override("line_spacing", int(size * 0.28))
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 제목용 (고운바탕 굵게)
static func title(text: String, size: int = 40, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, false, align)
	l.add_theme_font_override("font", font_title)
	l.add_theme_constant_override("line_spacing", int(size * 0.2))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## 길어질 수 있는 제목 (줄바꿈 허용). 가로로 늘어나는 자리에만 쓴다.
static func title_wrap(text: String, size: int = 40, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := title(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 이야기 글 (고운바탕)
static func story(text: String, size: int = 26, color: Color = INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_story)
	l.add_theme_constant_override("line_spacing", int(size * 0.5))
	return l


## 한 줄로만 쓰는 짧은 글
static func tag(text: String, size: int = 20, color: Color = SUB, bold: bool = false) -> Label:
	var l := label(text, size, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func rich(bbcode: String, size: int = 23) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ───────────────────── 버튼 ─────────────────────
static func style_button(b: Button, kind: String, icon: String = "", icon_px: float = 0.0) -> void:
	fonts()
	var fs := b.get_theme_font_size("font_size")
	var isz := icon_px if icon_px > 0.0 else fs * 1.05
	var extra := (isz + 10.0) if (icon != "" and b.text != "") else 0.0
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb_button(kind, st, extra))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fc := TEXT
	var fd := Color("6d6880")
	var fp := AMBER
	match kind:
		"primary":
			fc = Color("2c1705")
			fp = Color("2c1705")
			fd = Color("7a7488")
		"tab_on":
			fc = INK
			fp = INK
		"tab_off":
			fc = SUB
			fp = TEXT
		"ghost":
			fc = BRASS
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_focus_color", fc)
	b.add_theme_color_override("font_pressed_color", fp)
	b.add_theme_color_override("font_disabled_color", fd)
	b.set_meta("kind", kind)
	if icon == "":
		return
	var ic: Icon = b.get_meta("icon_node") if b.has_meta("icon_node") else null
	if ic == null:
		ic = Icon.make(icon, isz, fc)
		b.add_child(ic)
		b.set_meta("icon_node", ic)
		b.draw.connect(func():
			var f := b.get_theme_font("font")
			var size_px := b.get_theme_font_size("font_size")
			var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x if b.text != "" else 0.0
			var group := ic.px + (10.0 + tw if b.text != "" else 0.0)
			ic.size = Vector2(ic.px, ic.px)
			ic.position = Vector2((b.size.x - group) * 0.5, (b.size.y - ic.px) * 0.5)
			var want: Color = b.get_theme_color("font_disabled_color") if b.disabled else b.get_theme_color("font_color")
			if ic.col != want:
				ic.col = want
				ic.queue_redraw())
	ic.kind = icon
	ic.px = isz
	ic.col = fc
	ic.queue_redraw()


static func press_fx(b: Button) -> void:
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(0.965, 0.965), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


static func button(text: String, cb: Callable, size: int = 26, accent: bool = false, min_h: int = 72, icon: String = "") -> Button:
	fonts()
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold)
	b.custom_minimum_size = Vector2(0, min_h)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.clip_text = false
	style_button(b, "primary" if accent else "secondary", icon)
	press_fx(b)
	b.pressed.connect(func():
		Sfx.play("ui_tap")
		cb.call())
	return b


static func icon_button(icon: String, cb: Callable, size: int = 62, icon_px: float = 26.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_button(b, "round", icon, icon_px)
	press_fx(b)
	b.pressed.connect(func():
		Sfx.play("ui_tap")
		cb.call())
	return b


## 알약 모양 탭 줄. items: [[key, 글자], ...]
static func tabs(items: Array, current: String, cb: Callable, size: int = 22) -> HBoxContainer:
	var h := hbox(8)
	var map := {}
	for it in items:
		var key: String = it[0]
		var b := Button.new()
		b.text = it[1]
		b.add_theme_font_size_override("font_size", size)
		b.add_theme_font_override("font", font_bold)
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		style_button(b, "tab_on" if key == current else "tab_off")
		b.pressed.connect(func():
			Sfx.play("ui_tap")
			tabs_select(h, key)
			cb.call(key))
		h.add_child(b)
		map[key] = b
	h.set_meta("map", map)
	return h


static func tabs_select(h: HBoxContainer, key: String) -> void:
	var map: Dictionary = h.get_meta("map")
	for k in map.keys():
		style_button(map[k], "tab_on" if k == key else "tab_off")


# ───────────────────── 상자·배치 ─────────────────────
static func panel(pad: int = 18, _bg: Color = PANEL, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := sb_ink(pad)
	sb.line = border
	p.add_theme_stylebox_override("panel", sb)
	return p


static func paper(pad: int = 20, glow: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb_paper(pad, glow))
	return p


## 아이콘 + 글자 알약. 글자는 chip_set()으로 바꾼다.
static func chip(icon: String, text: String, color: Color = TEXT, size: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := FancyBox.make(Color(0.16, 0.15, 0.26, 0.92), Color(0.105, 0.1, 0.18, 0.92), Color(color, 0.3), 999, 14).with_shadow(Color(0, 0, 0, 0.25), 6, 2)
	sb.pad(14, 7)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := hbox(7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon != "":
		h.add_child(Icon.make(icon, size * 1.05, color))
	var l := tag(text, size, color, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	p.set_meta("label", l)
	return p


static func chip_set(p: PanelContainer, text: String) -> void:
	(p.get_meta("label") as Label).text = text


static func vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func grow() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## 가는 놋쇠 선
static func divider(color: Color = LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1.5)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 단계 표시 점 (●●○)
static func pips(n: int, total: int, color: Color = AMBER, off: Color = Color(1, 1, 1, 0.14), d: float = 11.0) -> HBoxContainer:
	var h := hbox(5)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in total:
		var c := Panel.new()
		c.custom_minimum_size = Vector2(d, d)
		c.add_theme_stylebox_override("panel", box(color if i < n else off, int(d), Color(0, 0, 0, 0), 0, 0))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(c)
	return h


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 12
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 26)
	m.add_theme_constant_override("margin_left", 4)
	m.add_theme_constant_override("margin_right", 4)
	m.add_child(content)
	s.add_child(m)
	return s


static func backdrop(root: Control, biome: String = "") -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/backdrop.gdshader")
	var d: Array = BACKDROPS.get(biome, BACKDROPS[""])
	mat.set_shader_parameter("top_col", d[0])
	mat.set_shader_parameter("bot_col", d[1])
	mat.set_shader_parameter("glow_col", d[2])
	mat.set_shader_parameter("glow_amt", d[3])
	bg.material = mat
	root.add_child(bg)
	return bg


## 화면 기본 골격: 배경 + 머리줄(뒤로 가기, 제목) + 본문
static func screen_frame(root: Control, title_text: String, back: Callable = Callable(), biome: String = "") -> VBoxContainer:
	backdrop(root, biome)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 18 + Game.safe_top)
	m.add_theme_constant_override("margin_bottom", 18 + Game.safe_bottom)
	root.add_child(m)
	var v := vbox(16)
	m.add_child(v)
	if title_text != "":
		var h := hbox(14)
		if back.is_valid():
			h.add_child(icon_button("back", back))
		var tl := title(title_text, 38, TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
		v.add_child(h)
		v.set_meta("header", h)
	return v


static func tag_name(t: String) -> String:
	return UpgradeData.TAGS.get(t, {}).get("name", "")


static func tag_color(t: String) -> Color:
	return UpgradeData.TAGS.get(t, {}).get("color", SUB)


## 한지 위에서 읽히는 태그 색
static func tag_ink(t: String) -> Color:
	return TAG_INK.get(t, INK_SUB)


## 각인·유물 카드 (불 켜진 한지)
static func upgrade_card(kind: String, id: String, owned: Array = [], price: int = -1) -> PanelContainer:
	var p := paper(18)
	var h := hbox(16)
	p.add_child(h)
	var v := vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "insc":
		var d := UpgradeData.inscription(id)
		var col := tag_ink(d["tag"])
		var ic := Icon.make_badge(TAG_ICON.get(d["tag"], "star"), 72, col, PAPER)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		h.add_child(v)
		var top := hbox(8)
		var nm := title_wrap(d["name"], 28, INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var r := int(d["rarity"])
		var rl := tag(RARITY[r], 19, RARITY_COL[r], true)
		rl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(rl)
		v.add_child(top)
		v.add_child(label(d["desc"], 23, INK))
		var cnt := 0
		for o in owned:
			var od := UpgradeData.inscription(o)
			if not od.is_empty() and od["tag"] == d["tag"]:
				cnt += 1
		var goal := 3 if cnt < 3 else 5
		var foot := hbox(8)
		foot.add_child(tag(tag_name(d["tag"]) + " 세트", 19, col, true))
		foot.add_child(pips(min(cnt + 1, goal), goal, col, Color(0.3, 0.2, 0.1, 0.18), 10))
		v.add_child(foot)
	else:
		var rd := UpgradeData.relic(id)
		var curse: bool = rd.get("curse", false)
		var col2 := Color("a02a1c") if curse else Color("8a5a12")
		var ic2 := Icon.make_badge("horn" if curse else "star", 72, col2, PAPER)
		ic2.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic2)
		h.add_child(v)
		var top2 := hbox(8)
		var nm2 := title_wrap(rd["name"], 28, INK)
		nm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top2.add_child(nm2)
		var kl := tag("저주 유물" if curse else "유물", 19, col2, true)
		kl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top2.add_child(kl)
		v.add_child(top2)
		v.add_child(label(rd["desc"], 23, INK))
	if price >= 0:
		p.set_meta("price", price)
	p.set_meta("body", v)
	return p


## 누를 수 있는 선택 줄: 아이콘 + 제목 + 설명
static func option(icon: String, col: Color, head: String, body: String, cb: Callable, disabled: bool = false) -> PanelContainer:
	var p := panel(18)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := hbox(16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := Icon.make_badge(icon, 60, Color(col, 0.18), col)
	h.add_child(ic)
	var v := vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(title_wrap(head, 27, TEXT))
	if body != "":
		v.add_child(label(body, 20, SUB))
	h.add_child(v)
	h.add_child(Icon.make("next", 22, Color(BRASS, 0.7)))
	if disabled:
		p.modulate = Color(1, 1, 1, 0.4)
	else:
		p.gui_input.connect(func(e):
			if is_tap(e):
				Sfx.play("ui_confirm")
				cb.call())
	return p


## 왼쪽 이름, 오른쪽 값
static func stat_row(name: String, value: String, name_col: Color = INK_SUB, value_col: Color = INK, size: int = 24) -> HBoxContainer:
	var h := hbox(10)
	h.add_child(expand(label(name, size, name_col)))
	h.add_child(tag(value, size, value_col, true))
	return h


## 카드를 하나씩 불 켜듯 드러낸다
static func light_up(cards: Array, delay: float = 0.12) -> void:
	var i := 0
	for c in cards:
		var node: CanvasItem = c
		node.modulate = Color(0.22, 0.2, 0.3, 1.0)
		var tw := node.create_tween()
		tw.tween_interval(0.08 + delay * i)
		tw.tween_callback(func(): Sfx.play("ui_tap", 1.0 + 0.12 * i, 0.5))
		tw.tween_property(node, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_SINE)
		i += 1


static func is_tap(e: InputEvent) -> bool:
	return (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)


static func haptic(ms: int = 18) -> void:
	if Save.setting("haptics", true):
		Input.vibrate_handheld(ms)
