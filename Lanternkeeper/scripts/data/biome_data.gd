class_name BiomeData
## 탑의 네 구역. 구역마다 고유 규칙, 장치 비율, 적 구성, 색감, 음악이 다르다.

const BIOMES := {
	"fog": {
		"name": "안개 정원", "rule": "짙은 안개: 4칸보다 먼 적은 정체와 의도가 보이지 않는다.",
		"floor": Color(0.17, 0.21, 0.19), "floor2": Color(0.2, 0.245, 0.22), "accent": Color(0.55, 0.75, 0.62),
		"fog": Color(0.05, 0.08, 0.07),
		"pillar": [3, 5], "crate": [0, 2], "mirror": [0, 0], "glass": [0, 1], "water": [0, 3], "brazier": [0, 0],
		"enemies": ["rat", "moth", "mist", "bomber", "spider"],
		"boss": "queen", "music": "fog",
	},
	"mirror": {
		"name": "거울 회랑", "rule": "반사의 회랑: 거울이 많아 빛이 여러 번 갈라진다.",
		"floor": Color(0.18, 0.18, 0.25), "floor2": Color(0.21, 0.21, 0.29), "accent": Color(0.7, 0.72, 0.95),
		"fog": Color(0.05, 0.05, 0.09),
		"pillar": [2, 4], "crate": [0, 1], "mirror": [2, 3], "glass": [1, 2], "water": [0, 0], "brazier": [0, 1],
		"enemies": ["rat", "moth", "knight", "archer", "ghost", "shield"],
		"boss": "mirrorlord", "music": "mirror",
	},
	"library": {
		"name": "잠긴 서고", "rule": "차오르는 물: 물에 닿은 그림자는 이어진 물길 전체로 번진다.",
		"floor": Color(0.15, 0.18, 0.24), "floor2": Color(0.18, 0.21, 0.28), "accent": Color(0.45, 0.7, 0.9),
		"fog": Color(0.03, 0.06, 0.09),
		"pillar": [3, 4], "crate": [1, 2], "mirror": [0, 1], "glass": [0, 1], "water": [6, 10], "brazier": [0, 0],
		"enemies": ["ghost", "spider", "healer", "summoner", "charger", "creeper", "archer"],
		"boss": "archivist", "music": "library",
	},
	"eclipse": {
		"name": "일식의 정상", "rule": "저무는 빛: 3턴마다 등불 반경이 0.5씩 줄어든다.",
		"floor": Color(0.23, 0.15, 0.14), "floor2": Color(0.27, 0.18, 0.16), "accent": Color(0.95, 0.55, 0.35),
		"fog": Color(0.08, 0.03, 0.03),
		"pillar": [3, 5], "crate": [0, 1], "mirror": [0, 1], "glass": [0, 1], "water": [0, 2], "brazier": [1, 2],
		"enemies": ["goblin", "statue", "charger", "knight", "summoner", "creeper", "bomber", "shield"],
		"boss": "eclipse", "music": "eclipse",
	},
}
const ORDER := ["fog", "mirror", "library", "eclipse"]


static func get_def(id: String) -> Dictionary:
	return BIOMES.get(id, BIOMES["fog"])


static func for_floor(floor_index: int) -> String:
	return ORDER[floor_index % ORDER.size()]
