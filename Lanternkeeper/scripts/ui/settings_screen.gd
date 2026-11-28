extends Screen
## 설정: 소리, 빠른 진행, 색각 보조, 진동, 왼손 모드, 개인정보, 라이선스, 초기화.

var back := "title"


class Switch:
	extends Control
	var on := false

	func _ready() -> void:
		custom_minimum_size = Vector2(72, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f09a45") if on else Color(1, 1, 1, 0.1)
		sb.set_corner_radius_all(20)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(size.x - 20 if on else 20.0, 20), 15, Color("fff4dc") if on else Color("8c869c"))


func build(p: Dictionary) -> void:
	back = p.get("back", "title")
	var v := UI.screen_frame(self, "설정", func(): Game.goto(back))
	var body := UI.vbox(12)
	v.add_child(UI.scroll(body))
	body.add_child(_slider("효과음", "sfx"))
	body.add_child(_slider("배경음악", "music"))
	body.add_child(_toggle("빠른 진행", "연출 속도를 두 배로 높입니다.", "fast"))
	body.add_child(_toggle("색각 보조", "그림자에 빗금을 긋고 상태를 글자로도 표시합니다.", "colorblind"))
	body.add_child(_toggle("진동", "", "haptics"))
	body.add_child(_toggle("왼손 모드", "점화 버튼을 왼쪽에 둡니다.", "left"))
	body.add_child(UI.spacer(6))
	body.add_child(UI.button("처음 안내 다시 보기", func():
		Save.set_setting("tutorial", false)
		Game.toast("다음 전투에서 안내가 다시 나옵니다"), 24, false, 68))
	body.add_child(UI.button("개인정보 처리방침", func(): _privacy(), 24, false, 68))
	body.add_child(UI.button("만든 이와 라이선스", func(): _credits(), 24, false, 68))
	body.add_child(UI.spacer(10))
	var rb := UI.button("모든 기록 지우기", func(): confirm("불씨, 해금, 업적, 진행 중인 탐험이 모두 지워집니다.\n되돌릴 수 없습니다.", "지우기", func():
		Save.reset_all()
		RunState.fac = Save.meta["facilities"]
		Game.run = null
		Game.goto("title")), 22, false, 60)
	UI.style_button(rb, "ghost")
	rb.add_theme_color_override("font_color", UI.RED)
	body.add_child(rb)


func _slider(name: String, key: String) -> Control:
	var p := UI.panel(18)
	var v := UI.vbox(10)
	p.add_child(v)
	var row := UI.hbox()
	row.add_child(UI.expand(UI.label(name, 24, UI.TEXT, true)))
	var val := UI.tag("%d" % int(float(Save.setting(key, 0.7)) * 100), 22, UI.AMBER, true)
	row.add_child(val)
	v.add_child(row)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = float(Save.setting(key, 0.7))
	s.custom_minimum_size = Vector2(0, 44)
	s.value_changed.connect(func(x):
		Save.meta["settings"][key] = x
		val.text = "%d" % int(x * 100)
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c):
		Save.save_meta()
		Sfx.play("ui_tap"))
	v.add_child(s)
	return p


func _toggle(name: String, desc: String, key: String) -> Control:
	var p := UI.panel(18)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := UI.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(name, 24, UI.TEXT, true))
	if desc != "":
		v.add_child(UI.label(desc, 19, UI.SUB))
	h.add_child(v)
	var sw := Switch.new()
	sw.on = Save.setting(key, false)
	h.add_child(sw)
	p.gui_input.connect(func(e):
		if UI.is_tap(e):
			sw.on = not sw.on
			sw.queue_redraw()
			Save.set_setting(key, sw.on)
			Sfx.play("ui_tap"))
	return p


func _privacy() -> void:
	var v := UI.vbox(12)
	v.add_child(UI.label("등불지기는 어떤 개인정보도 모으지 않습니다.", 24, UI.AMBER, true))
	for line in ["회원가입과 로그인이 없습니다.", "광고와 추적 도구가 없습니다.", "진행 기록은 이 기기 안에만 저장되고 밖으로 보내지 않습니다.",
			"앱을 지우면 기록도 함께 지워집니다.", "문의는 앱스토어의 개발자 연락처로 보내 주세요."]:
		var row := UI.hbox(10)
		row.add_child(Icon.make("check", 18, UI.GREEN))
		row.add_child(UI.expand(UI.label(line, 22)))
		v.add_child(row)
	sheet("개인정보 처리방침", v)


func _credits() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.title("등불지기", 30, UI.AMBER))
	v.add_child(UI.label("기획·개발: 등불지기 개발팀\n엔진: Godot Engine (MIT)\n글꼴: 고운바탕, 프리텐다드 (SIL Open Font License 1.1)\n그림·소리·음악: 코드로 직접 만들었습니다.", 22))
	v.add_child(UI.button("오픈소스 라이선스 전문", func(): _licenses(), 22, false, 64))
	sheet("만든 이", v)


func _licenses() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.label("Godot Engine", 24, UI.AMBER, true))
	v.add_child(UI.label(Engine.get_license_text(), 16, UI.SUB))
	v.add_child(UI.label("Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved.", 16, UI.SUB))
	for f in [["고운바탕 Gowun Batang", "res://assets/fonts/OFL.txt"], ["프리텐다드 Pretendard", "res://assets/fonts/Pretendard-LICENSE.txt"]]:
		v.add_child(UI.label(f[0] + "  (SIL Open Font License 1.1)", 22, UI.AMBER, true))
		var txt := FileAccess.get_file_as_string(f[1])
		if txt != "":
			v.add_child(UI.label(txt, 14, UI.SUB))
	v.add_child(UI.label("엔진에 포함된 구성 요소", 22, UI.AMBER, true))
	var info := Engine.get_license_info()
	for k in info.keys():
		v.add_child(UI.label(str(k), 18, UI.TEXT))
		v.add_child(UI.label(str(info[k]), 13, UI.SUB))
	sheet("오픈소스 라이선스", v)
