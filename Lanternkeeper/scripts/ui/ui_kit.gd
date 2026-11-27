class_name UI
## 공통 색, 테마, 위젯 생성 도우미.

const BG := Color(0.043, 0.043, 0.07)
const PANEL := Color(0.09, 0.085, 0.12)
const PANEL2 := Color(0.13, 0.12, 0.165)
const LINE := Color(0.32, 0.27, 0.22)
const AMBER := Color(1.0, 0.72, 0.38)
const AMBER_DIM := Color(0.75, 0.5, 0.28)
const TEXT := Color(0.94, 0.9, 0.84)
const SUB := Color(0.66, 0.61, 0.56)
const RED := Color(1.0, 0.38, 0.35)
const GREEN := Color(0.5, 0.92, 0.55)
const BLUE := Color(0.5, 0.75, 1.0)
const VIOLET := Color(0.62, 0.42, 0.95)
const RARITY := ["흔함", "희귀", "전설"]
const RARITY_COL := [Color(0.75, 0.72, 0.68), Color(0.5, 0.75, 1.0), Color(1.0, 0.72, 0.3)]

static var font_reg: Font
static var font_bold: Font


static func fonts() -> void:
	if font_reg == null:
		font_reg = load("res://assets/fonts/GowunBatang-Regular.ttf")
		font_bold = load("res://assets/fonts/GowunBatang-Bold.ttf")


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


static func make_theme() -> Theme:
	fonts()
	var t := Theme.new()
	t.default_font = font_reg
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL2, 18, LINE, 2, 20))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(0.06), 18, AMBER_DIM, 2, 20))
	t.set_stylebox("pressed", "Button", box(PANEL2.darkened(0.2), 18, AMBER, 2, 20))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", box(PANEL.darkened(0.1), 18, Color(0.2, 0.2, 0.2), 2, 20))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.4))
	t.set_font_size("font_size", "Button", 28)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 20, LINE, 1, 18))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 25)
	t.set_font_size("bold_font_size", "RichTextLabel", 25)
	var grab := box(AMBER, 12)
	t.set_stylebox("slider", "HSlider", box(PANEL2, 6, LINE, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(AMBER_DIM, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AMBER, 6))
	t.set_stylebox("panel", "TooltipPanel", grab)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	return t


static func label(text: String, size: int = 26, color: Color = TEXT, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rich(bbcode: String, size: int = 25) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, cb: Callable, size: int = 28, accent: bool = false, min_h: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	if accent:
		b.add_theme_stylebox_override("normal", box(Color(0.32, 0.2, 0.1), 18, AMBER, 2, 20))
		b.add_theme_stylebox_override("hover", box(Color(0.38, 0.24, 0.12), 18, AMBER, 3, 20))
		b.add_theme_stylebox_override("pressed", box(Color(0.25, 0.15, 0.08), 18, AMBER, 3, 20))
		b.add_theme_color_override("font_color", AMBER)
	b.pressed.connect(func():
		Sfx.play("ui_tap")
		cb.call())
	return b


static func panel(pad: int = 18, bg: Color = PANEL, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 20, border, 1, pad))
	return p


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


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 12
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## 화면 기본 골격: 제목 줄 + 본문 영역
static func screen_frame(root: Control, title: String, back: Callable = Callable()) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 16 + Game.safe_top)
	m.add_theme_constant_override("margin_bottom", 16 + Game.safe_bottom)
	root.add_child(m)
	var v := vbox(16)
	m.add_child(v)
	if title != "":
		var h := hbox(12)
		if back.is_valid():
			var bb := button("‹", back, 40, false, 72)
			bb.custom_minimum_size = Vector2(84, 72)
			h.add_child(bb)
		var tl := label(title, 40, AMBER, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
		v.add_child(h)
	return v


static func tag_name(tag: String) -> String:
	return UpgradeData.TAGS.get(tag, {}).get("name", "")


static func tag_color(tag: String) -> Color:
	return UpgradeData.TAGS.get(tag, {}).get("color", SUB)


## 각인/유물 카드
static func upgrade_card(kind: String, id: String, owned: Array = [], price: int = -1) -> PanelContainer:
	var p := panel(18)
	var v := vbox(6)
	p.add_child(v)
	if kind == "insc":
		var d := UpgradeData.inscription(id)
		var col := tag_color(d["tag"])
		p.add_theme_stylebox_override("panel", box(PANEL, 20, col.darkened(0.3), 2, 18))
		var h := hbox(8)
		h.add_child(expand(label(d["name"], 30, col, true)))
		var rl := label(RARITY[int(d["rarity"])], 22, RARITY_COL[int(d["rarity"])])
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(rl)
		v.add_child(h)
		v.add_child(label(d["desc"], 24, TEXT))
		var cnt := 0
		for o in owned:
			var od := UpgradeData.inscription(o)
			if not od.is_empty() and od["tag"] == d["tag"]:
				cnt += 1
		var next := 3 if cnt + 1 <= 3 else 5
		var info := "%s 각인 · 모으면 %d/%d" % [tag_name(d["tag"]), min(cnt + 1, next), next]
		v.add_child(label(info, 21, SUB))
	else:
		var r := UpgradeData.relic(id)
		var curse: bool = r.get("curse", false)
		var col2 := RED if curse else AMBER
		p.add_theme_stylebox_override("panel", box(PANEL, 20, col2.darkened(0.35), 2, 18))
		v.add_child(label(("저주 유물 · " if curse else "유물 · ") + r["name"], 30, col2, true))
		v.add_child(label(r["desc"], 24, TEXT))
	if price >= 0:
		v.add_child(label("기름 %d" % price, 24, AMBER))
	return p


static func haptic(ms: int = 18) -> void:
	if Save.setting("haptics", true):
		Input.vibrate_handheld(ms)
