class_name EventData
## 무작위 이벤트 30종 (구출 이벤트 5종 포함).
## 결과(out) 문법: [종류, 값] 목록.
##   hp ±n, max_hp ±n, oil ±n, heal_pct n, insc "random"/"rare"/"tag:<태그>", relic "random",
##   curse 1, remove_insc 1, fight "elite", embers n, rescue <npc>, undo n,
##   chance [확률, [성공 결과...], [실패 결과...]]
## req: {"oil": n} / {"hp": n} 을 만족해야 고를 수 있다.

const EVENTS := {
	"e_merchant": {"title": "떠도는 상인의 수레", "text": "등불 기름 냄새가 나는 수레가 길을 막고 있다. 주인은 보이지 않고, 동전 상자만 놓여 있다.",
		"choices": [
			{"text": "기름 30을 두고 각인 하나를 가져간다", "req": {"oil": 30}, "out": [["oil", -30], ["insc", "random"]]},
			{"text": "몰래 기름을 한 통 챙긴다", "out": [["oil", 25], ["chance", [50, [], [["curse", 1]]]]]},
			{"text": "그냥 지나친다", "out": []}]},
	"e_well": {"title": "소원 우물", "text": "물 밑바닥에서 희미한 빛이 흔들린다. 우물가에 \"하나를 주면 하나를 준다\"고 새겨져 있다.",
		"choices": [
			{"text": "기름 20을 던진다", "req": {"oil": 20}, "out": [["oil", -20], ["chance", [70, [["relic", "random"]], [["hp", 2]]]]]},
			{"text": "피 한 방울을 떨어뜨린다 (체력 -2)", "out": [["hp", -2], ["insc", "rare"]]},
			{"text": "물만 마신다", "out": [["heal_pct", 20]]}]},
	"e_statue": {"title": "울고 있는 석상", "text": "석상의 눈에서 그을음 섞인 눈물이 흐른다. 받침돌에 작은 홈이 파여 있다.",
		"choices": [
			{"text": "각인 하나를 홈에 바친다", "out": [["remove_insc", 1], ["max_hp", 3], ["heal_pct", 100]]},
			{"text": "눈물을 닦아 준다", "out": [["chance", [50, [["relic", "random"]], [["hp", -3]]]]]},
			{"text": "모른 척한다", "out": []}]},
	"e_campfire": {"title": "꺼지지 않은 모닥불", "text": "누군가 피워 둔 모닥불이 아직 타고 있다. 따뜻하다.",
		"choices": [
			{"text": "몸을 녹인다", "out": [["heal_pct", 35]]},
			{"text": "불씨를 등불에 옮긴다", "out": [["insc", "tag:fire"]]}]},
	"e_mirror": {"title": "속삭이는 거울", "text": "거울 속 내가 먼저 입을 연다. \"나와 자리를 바꾸자. 잠깐이면 돼.\"",
		"choices": [
			{"text": "자리를 바꾼다", "out": [["chance", [60, [["insc", "tag:mirror"], ["insc", "tag:mirror"]], [["hp", -4]]]]]},
			{"text": "거울을 깬다", "out": [["oil", 15], ["hp", -1]]},
			{"text": "등을 돌린다", "out": []}]},
	"e_library": {"title": "젖은 일지", "text": "물에 불은 일지 한 권이 떠내려왔다. 등불지기의 필체다.",
		"choices": [
			{"text": "끝까지 읽는다", "out": [["insc", "random"], ["hp", -1]]},
			{"text": "말려서 챙긴다", "out": [["embers", 15]]}]},
	"e_shrine": {"title": "그을린 제단", "text": "검게 그을린 제단 위에 \"불씨를 바치는 자에게 밤의 가호를\"이라 적혀 있다.",
		"choices": [
			{"text": "최대 체력 2를 바친다", "out": [["max_hp", -2], ["relic", "random"]]},
			{"text": "기름 40을 바친다", "req": {"oil": 40}, "out": [["oil", -40], ["relic", "random"]]},
			{"text": "떠난다", "out": []}]},
	"e_gambler": {"title": "주사위 도깨비", "text": "도깨비가 주사위를 흔든다. \"한 판 하자, 등불지기. 이기면 다 가져가.\"",
		"choices": [
			{"text": "기름 25를 건다", "req": {"oil": 25}, "out": [["chance", [50, [["oil", 50]], [["oil", -25]]]]]},
			{"text": "체력 3을 건다", "out": [["chance", [50, [["relic", "random"]], [["hp", -3]]]]]},
			{"text": "사양한다", "out": []}]},
	"e_wounded": {"title": "쓰러진 순례자", "text": "탑을 오르던 순례자가 쓰러져 있다. 숨은 붙어 있다.",
		"choices": [
			{"text": "약초를 나눠 준다 (체력 -2)", "out": [["hp", -2], ["embers", 25], ["undo", 1]]},
			{"text": "짐을 뒤진다", "out": [["oil", 30], ["curse", 1]]},
			{"text": "곁에 등불을 두고 간다", "out": [["heal_pct", 10]]}]},
	"e_ambush": {"title": "수상한 고요", "text": "너무 조용하다. 기둥 뒤에서 무언가 숨을 죽이고 있다.",
		"choices": [
			{"text": "먼저 덮친다 (엘리트 전투)", "out": [["fight", "elite"], ["relic", "random"]]},
			{"text": "살금살금 돌아간다", "out": [["hp", -2]]}]},
	"e_forge": {"title": "식은 대장간", "text": "버려진 모루 위에 망치가 놓여 있다. 화로엔 아직 불씨가 남았다.",
		"choices": [
			{"text": "각인 하나를 녹여 새로 벼린다", "out": [["remove_insc", 1], ["insc", "rare"]]},
			{"text": "망치로 등잔을 손본다", "out": [["insc", "tag:chain"]]}]},
	"e_frozen": {"title": "얼어붙은 등불지기", "text": "얼음 속에 등불을 든 사람이 갇혀 있다. 얼음이 차갑게 빛난다.",
		"choices": [
			{"text": "얼음 조각을 깎아 간직한다", "out": [["insc", "tag:frost"]]},
			{"text": "등불로 얼음을 녹인다 (체력 -2)", "out": [["hp", -2], ["embers", 20], ["relic", "random"]]}]},
	"e_swamp": {"title": "독 늪", "text": "초록빛 늪에서 거품이 올라온다. 늪 한가운데 빛나는 것이 가라앉아 있다.",
		"choices": [
			{"text": "손을 넣어 꺼낸다 (체력 -3)", "out": [["hp", -3], ["relic", "random"]]},
			{"text": "늪의 독을 심지에 바른다", "out": [["insc", "tag:poison"]]},
			{"text": "돌아간다", "out": []}]},
	"e_shadowself": {"title": "나를 닮은 그림자", "text": "벽에 비친 내 그림자가 따로 움직인다. 손짓으로 나를 부른다.",
		"choices": [
			{"text": "그림자를 따라간다", "out": [["insc", "tag:dark"], ["insc", "tag:dark"], ["max_hp", -1]]},
			{"text": "등불을 들이댄다", "out": [["oil", 20]]}]},
	"e_bell": {"title": "울리지 않는 종", "text": "거대한 종이 매달려 있다. 추가 떨어져 바닥에 굴러다닌다.",
		"choices": [
			{"text": "추를 다시 단다 (체력 -1)", "out": [["hp", -1], ["insc", "tag:chain"], ["oil", 10]]},
			{"text": "추를 팔 만큼 떼어 간다", "out": [["oil", 35]]}]},
	"e_child": {"title": "길 잃은 아이", "text": "작은 아이가 꺼진 초를 들고 울고 있다.",
		"choices": [
			{"text": "초에 불을 붙여 준다", "out": [["embers", 20], ["heal_pct", 15]]},
			{"text": "기름 15를 쥐여 준다", "req": {"oil": 15}, "out": [["oil", -15], ["embers", 40]]}]},
	"e_tea": {"title": "찻집 유령", "text": "반쯤 투명한 주인이 따뜻한 차를 내온다. \"쉬었다 가요. 오늘 밤은 길어요.\"",
		"choices": [
			{"text": "차를 마신다", "out": [["heal_pct", 50]]},
			{"text": "찻잎을 사 간다 (기름 25)", "req": {"oil": 25}, "out": [["oil", -25], ["max_hp", 2], ["heal_pct", 20]]}]},
	"e_chest": {"title": "자물쇠 걸린 상자", "text": "쇠사슬에 감긴 상자. 자물쇠가 그을음으로 덮여 있다.",
		"choices": [
			{"text": "억지로 연다 (체력 -2)", "out": [["hp", -2], ["chance", [75, [["relic", "random"]], [["curse", 1]]]]]},
			{"text": "그대로 둔다", "out": []}]},
	"e_cartographer": {"title": "지도 그리는 노인", "text": "노인이 탑의 지도를 그리고 있다. \"길을 알려 주지. 대신 이야기 하나만 들려줘.\"",
		"choices": [
			{"text": "지난 탐험 이야기를 들려준다", "out": [["undo", 2], ["oil", 10]]},
			{"text": "지도 한 장을 산다 (기름 20)", "req": {"oil": 20}, "out": [["oil", -20], ["insc", "random"], ["insc", "random"]]}]},
	"e_mask": {"title": "그을음 가면", "text": "바닥에 떨어진 가면에서 탐욕스러운 속삭임이 새어 나온다. \"나를 쓰면 부자가 될 거야.\"",
		"choices": [
			{"text": "가면을 쓴다", "out": [["relic", "x_mask"]]},
			{"text": "가면을 부순다", "out": [["embers", 10]]}]},
	"e_oil_spring": {"title": "기름 샘", "text": "바위틈에서 등불 기름이 솟는다. 다만 주변에 그림자 쥐 발자국이 가득하다.",
		"choices": [
			{"text": "가득 퍼 담는다 (전투)", "out": [["fight", "elite"], ["oil", 60]]},
			{"text": "조금만 담는다", "out": [["oil", 20]]}]},
	"e_crow": {"title": "말하는 까마귀", "text": "까마귀가 반짝이는 것을 물고 있다. \"바꾸자. 너의 반짝이는 것과.\"",
		"choices": [
			{"text": "각인 하나를 내준다", "out": [["remove_insc", 1], ["relic", "random"]]},
			{"text": "기름 30을 내준다", "req": {"oil": 30}, "out": [["oil", -30], ["relic", "random"]]},
			{"text": "쫓아 버린다", "out": []}]},
	"e_garden": {"title": "빛 먹는 꽃", "text": "등불 빛을 받자 꽃이 활짝 피어난다. 꽃잎에서 달콤한 향이 난다.",
		"choices": [
			{"text": "꽃잎을 먹는다", "out": [["chance", [70, [["max_hp", 2], ["heal_pct", 30]], [["hp", -2]]]]]},
			{"text": "꽃을 꺾어 간다", "out": [["oil", 15]]}]},
	"e_echo": {"title": "메아리 동굴", "text": "외치면 목소리가 몇 번이고 되돌아온다. 마지막 메아리는 내 목소리가 아니다.",
		"choices": [
			{"text": "크게 외친다", "out": [["insc", "tag:chain"]]},
			{"text": "귀를 기울인다", "out": [["embers", 15], ["undo", 1]]}]},
	"e_cursed_altar": {"title": "피 묻은 제단", "text": "제단 위에 동전이 쌓여 있다. 모두 피가 묻었다.",
		"choices": [
			{"text": "동전을 가져간다", "out": [["oil", 70], ["curse", 1]]},
			{"text": "동전을 제단에 돌려놓는다", "out": [["heal_pct", 25]]}]},
	# ── 구출 (오두막 시설 해금) ──
	"r_merchant": {"title": "갇힌 상인", "rescue": "merchant", "text": "\"여기요! 그림자들이 내 수레를 뺏어 갔어요. 꺼내 주면 은혜는 꼭 갚을게요!\" 상인 미로가 창살 너머에서 외친다.",
		"choices": [
			{"text": "창살을 부순다 (체력 -2)", "out": [["hp", -2], ["rescue", "merchant"], ["oil", 20]]},
			{"text": "다음에 오겠다고 한다", "out": []}]},
	"r_smith": {"title": "쇠사슬에 묶인 대장장이", "rescue": "smith", "text": "덩치 큰 사내가 쇠사슬에 묶여 있다. \"망치만 있으면 이딴 거 끊는데.\" 대장장이 철이다.",
		"choices": [
			{"text": "망치를 찾아다 준다 (전투)", "out": [["fight", "elite"], ["rescue", "smith"]]},
			{"text": "지나간다", "out": []}]},
	"r_seer": {"title": "점술가의 꿈", "rescue": "seer", "text": "잠든 여인 주위로 별빛이 맴돈다. 점술가 달래가 악몽에 갇혀 있다.",
		"choices": [
			{"text": "등불을 비춰 깨운다 (기름 20)", "req": {"oil": 20}, "out": [["oil", -20], ["rescue", "seer"]]},
			{"text": "곁에서 지켜 준다 (체력 -3)", "out": [["hp", -3], ["rescue", "seer"]]}]},
	"r_gardener": {"title": "덩굴 속 정원사", "rescue": "gardener", "text": "가시덩굴 속에서 노래가 들린다. 정원사 솔이 덩굴에 휘감긴 채 흥얼거린다.",
		"choices": [
			{"text": "덩굴을 태운다", "out": [["rescue", "gardener"], ["hp", -1]]},
			{"text": "모른 척한다", "out": []}]},
	"r_librarian": {"title": "물 위의 사서", "rescue": "librarian", "text": "책 더미 위에 사람이 서 있다. 사방이 물이다. \"책은 두고 갈 수 없어요.\" 사서 문이다.",
		"choices": [
			{"text": "책을 함께 나른다 (체력 -2)", "out": [["hp", -2], ["rescue", "librarian"], ["embers", 10]]},
			{"text": "사람만 데려간다", "out": [["rescue", "librarian"], ["max_hp", -1]]}]},
}
