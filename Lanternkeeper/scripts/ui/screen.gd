class_name Screen
extends Control
## 모든 화면의 기반. build(params)에서 내용을 만든다.

var params: Dictionary = {}


func build(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 확인 창
func confirm(text: String, yes: String, on_yes: Callable, no: String = "취소") -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	var p := UI.panel(28, UI.PANEL, UI.AMBER_DIM)
	p.custom_minimum_size = Vector2(560, 0)
	c.add_child(p)
	var v := UI.vbox(20)
	p.add_child(v)
	v.add_child(UI.label(text, 28, UI.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UI.hbox(16)
	v.add_child(h)
	h.add_child(UI.expand(UI.button(no, func(): dim.queue_free())))
	h.add_child(UI.expand(UI.button(yes, func():
		dim.queue_free()
		on_yes.call(), 28, true)))


## 아래에서 올라오는 정보 창
func sheet(title: String, body: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			dim.queue_free())
	var p := UI.panel(24, UI.PANEL, UI.AMBER_DIM)
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
	h.add_child(UI.expand(UI.label(title, 32, UI.AMBER, true)))
	h.add_child(UI.button("닫기", func(): dim.queue_free(), 24, false, 60))
	v.add_child(h)
	var sc := UI.scroll(body)
	sc.custom_minimum_size = Vector2(0, min(body.get_combined_minimum_size().y + 20, 820))
	v.add_child(sc)
	return dim
