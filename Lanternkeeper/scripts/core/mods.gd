class_name Mods
## 캐릭터·각인·세트·유물·그을음·시설 효과를 하나의 수치 사전으로 합친다.


static func add_fx(m: Dictionary, fx: Dictionary) -> void:
	for k in fx.keys():
		m[k] = m.get(k, 0) + fx[k]


static func tag_counts(inscriptions: Array) -> Dictionary:
	var out := {}
	for id in inscriptions:
		var d := UpgradeData.inscription(id)
		if d.is_empty():
			continue
		out[d["tag"]] = int(out.get(d["tag"], 0)) + 1
	return out


## 켜진 세트 효과 목록: [{tag, n, desc}]
static func active_sets(inscriptions: Array) -> Array:
	var out := []
	var counts := tag_counts(inscriptions)
	for tag in UpgradeData.TAG_ORDER:
		for tier in UpgradeData.SETS[tag]:
			if int(counts.get(tag, 0)) >= int(tier["n"]):
				out.append({"tag": tag, "n": tier["n"], "desc": tier["desc"], "fx": tier["fx"]})
	return out


static func ascension_fx(asc: int) -> Dictionary:
	var m := {}
	for i in min(asc, MetaData.ASCENSION.size()):
		add_fx(m, MetaData.ASCENSION[i]["fx"])
	return m


static func build(character: String, inscriptions: Array, relics: Array, asc: int, facilities: Dictionary) -> Dictionary:
	var m := {}
	var ch: Dictionary = GearData.CHARACTERS.get(character, GearData.CHARACTERS["keeper"])
	add_fx(m, ch.get("mods", {}))
	for id in inscriptions:
		var d := UpgradeData.inscription(id)
		if not d.is_empty():
			add_fx(m, d["fx"])
	for s in active_sets(inscriptions):
		add_fx(m, s["fx"])
	for id in relics:
		var r := UpgradeData.relic(id)
		if not r.is_empty():
			add_fx(m, r["fx"])
	add_fx(m, ascension_fx(asc))
	m["max_hp"] = m.get("max_hp", 0) + int(facilities.get("hearth", 0))
	var garden := int(facilities.get("garden", 0))
	if garden > 0:
		m["heal_on_room"] = m.get("heal_on_room", 0) + 1
		if garden >= 2:
			m["garden2"] = 1
	m["shop_discount"] = m.get("shop_discount", 0) + 10 * int(facilities.get("market", 0))
	return m


static func max_hp_for(character: String, m: Dictionary) -> int:
	var ch: Dictionary = GearData.CHARACTERS.get(character, GearData.CHARACTERS["keeper"])
	return max(2, int(ch["hp"]) + int(m.get("max_hp", 0)))


static func move_for(character: String, m: Dictionary) -> int:
	var ch: Dictionary = GearData.CHARACTERS.get(character, GearData.CHARACTERS["keeper"])
	return max(1, int(ch["move"]) + int(m.get("move", 0)))
