extends Screen
## 보상: 각인 고르기(전투), + 유물(엘리트·보스), 보물 방.

var mode := "battle"
var body: VBoxContainer
var steps: Array = []
var choices: Array = []
var selected := ""
var hud: RunHud


func build(p: Dictionary) -> void:
	mode = p.get("mode", "battle")
	var v := UI.screen_frame(self, "")
	hud = RunHud.make(self)
	v.add_child(hud)
	var title := {"battle": "전리품", "elite": "엘리트의 전리품", "boss": "보스의 보물", "treasure": "보물 상자"}
	v.add_child(UI.label(title.get(mode, "보상"), 44, UI.AMBER, true))
	if int(p.get("oil", 0)) > 0:
		v.add_child(UI.label("기름 +%d" % int(p["oil"]), 26, UI.AMBER))
		Sfx.play("coin")
	body = UI.vbox(16)
	v.add_child(UI.scroll(body))
	match mode:
		"battle":
			steps = ["insc"]
		"elite":
			steps = ["insc", "relic"]
		"boss":
			steps = ["insc", "relic"]
			var healed := Game.run.heal(int(ceil(Game.run.max_hp() * 0.3)))
			if healed > 0:
				v.add_child(UI.label("보스를 쓰러뜨리고 숨을 고른다 · 체력 +%d" % healed, 24, UI.GREEN))
		"treasure":
			steps = ["relic"]
			Game.run.add_oil(25)
	_next()


func _next() -> void:
	hud.refresh()
	for c in body.get_children():
		c.queue_free()
	if steps.is_empty():
		Game.save_run()
		Game.complete_node()
		return
	var step: String = steps.pop_front()
	if step == "insc":
		_insc_step()
	else:
		_relic_step()


func _insc_step() -> void:
	var r := Game.run
	var n := 3 + int(r.mods().get("reward_choices", 0))
	choices = Game.roll_inscriptions(n, 1 if mode != "battle" else 0, r.inscriptions)
	body.add_child(UI.label("각인 하나를 새긴다", 28, UI.TEXT))
	for id in choices:
		var card := UI.upgrade_card("insc", id, r.inscriptions)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e): _card_input(e, id))
		body.add_child(card)
	var h := UI.hbox(12)
	if r.rerolls > 0:
		h.add_child(UI.expand(UI.button("다시 뽑기 (%d)" % r.rerolls, func():
			r.rerolls -= 1
			steps.push_front("insc")
			_next(), 24)))
	h.add_child(UI.expand(UI.button("건너뛰기 (기름 +10)", func():
		r.add_oil(10)
		_next(), 24)))
	body.add_child(h)


func _card_input(e: InputEvent, id: String) -> void:
	var released: bool = (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if not released:
		return
	Sfx.play("ui_confirm")
	Game.gain_inscription(id)
	_next()


func _relic_step() -> void:
	var a := Game.roll_relic()
	var b := Game.roll_relic([a])
	body.add_child(UI.label("유물 하나를 고른다", 28, UI.TEXT))
	for id in [a, b]:
		if id == "":
			continue
		var card := UI.upgrade_card("relic", id)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e):
			var released: bool = (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
			if released:
				Sfx.play("coin")
				Game.gain_relic(id)
				_next())
		body.add_child(card)
	if a == "":
		body.add_child(UI.label("남은 유물이 없다. 대신 기름을 챙긴다.", 24, UI.SUB))
		body.add_child(UI.button("계속", func():
			Game.run.add_oil(40)
			_next(), 28, true))
