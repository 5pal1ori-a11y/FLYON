extends Screen
## 설정: 소리, 빠른 진행, 색각 보조, 진동, 왼손 모드, 개인정보, 크레딧, 초기화.

var back := "title"


func build(p: Dictionary) -> void:
	back = p.get("back", "title")
	var v := UI.screen_frame(self, "설정", func(): Game.goto(back))
	var body := UI.vbox(16)
	v.add_child(UI.scroll(body))
	body.add_child(_slider("효과음", "sfx"))
	body.add_child(_slider("배경음악", "music"))
	body.add_child(_toggle("빠른 진행 (연출 속도 2배)", "fast"))
	body.add_child(_toggle("색각 보조 (그림자 빗금 · 글자 표시)", "colorblind"))
	body.add_child(_toggle("진동", "haptics"))
	body.add_child(_toggle("왼손 모드 (점화 버튼 왼쪽)", "left"))
	body.add_child(UI.button("튜토리얼 다시 보기", func():
		Save.set_setting("tutorial", false)
		Game.toast("다음 전투에서 안내가 다시 나옵니다"), 26))
	body.add_child(UI.button("개인정보 처리방침", func(): _privacy(), 26))
	body.add_child(UI.button("만든 이 · 라이선스", func(): _credits(), 26))
	body.add_child(UI.spacer(20))
	body.add_child(UI.button("모든 기록 초기화", func(): confirm("불씨·해금·업적·진행 중 탐험이 모두 지워집니다.\n되돌릴 수 없습니다.", "초기화", func():
		Save.reset_all()
		RunState.fac = Save.meta["facilities"]
		Game.run = null
		Game.goto("title")), 26))


func _slider(title: String, key: String) -> Control:
	var p := UI.panel(18)
	var v := UI.vbox(8)
	p.add_child(v)
	var l := UI.label("%s  %d%%" % [title, int(float(Save.setting(key, 0.7)) * 100)], 26)
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = float(Save.setting(key, 0.7))
	s.custom_minimum_size = Vector2(0, 48)
	s.value_changed.connect(func(val):
		Save.meta["settings"][key] = val
		l.text = "%s  %d%%" % [title, int(val * 100)]
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c):
		Save.save_meta()
		Sfx.play("ui_tap"))
	v.add_child(s)
	return p


func _toggle(title: String, key: String) -> Control:
	var on: bool = Save.setting(key, false)
	var b := UI.button(("● " if on else "○ ") + title, func(): pass, 26, on, 80)
	b.pressed.connect(func():
		var nv: bool = not Save.setting(key, false)
		Save.set_setting(key, nv)
		b.text = ("● " if nv else "○ ") + title
		b.add_theme_color_override("font_color", UI.AMBER if nv else UI.TEXT))
	return b


func _privacy() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.label("등불지기는 어떤 개인정보도 수집하지 않습니다.", 26, UI.AMBER, true))
	v.add_child(UI.label("· 회원가입·로그인이 없습니다.\n· 광고와 추적 도구가 없습니다.\n· 진행 기록은 이 기기 안에만 저장되며 외부로 전송되지 않습니다.\n· 앱을 지우면 기록도 함께 지워집니다.\n· 문의는 앱스토어의 개발자 연락처로 보내 주세요.", 24))
	sheet("개인정보 처리방침", v)


func _credits() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.label("등불지기", 30, UI.AMBER, true))
	v.add_child(UI.label("기획·개발: 등불지기 개발팀\n엔진: Godot Engine (MIT 라이선스)\n글꼴: 고운바탕 Gowun Batang (SIL Open Font License 1.1)\n그림·소리·음악: 코드로 직접 생성 (외부 소스 없음)", 24))
	v.add_child(UI.button("오픈소스 라이선스 전문 보기", func(): _licenses(), 24))
	sheet("만든 이", v)


func _licenses() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.label("Godot Engine", 26, UI.AMBER, true))
	v.add_child(UI.label(Engine.get_license_text(), 18, UI.SUB))
	v.add_child(UI.label("Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved.", 18, UI.SUB))
	v.add_child(UI.label("고운바탕 Gowun Batang — SIL Open Font License 1.1", 22, UI.AMBER))
	var ofl := FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	if ofl != "":
		v.add_child(UI.label(ofl, 15, UI.SUB))
	v.add_child(UI.label("Copyright 2021 The Gowun Batang Project Authors (https://github.com/yangheeryu/Gowun-Batang). 이 글꼴은 SIL Open Font License 1.1에 따라 사용합니다. 글꼴 자체를 따로 판매하지 않습니다.", 18, UI.SUB))
	v.add_child(UI.label("엔진에 포함된 구성 요소", 22, UI.AMBER))
	var info := Engine.get_license_info()
	for k in info.keys():
		v.add_child(UI.label(str(k), 20, UI.TEXT))
		v.add_child(UI.label(str(info[k]), 15, UI.SUB))
	sheet("오픈소스 라이선스", v)
