class_name MapGen
## 층 지도: 갈림길로 이어진 7줄의 방 + 보스.

const ROWS := 7
const TYPE_NAMES := {"battle": "전투", "elite": "엘리트", "event": "이벤트", "shop": "상점", "rest": "휴식", "treasure": "보물", "boss": "보스"}


static func generate(seed: int, elite_more: bool, short: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rows := ROWS if not short else 4
	var nodes := []
	var grid := []
	var nid := 0
	for r in rows:
		var count := 3 if r == 0 else rng.randi_range(2, 4)
		if r == rows - 1:
			count = rng.randi_range(2, 3)
		var row_nodes := []
		for i in count:
			var x := (i + 1.0) / (count + 1.0) + rng.randf_range(-0.06, 0.06)
			var n := {"id": nid, "row": r, "x": x, "type": "battle", "links": []}
			nid += 1
			nodes.append(n)
			row_nodes.append(n)
		grid.append(row_nodes)
	var boss := {"id": nid, "row": rows, "x": 0.5, "type": "boss", "links": []}
	nodes.append(boss)

	# 연결
	for r in rows - 1:
		var cur: Array = grid[r]
		var nxt: Array = grid[r + 1]
		for n in cur:
			var sorted := nxt.duplicate()
			sorted.sort_custom(func(a, c): return abs(a["x"] - n["x"]) < abs(c["x"] - n["x"]))
			n["links"].append(sorted[0]["id"])
			if sorted.size() > 1 and rng.randf() < 0.45:
				n["links"].append(sorted[1]["id"])
		for m in nxt:
			var has_in := false
			for n in cur:
				if n["links"].has(m["id"]):
					has_in = true
			if not has_in:
				var best = cur[0]
				for n in cur:
					if abs(n["x"] - m["x"]) < abs(best["x"] - m["x"]):
						best = n
				best["links"].append(m["id"])
	for n in grid[rows - 1]:
		n["links"].append(boss["id"])

	# 방 종류
	var weights := {"battle": 46, "event": 22, "elite": 12 + (8 if elite_more else 0), "shop": 8, "rest": 7, "treasure": 5}
	var has_shop := false
	for r in rows:
		for n in grid[r]:
			if r == 0:
				n["type"] = "battle"
			elif r == rows - 1:
				n["type"] = "rest"
			else:
				var t := RoomGen._weighted(rng, weights)
				if r < 2 and (t == "elite" or t == "rest"):
					t = "battle"
				n["type"] = t
				if t == "shop":
					has_shop = true
	if not has_shop and rows > 3:
		var r2 := rng.randi_range(2, rows - 2)
		grid[r2][rng.randi_range(0, grid[r2].size() - 1)]["type"] = "shop"
	if rows > 4:
		var has_treasure := false
		for n in grid[3]:
			if n["type"] == "treasure":
				has_treasure = true
		if not has_treasure:
			grid[3][rng.randi_range(0, grid[3].size() - 1)]["type"] = "treasure"
	return {"nodes": nodes, "rows": rows, "boss": boss["id"]}


static func node(map: Dictionary, id: int) -> Dictionary:
	for n in map["nodes"]:
		if int(n["id"]) == id:
			return n
	return {}


static func starts(map: Dictionary) -> Array:
	var out := []
	for n in map["nodes"]:
		if int(n["row"]) == 0:
			out.append(int(n["id"]))
	return out
