class_name Screen
extends Control
## 모든 화면의 기반. build(params)에서 내용을 만든다.

var params: Dictionary = {}


func build(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.72, 0.15)
	return dim


## 확인 창
func confirm(text: String, yes: String, on_yes: Callable, no: String = "취소") -> void:
	var dim := _dim()
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	var p := UI.panel(30)
	p.custom_minimum_size = Vector2(580, 0)
	c.add_child(p)
	var v := UI.vbox(24)
	p.add_child(v)
	v.add_child(UI.label(text, 26, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UI.hbox(14)
	v.add_child(h)
	h.add_child(UI.expand(UI.button(no, func(): dim.queue_free())))
	h.add_child(UI.expand(UI.button(yes, func():
		dim.queue_free()
		on_yes.call(), 26, true)))


## 아래에서 올라오는 정보 창
func sheet(title_text: String, body: Control) -> Control:
	var dim := _dim()
	dim.gui_input.connect(func(e):
		if UI.is_tap(e):
			dim.queue_free())
	var p := UI.panel(26)
	p.anchor_left = 0
	p.anchor_right = 1
	p.anchor_top = 1
	p.anchor_bottom = 1
	p.offset_left = 12
	p.offset_right = -12
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -12 - Game.safe_bottom
	dim.add_child(p)
	var v := UI.vbox(14)
	p.add_child(v)
	var h := UI.hbox()
	var tl := UI.title(title_text, 32, UI.AMBER)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(UI.expand(tl))
	h.add_child(UI.icon_button("close", func(): dim.queue_free(), 54, 20))
	v.add_child(h)
	v.add_child(UI.divider())
	var sc := UI.scroll(body)
	sc.custom_minimum_size = Vector2(0, min(body.get_combined_minimum_size().y + 44, 820))
	v.add_child(sc)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.15)
	return dim
