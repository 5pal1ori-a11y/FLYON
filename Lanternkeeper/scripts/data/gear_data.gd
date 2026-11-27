class_name GearData
## 등불 6종, 캐릭터 3명, 오두막 시설, 등불 꾸미기, NPC.

const LANTERNS := {
	"candle": {"name": "촛불", "radius": 3.0, "length": 3, "dmg": 2, "mode": "point", "count": 1, "cost": 0,
		"color": Color(1.0, 0.72, 0.35),
		"desc": "그림자가 짧지만 강하다. 가장 믿을 만한 불빛."},
	"torch": {"name": "횃불", "radius": 4.5, "length": 5, "dmg": 1, "burn": 1, "mode": "point", "count": 1, "cost": 60,
		"color": Color(1.0, 0.5, 0.2),
		"desc": "넓고 긴 그림자. 맞은 적은 화상 1을 입는다."},
	"moon": {"name": "달빛 등", "radius": 0.0, "length": 4, "dmg": 1, "mode": "directional", "count": 1, "cost": 120,
		"color": Color(0.7, 0.8, 1.0),
		"desc": "방 안의 모든 그림자가 한 방향으로 나란히 뻗는다. 등불을 놓은 쪽의 반대편으로."},
	"twin": {"name": "쌍둥이 램프", "radius": 2.5, "length": 2, "dmg": 1, "mode": "point", "count": 2, "cost": 160,
		"color": Color(1.0, 0.85, 0.5),
		"desc": "등불 두 개를 동시에 놓는다. 그림자가 겹친 곳은 피해가 쌓인다."},
	"swing": {"name": "흔들등", "radius": 3.0, "length": 3, "dmg": 1, "mode": "swing", "count": 1, "cost": 200,
		"color": Color(0.95, 0.6, 0.9),
		"desc": "놓은 자리와, 나를 중심으로 시계 방향 90° 돌아간 자리에서 두 번 빛난다."},
	"black": {"name": "검은 불꽃", "radius": 2.5, "length": 3, "dmg": 2, "mode": "inverse", "count": 1, "cost": 260,
		"color": Color(0.6, 0.4, 1.0),
		"desc": "빛과 그림자가 뒤바뀐다. 그림자가 아닌, 빛이 닿은 곳의 적이 피해를 입는다."},
}
const LANTERN_ORDER := ["candle", "torch", "moon", "twin", "swing", "black"]

const CHARACTERS := {
	"keeper": {"name": "등불지기", "hp": 7, "move": 2, "cost": 0,
		"desc": "탑의 마지막 등불지기. 균형 잡힌 기본 캐릭터.", "mods": {}},
	"thief": {"name": "그림자 도둑", "hp": 5, "move": 2, "cost": 120,
		"desc": "지난 턴 내 그림자가 드리운 칸이면 어디로든 이동할 수 있다. 굳은 적에게 피해 +1.",
		"mods": {"shadow_step": 1, "dmg_vs_frozen": 1}},
	"priest": {"name": "새벽 사제", "hp": 9, "move": 1, "cost": -1, "unlock_stat": "boss_mirrorlord",
		"desc": "등불 반경 +1. 한 번에 적 둘 이상을 맞히면 체력 1 회복. 이동력 1. (거울 군주를 쓰러뜨리면 합류)",
		"mods": {"radius": 1.0, "heal_multi": 1}},
}
const CHARACTER_ORDER := ["keeper", "thief", "priest"]

## 오두막 시설. needs: 필요한 NPC 구출. costs: 레벨별 불씨 비용.
const FACILITIES := {
	"hearth": {"name": "화덕", "desc": "최대 체력 +1 (레벨당)", "costs": [30, 50, 80, 120, 170], "needs": ""},
	"oilstore": {"name": "기름 창고", "desc": "시작 기름 +15 (레벨당)", "costs": [25, 60, 110], "needs": ""},
	"forge": {"name": "대장간", "desc": "Lv1 흔한 각인 하나, Lv2 희귀 각인 하나를 들고 시작", "costs": [70, 160], "needs": "smith"},
	"seer": {"name": "점술 탁자", "desc": "층마다 보상 다시 뽑기 +1 (레벨당)", "costs": [60, 140], "needs": "seer"},
	"garden": {"name": "약초 정원", "desc": "방을 마칠 때마다 체력 +1 (Lv2부터 +1 추가: 2방에 1번)", "costs": [80, 180], "needs": "gardener"},
	"market": {"name": "떠돌이 장터", "desc": "상점 가격 -10% (레벨당)", "costs": [50, 120], "needs": "merchant"},
	"archive": {"name": "서고", "desc": "탑의 기록을 모아 둔다. 이벤트를 마칠 때마다 기름 +10", "costs": [40], "needs": "librarian"},
}
const FACILITY_ORDER := ["hearth", "oilstore", "forge", "seer", "garden", "market", "archive"]

const NPCS := {
	"merchant": {"name": "떠돌이 상인 미로", "desc": "오두막에 장터를 연다."},
	"smith": {"name": "대장장이 철이", "desc": "오두막에 대장간을 연다."},
	"seer": {"name": "점술가 달래", "desc": "오두막에 점술 탁자를 놓는다."},
	"gardener": {"name": "정원사 솔", "desc": "오두막 뒤편에 약초를 심는다."},
	"librarian": {"name": "사서 문", "desc": "오두막에 작은 서고를 꾸린다."},
}

## 등불 꾸미기 (업적 보상, 판매하지 않음)
const SKINS := {
	"amber": {"name": "호박빛", "color": Color(1.0, 0.72, 0.35), "desc": "기본"},
	"azure": {"name": "푸른 불꽃", "color": Color(0.45, 0.75, 1.0), "desc": "업적: 서리의 손"},
	"jade": {"name": "비취 불꽃", "color": Color(0.45, 1.0, 0.65), "desc": "업적: 독의 길"},
	"amethyst": {"name": "자수정 불꽃", "color": Color(0.75, 0.5, 1.0), "desc": "업적: 거울 너머"},
	"crimson": {"name": "핏빛 불꽃", "color": Color(1.0, 0.3, 0.3), "desc": "업적: 불타는 탑"},
	"silver": {"name": "은달 불꽃", "color": Color(0.92, 0.95, 1.0), "desc": "업적: 일식을 넘어"},
	"gold": {"name": "황금 불꽃", "color": Color(1.0, 0.85, 0.2), "desc": "업적: 그을음 10단계"},
	"prism": {"name": "무지갯빛", "color": Color(1, 1, 1), "desc": "업적: 모든 업적의 절반"},
}
const SKIN_ORDER := ["amber", "azure", "jade", "amethyst", "crimson", "silver", "gold", "prism"]
