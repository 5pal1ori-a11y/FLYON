class_name PuzzleData
## 퍼즐 모드: "단 한 번의 이동과 점화로 모든 적을 물리쳐라".
## puzzles.json은 tools/gen_puzzles.gd가 만들고, 모든 퍼즐은 해답이 있는지 자동 검증된다.

const PATH := "res://scripts/data/puzzles.json"
const TILE_CHARS := {".": Board.FLOOR, "#": Board.WALL, "P": Board.PILLAR, "C": Board.CRATE, "M": Board.MIRROR,
	"G": Board.GLASS, "~": Board.WATER, "B": Board.BRAZIER}

static var _cache: Array = []


static func load_all() -> Array:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Array:
		_cache = data
	return _cache


static func board_from(pz: Dictionary) -> Board:
	var rows: Array = pz["tiles"]
	var b := Board.new(rows[0].length(), rows.size())
	b.biome = pz.get("biome", "fog")
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			b.set_tile(Vector2i(x, y), TILE_CHARS.get(line[x], Board.FLOOR))
	b.objective = {"type": "puzzle"}
	var pl: Array = pz["player"]
	b.spawn_player(Vector2i(int(pl[0]), int(pl[1])), 5, 5, int(pz.get("move", 2)))
	for e in pz["enemies"]:
		var u := b.spawn_enemy(e["k"], Vector2i(int(e["x"]), int(e["y"])))
		if e.has("f"):
			u.facing = Vector2i(int(e["f"][0]), int(e["f"][1]))
	return b


static func make_battle(pz: Dictionary) -> Battle:
	return Battle.new(board_from(pz), {}, pz.get("lantern", "candle"), 0, true)


static func to_def(b: Board, lantern: String, move: int, solution: Dictionary, difficulty: int) -> Dictionary:
	var inv := {}
	for k in TILE_CHARS.keys():
		inv[TILE_CHARS[k]] = k
	var rows := []
	for y in b.h:
		var line := ""
		for x in b.w:
			line += inv.get(b.tile(Vector2i(x, y)), ".")
		rows.append(line)
	var ens := []
	for e in b.enemies():
		var d := {"k": e.kind, "x": e.pos.x, "y": e.pos.y}
		if e.front_guard:
			d["f"] = [e.facing.x, e.facing.y]
		ens.append(d)
	var p := b.player()
	var cells := []
	for c in solution["cells"]:
		cells.append([c.x, c.y])
	return {"tiles": rows, "player": [p.pos.x, p.pos.y], "enemies": ens, "lantern": lantern, "move": move,
		"biome": b.biome, "difficulty": difficulty,
		"solution": {"move": [solution["move"].x, solution["move"].y], "cells": cells}}
