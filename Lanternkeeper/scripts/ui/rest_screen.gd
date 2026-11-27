extends Screen
## 휴식처: 쉬기 / 명상 / 정화.

var hud: RunHud


func build(_p: Dictionary) -> void:
	var r := Game.run
	var v := UI.screen_frame(self, "")
	hud = RunHud.make(self)
	v.add_child(hud)
	v.add_child(UI.spacer(30))
	v.add_child(UI.label("모닥불 곁에서", 46, UI.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("잠시 숨을 고른다. 하나만 할 수 있다.", 26, UI.SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(20))
	var m := r.mods()
	var pct := 35 + int(m.get("rest_heal_bonus", 0))
	var amount := int(ceil(r.max_hp() * pct / 100.0))
	var no_heal := int(m.get("no_rest_heal", 0)) > 0
	var b1 := UI.button("쉬기 · 체력 %d 회복" % amount if not no_heal else "쉬기 · (저주: 회복할 수 없다)", func():
		r.heal(amount)
		Sfx.play("heal")
		_done(), 28, true, 96)
	b1.disabled = no_heal or r.hp >= r.max_hp()
	v.add_child(b1)
	v.add_child(UI.button("명상 · 최대 체력 +1", func():
		r.extra_max_hp += 1
		r.hp += 1
		Sfx.play("ui_confirm")
		_done(), 28, false, 96))
	var curses := []
	for id in r.relics:
		if UpgradeData.relic(id).get("curse", false):
			curses.append(id)
	if not curses.is_empty():
		var cid: String = curses[0]
		v.add_child(UI.button("정화 · 저주 제거: %s" % UpgradeData.relic(cid)["name"], func():
			r.remove_relic(cid)
			Save.stat_add("curses_cleansed")
			Save.check_unlocks()
			Sfx.play("freeze")
			_done(), 28, false, 96))


func _done() -> void:
	Game.save_run()
	Game.complete_node()
