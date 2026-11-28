extends Screen
## 보상: 각인 고르기(전투), 유물(엘리트·보스), 보물 방.

var mode := "battle"
var body: VBoxContainer
var steps: Array = []
var choices: Array = []
var step_kind := ""
var hud: RunHud


func build(p: Dictionary) -> void:
	mode = p.get("mode", "battle")
	var v := UI.screen_frame(self, "", Callable(), Game.run.biome())
	hud = RunHud.make(self)
	v.add_child(hud)
	var names := {"battle": "전리품", "elite": "엘리트의 전리품", "boss": "보스의 보물", "treasure": "보물 상자"}
	var head := UI.hbox(12)
	var tl := UI.title(names.get(mode, "보상"), 40, Color("ffd9a0"))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if int(p.get("oil", 0)) > 0:
		head.add_child(UI.chip("oil", "+%d" % int(p["oil"]), UI.AMBER, 22))
		Sfx.play("coin")
	v.add_child(head)
	match mode:
		"battle":
			steps = ["insc"]
		"elite":
			steps = ["insc", "relic"]
		"boss":
			steps = ["insc", "relic"]
			var healed := Game.run.heal(int(ceil(Game.run.max_hp() * 0.3)))
			if healed > 0:
				v.add_child(UI.label("숨을 고르며 체력 %d을 되찾았다." % healed, 21, UI.GREEN))
		"treasure":
			steps = ["relic"]
			Game.run.add_oil(25)
	body = UI.vbox(16)
	v.add_child(UI.scroll(body))
	_next()


func _next() -> void:
	hud.refresh()
	for c in body.get_children():
		c.queue_free()
	if steps.is_empty():
		Game.save_run()
		Game.complete_node()
		return
	step_kind = steps.pop_front()
	if step_kind == "insc":
		_insc_step()
	else:
		_relic_step()


func _pick(card: PanelContainer, cb: Callable) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.gui_input.connect(func(e):
		if UI.is_tap(e):
			cb.call())


func _insc_step() -> void:
	var r := Game.run
	var n := 3 + int(r.mods().get("reward_choices", 0))
	choices = Game.roll_inscriptions(n, 1 if mode != "battle" else 0, r.inscriptions)
	body.add_child(UI.label("등불에 새길 각인을 하나 고르세요.", 22, UI.SUB))
	var cards := []
	for id in choices:
		var card := UI.upgrade_card("insc", id, r.inscriptions)
		_pick(card, func():
			Sfx.play("ui_confirm")
			Game.gain_inscription(id)
			_next())
		body.add_child(card)
		cards.append(card)
	UI.light_up(cards)
	var h := UI.hbox(12)
	if r.rerolls > 0:
		var rb := UI.button("다시 뽑기 %d" % r.rerolls, func():
			r.rerolls -= 1
			steps.push_front("insc")
			_next(), 22, false, 64, "undo")
		UI.style_button(rb, "ghost", "undo")
		h.add_child(UI.expand(rb))
	var sb := UI.button("받지 않고 기름 10", func():
		r.add_oil(10)
		_next(), 22, false, 64, "oil")
	UI.style_button(sb, "ghost", "oil")
	h.add_child(UI.expand(sb))
	body.add_child(h)


func _relic_step() -> void:
	var a := Game.roll_relic()
	var b := Game.roll_relic([a])
	choices = [a, b]
	if a == "":
		body.add_child(UI.label("남은 유물이 없어 기름 40을 대신 챙깁니다.", 22, UI.SUB))
		body.add_child(UI.button("계속", func():
			Game.run.add_oil(40)
			_next(), 28, true))
		return
	body.add_child(UI.label("가져갈 유물을 하나 고르세요.", 22, UI.SUB))
	var cards := []
	for id in choices:
		if id == "":
			continue
		var card := UI.upgrade_card("relic", id)
		_pick(card, func():
			Sfx.play("coin")
			Game.gain_relic(id)
			_next())
		body.add_child(card)
		cards.append(card)
	UI.light_up(cards)
