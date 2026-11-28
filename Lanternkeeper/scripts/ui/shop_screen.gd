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
	var v := UI.screen_frame(self, "", Callable(), r.biome())
	hud = RunHud.make(self)
	v.add_child(hud)
	var head := UI.vbox(2)
	head.add_child(UI.title("떠돌이 상점", 40, Color("ffd9a0")))
	head.add_child(UI.story("\"기름만 있으면 뭐든 팔지.\"", 22, UI.SUB))
	v.add_child(head)
	body = UI.vbox(14)
	v.add_child(UI.scroll(body))
	v.add_child(UI.button("상점을 떠난다", func():
		Game.save_run()
		Game.complete_node(), 28, true, 84, "next"))
	_fill()


func _price_row(card: PanelContainer, what: String, id: String, price: int) -> void:
	var r := Game.run
	var row := UI.hbox(8)
	row.add_child(Icon.make("oil", 22, Color("a3600c")))
	row.add_child(UI.tag(str(price), 24, UI.INK, true))
	row.add_child(UI.grow())
	var b := UI.button("산다", _buy.bind(what, id, price), 22, true, 52)
	b.custom_minimum_size.x = 130
	b.disabled = r.oil < price
	row.add_child(b)
	(card.get_meta("body") as VBoxContainer).add_child(row)


func _service(icon: String, col: Color, head: String, what: String, price: int, disabled: bool) -> void:
	var p := UI.panel(16)
	var h := UI.hbox(14)
	p.add_child(h)
	h.add_child(Icon.make_badge(icon, 48, Color(col, 0.18), col))
	h.add_child(UI.expand(UI.label(head, 22, UI.TEXT, true)))
	var b := UI.button(str(price), _buy.bind(what, "", price), 22, true, 52, "oil")
	b.custom_minimum_size.x = 130
	b.disabled = disabled or Game.run.oil < price
	h.add_child(b)
	body.add_child(p)


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
		var card := UI.upgrade_card("insc", id, r.inscriptions)
		_price_row(card, "insc", id, r.price(base))
		body.add_child(card)
	for id in stock["relic"]:
		if id == "" or sold.has(id):
			continue
		var card2 := UI.upgrade_card("relic", id)
		_price_row(card2, "relic", id, r.price(110))
		body.add_child(card2)
	_service("heart", UI.RED, "약초  체력 30% 회복", "heal", r.price(35), r.hp >= r.max_hp())
	_service("close", UI.SUB, "마지막 각인 지우기", "remove", r.price(50), r.inscriptions.is_empty())
	_service("undo", UI.BLUE, "모래시계  되돌리기 +1", "undo", r.price(45), false)


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
