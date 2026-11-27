extends Screen
## 상점: 각인 3, 유물 2, 회복·각인 지우기·되돌리기.

var hud: RunHud
var body: VBoxContainer
var stock: Dictionary = {}


func build(p: Dictionary) -> void:
	var r := Game.run
	var key := "shop_%d_%d" % [r.floor, int(p.get("node", 0))]
	if r.stats.has(key):
		stock = r.stats[key]
	else:
		var ins := Game.roll_inscriptions(3, 0, r.inscriptions)
		stock = {"insc": ins, "relic": [Game.roll_relic()], "sold": []}
		stock["relic"].append(Game.roll_relic(stock["relic"]))
		r.stats[key] = stock
	var v := UI.screen_frame(self, "")
	hud = RunHud.make(self)
	v.add_child(hud)
	v.add_child(UI.label("떠돌이 상점", 44, UI.AMBER, true))
	v.add_child(UI.label("\"기름만 있으면 뭐든 팔지.\"", 24, UI.SUB))
	body = UI.vbox(14)
	v.add_child(UI.scroll(body))
	v.add_child(UI.button("떠나기", func():
		Game.save_run()
		Game.complete_node(), 30, true))
	_fill()


func _fill() -> void:
	var r := Game.run
	hud.refresh()
	for c in body.get_children():
		c.queue_free()
	var sold: Array = stock["sold"]
	for id in stock["insc"]:
		if sold.has(id):
			continue
		var base: int = [40, 65, 95][int(UpgradeData.inscription(id)["rarity"])]
		var price := r.price(base)
		var card := UI.upgrade_card("insc", id, r.inscriptions, price)
		body.add_child(card)
		var b := UI.button("사기", _buy.bind("insc", id, price), 24, true, 60)
		b.disabled = r.oil < price
		card.get_child(0).add_child(b)
	for id in stock["relic"]:
		if id == "" or sold.has(id):
			continue
		var price2 := r.price(110)
		var card2 := UI.upgrade_card("relic", id, [], price2)
		body.add_child(card2)
		var b2 := UI.button("사기", _buy.bind("relic", id, price2), 24, true, 60)
		b2.disabled = r.oil < price2
		card2.get_child(0).add_child(b2)
	body.add_child(UI.label("서비스", 26, UI.SUB))
	var heal_p := r.price(35)
	var hb := UI.button("약초 · 체력 30%% 회복 (기름 %d)" % heal_p, _buy.bind("heal", "", heal_p), 24)
	hb.disabled = r.oil < heal_p or r.hp >= r.max_hp()
	body.add_child(hb)
	var rm_p := r.price(50)
	var rb := UI.button("각인 지우기 · 마지막 각인 제거 (기름 %d)" % rm_p, _buy.bind("remove", "", rm_p), 24)
	rb.disabled = r.oil < rm_p or r.inscriptions.is_empty()
	body.add_child(rb)
	var ud_p := r.price(45)
	var ub := UI.button("모래시계 · 되돌리기 +1 (기름 %d)" % ud_p, _buy.bind("undo", "", ud_p), 24)
	ub.disabled = r.oil < ud_p
	body.add_child(ub)


func _buy(what: String, id: String, price: int) -> void:
	var r := Game.run
	if r.oil < price:
		return
	r.oil -= price
	Save.stat_add("oil_spent", price)
	match what:
		"insc":
			Game.gain_inscription(id)
			stock["sold"].append(id)
		"relic":
			Game.gain_relic(id)
			stock["sold"].append(id)
		"heal":
			r.heal(int(ceil(r.max_hp() * 0.3)))
		"remove":
			r.inscriptions.pop_back()
			r.dirty()
			r.clamp_hp()
			r.hp = max(1, r.hp)
		"undo":
			r.undo += 1
	Sfx.play("coin")
	Game.save_run()
	_fill()
