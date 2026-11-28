extends Screen
## 휴식처: 모닥불 곁에서 하나만 고른다.

var hud: RunHud


class FireArt:
	extends Control
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 300)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 60)
		var fl := 1.0 + 0.06 * sin(t * 6.3) + 0.04 * sin(t * 10.1)
		for i in 22:
			draw_circle(c + Vector2(0, -30), 260.0 * fl * (i + 1) / 22.0, Color(1, 0.55, 0.2, 0.022))
		draw_line(c + Vector2(-64, 16), c + Vector2(52, -8), Color("3a2415"), 16, true)
		draw_line(c + Vector2(64, 16), c + Vector2(-52, -8), Color("2c1b10"), 16, true)
		var flames := [[Color("ff7a24"), 58.0, 150.0, 7.0], [Color("ffb03a"), 38.0, 104.0, 9.0], [Color("fff0b0"), 20.0, 60.0, 12.0]]
		for f in flames:
			var w: float = f[1]
			var h: float = f[2] * fl
			var sway: float = sin(t * f[3]) * 8.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w, 0), c + Vector2(-w * 0.6, -h * 0.45), c + Vector2(sway, -h),
				c + Vector2(w * 0.6, -h * 0.45), c + Vector2(w, 0), c + Vector2(0, 14)]), f[0])
		for i in 9:
			var ph := fmod(t * 0.35 + i * 0.11, 1.0)
			draw_circle(c + Vector2(sin(i * 2.4 + t) * 46, -60 - ph * 190), 2.6, Color(1, 0.7, 0.3, 0.7 * (1.0 - ph)))
		# 곁에 앉은 등불지기
		var p := c + Vector2(-170, 20)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 0), p + Vector2(30, 0), p + Vector2(16, -52), p + Vector2(-16, -52)]), Color("07070d"))
		draw_circle(p + Vector2(4, -64), 17, Color("07070d"))
		draw_arc(p + Vector2(4, -64), 17, -0.9, 0.9, 10, Color(1, 0.6, 0.3, 0.6), 2.5, true)
		draw_line(p + Vector2(30, 0), p + Vector2(16, -52), Color(1, 0.6, 0.3, 0.45), 2.5, true)


func build(_p: Dictionary) -> void:
	var r := Game.run
	var v := UI.screen_frame(self, "", Callable(), r.biome())
	hud = RunHud.make(self)
	v.add_child(hud)
	v.add_child(FireArt.new())
	v.add_child(UI.title("모닥불 곁에서", 44, Color("ffd9a0"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("잠시 숨을 고른다. 하나만 할 수 있다.", 22, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(6))
	var m := r.mods()
	var pct := 35 + int(m.get("rest_heal_bonus", 0))
	var amount: int = min(int(ceil(r.max_hp() * pct / 100.0)), r.max_hp() - r.hp)
	var no_heal := int(m.get("no_rest_heal", 0)) > 0
	var heal_desc := "체력 %d을 되찾는다." % amount
	if no_heal:
		heal_desc = "저주 때문에 쉬어도 낫지 않는다."
	elif r.hp >= r.max_hp():
		heal_desc = "체력이 이미 가득하다."
	v.add_child(UI.option("heart", UI.RED, "쉰다", heal_desc, func():
		r.heal(amount)
		Sfx.play("heal")
		_done(), no_heal or r.hp >= r.max_hp()))
	v.add_child(UI.option("moon", UI.VIOLET, "명상한다", "최대 체력이 1 늘어난다.", func():
		r.extra_max_hp += 1
		r.hp += 1
		_done()))
	for id in r.relics:
		if UpgradeData.relic(id).get("curse", false):
			var cid: String = id
			v.add_child(UI.option("flame", UI.AMBER, "저주를 태운다", UpgradeData.relic(cid)["name"] + "을(를) 없앤다.", func():
				r.remove_relic(cid)
				Save.stat_add("curses_cleansed")
				Save.check_unlocks()
				Sfx.play("freeze")
				_done()))
			break


func _done() -> void:
	Game.save_run()
	Game.complete_node()
