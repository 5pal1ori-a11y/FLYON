class_name EnemyData
## 적 15종 + 분열체 + 보스 4종 + 엘리트 변형 5종.
## ai: melee / bomber / spider / archer / charger / healer / summoner / creeper / statue / boss_*

const ENEMIES := {
	"rat": {"name": "그림자 쥐", "hp": 2, "move": 1, "atk": 1, "ai": "melee", "tier": 1, "cost": 1,
		"desc": "가장 흔한 그림자 짐승. 한 칸씩 다가와 문다."},
	"moth": {"name": "재나방", "hp": 1, "move": 2, "atk": 1, "ai": "melee", "flying": true, "tier": 1, "cost": 1,
		"desc": "빛을 좇아 빠르게 날아든다. 장애물 위를 넘어 다닌다."},
	"mist": {"name": "안개 덩어리", "hp": 3, "move": 1, "atk": 1, "ai": "melee", "split": "mistling", "tier": 1, "cost": 2,
		"desc": "쓰러지면 작은 안개 둘로 갈라진다."},
	"mistling": {"name": "작은 안개", "hp": 1, "move": 1, "atk": 1, "ai": "melee", "tier": 0, "cost": 0,
		"desc": "안개 덩어리에서 떨어져 나온 조각."},
	"bomber": {"name": "폭발 반딧불", "hp": 1, "move": 1, "atk": 2, "ai": "bomber", "explode": 1, "tier": 1, "cost": 1,
		"desc": "곁에 닿으면 터져 주변 모두에게 피해를 준다. 쓰러질 때도 작게 터진다."},
	"spider": {"name": "그림자 거미", "hp": 2, "move": 2, "atk": 1, "ai": "spider", "tier": 1, "cost": 2,
		"desc": "지나간 자리에 거미줄을 남긴다. 거미줄에 들어서면 이동이 멈춘다."},
	"ghost": {"name": "떠도는 혼", "hp": 2, "move": 1, "atk": 1, "ai": "melee", "flying": true, "no_shadow": true, "tier": 2, "cost": 2,
		"desc": "그림자가 없어 굳힐 수 없다. 기둥 위를 지나다닌다."},
	"knight": {"name": "거울 기사", "hp": 4, "move": 1, "atk": 2, "ai": "melee", "front_guard": true, "tier": 2, "cost": 3,
		"desc": "방패가 향한 쪽에서 오는 그림자를 튕겨 낸다. 옆이나 등 뒤를 노려라."},
	"archer": {"name": "등불 사냥꾼", "hp": 2, "move": 1, "atk": 1, "ai": "archer", "range": 5, "tier": 2, "cost": 2,
		"desc": "같은 줄에 서면 조준하고, 다음 턴에 그 줄로 쏜다."},
	"shield": {"name": "방패병", "hp": 5, "move": 1, "atk": 1, "ai": "melee", "cap": 1, "tier": 2, "cost": 3,
		"desc": "한 번의 점화로 최대 1의 피해만 받는다. 상태 이상으로 공략하라."},
	"healer": {"name": "치유 수도사", "hp": 3, "move": 1, "atk": 0, "ai": "healer", "tier": 2, "cost": 2,
		"desc": "곁에 있는 적을 매 턴 1씩 회복시키고, 거리를 둔다."},
	"summoner": {"name": "그림자 소환사", "hp": 4, "move": 1, "atk": 1, "ai": "summoner", "tier": 3, "cost": 3,
		"desc": "멀찍이 떨어져 3턴마다 그림자 쥐를 불러낸다."},
	"charger": {"name": "돌진 늑대", "hp": 3, "move": 1, "atk": 2, "ai": "charger", "tier": 2, "cost": 2,
		"desc": "한 줄로 노려본 뒤 끝까지 돌진한다. 장애물에 부딪히면 기절한다."},
	"creeper": {"name": "어둠 잠식자", "hp": 3, "move": 0, "atk": 1, "ai": "creeper", "tier": 2, "cost": 2,
		"desc": "움직이지 않지만 2턴마다 주변을 어둠으로 물들인다. 어둠 위에서 턴을 마치면 피해를 입는다."},
	"goblin": {"name": "등불 도깨비", "hp": 3, "move": 1, "atk": 1, "ai": "melee", "aura": true, "tier": 3, "cost": 3,
		"desc": "스스로 빛을 내 주변 한 칸에 그림자가 들지 않는다. 굳히면 빛이 꺼진다."},
	"statue": {"name": "잿빛 석상", "hp": 6, "move": 1, "atk": 2, "ai": "statue", "tier": 3, "cost": 3,
		"desc": "등불 빛 안에 있으면 움직이지 못한다. 어둠 속에서만 다가온다."},
	# ── 보스 ──
	"queen": {"name": "안개 여왕", "hp": 16, "move": 1, "atk": 2, "ai": "boss_queen", "boss": true, "tier": 9, "cost": 0,
		"desc": "3턴마다 안개 덩어리를 부른다. 체력이 절반 아래로 떨어지면 2턴마다 둘씩 부르고, 안개가 짙어져 빛이 줄어든다."},
	"mirrorlord": {"name": "거울 군주", "hp": 18, "move": 1, "atk": 2, "ai": "boss_mirror", "boss": true, "front_guard": true, "tier": 9, "cost": 0,
		"desc": "앞에서 오는 그림자를 튕겨 내고, 3턴마다 거울과 자리를 바꾼다."},
	"archivist": {"name": "잠긴 서고의 사서", "hp": 20, "move": 1, "atk": 1, "ai": "boss_archivist", "boss": true, "range": 7, "tier": 9, "cost": 0,
		"desc": "매 턴 바닥을 물에 잠기게 하고, 2턴마다 한 줄 전체를 휩쓰는 물결을 쏜다."},
	"eclipse": {"name": "일식", "hp": 26, "move": 1, "atk": 2, "ai": "boss_eclipse", "boss": true, "aura": true, "tier": 9, "cost": 0,
		"desc": "턴마다 빛을 삼킨다. 주변 한 칸에는 그림자가 들지 않으며, 굳으면 빛이 꺼진다."},
}

const ELITES := {
	"swift": {"name": "재빠른", "move": 1, "desc": "이동 +1"},
	"armored": {"name": "단단한", "shield": 1, "desc": "매 턴 피해 1을 막는 껍질"},
	"volatile": {"name": "불안정한", "explode": 1, "desc": "쓰러질 때 폭발"},
	"giant": {"name": "거대한", "hp": 3, "desc": "체력 +3"},
	"regen": {"name": "되살아나는", "regen": 1, "desc": "매 턴 체력 1 회복"},
}

const BOSS_ORDER := ["queen", "mirrorlord", "archivist", "eclipse"]


static func get_def(kind: String) -> Dictionary:
	return ENEMIES.get(kind, ENEMIES["rat"])


static func pool_for(biome: String, max_tier: int) -> Array:
	var pool: Array = BiomeData.get_def(biome)["enemies"]
	var out := []
	for k in pool:
		if int(ENEMIES[k]["tier"]) <= max_tier:
			out.append(k)
	if out.is_empty():
		out.append("rat")
	return out
