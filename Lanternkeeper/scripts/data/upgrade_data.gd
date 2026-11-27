class_name UpgradeData
## 각인 60개(태그 6종 × 10), 세트 효과, 유물 40개(저주 포함).
## fx 키는 Mods/Combat/EnemyAI가 해석한다. 같은 키는 더해진다.

const TAGS := {
	"fire": {"name": "불꽃", "color": Color(1.0, 0.5, 0.25)},
	"frost": {"name": "서리", "color": Color(0.55, 0.85, 1.0)},
	"poison": {"name": "독", "color": Color(0.5, 0.95, 0.45)},
	"chain": {"name": "연쇄", "color": Color(1.0, 0.92, 0.4)},
	"mirror": {"name": "거울", "color": Color(0.8, 0.8, 1.0)},
	"dark": {"name": "어둠", "color": Color(0.7, 0.45, 0.95)},
}
const TAG_ORDER := ["fire", "frost", "poison", "chain", "mirror", "dark"]

## 같은 태그 3개 / 5개를 모으면 켜지는 세트 효과
const SETS := {
	"fire": [{"n": 3, "desc": "화상 입은 적이 쓰러지면 주변 적에게 폭발 피해 1", "fx": {"burning_explode": 1}},
		{"n": 5, "desc": "화상 부여 +1, 화상 입은 적에게 피해 +1", "fx": {"burn_on_hit": 1, "dmg_vs_burning": 1}}],
	"frost": [{"n": 3, "desc": "굳은 적이 쓰러지면 주변 적도 굳는다", "fx": {"shatter": 1}},
		{"n": 5, "desc": "매 점화 첫 번째로 맞은 적이 굳는다. 굳는 시간 +1", "fx": {"freeze_first": 1, "freeze_duration": 1}}],
	"poison": [{"n": 3, "desc": "독이 줄어들지 않는다", "fx": {"poison_no_decay": 1}},
		{"n": 5, "desc": "독 부여 +2", "fx": {"poison_on_hit": 2}}],
	"chain": [{"n": 3, "desc": "연쇄 도약 +1", "fx": {"chain_jumps": 1}},
		{"n": 5, "desc": "연쇄가 범위 안의 모든 적에게 번진다", "fx": {"chain_all": 1}}],
	"mirror": [{"n": 3, "desc": "나를 기준으로 반대편에 등불의 거울상이 생긴다", "fx": {"mirror_copy": 1}},
		{"n": 5, "desc": "거울 빛 반경 +1, 거울 빛 피해 +1", "fx": {"mirror_radius": 1.0, "mirror_dmg": 1}}],
	"dark": [{"n": 3, "desc": "그림자가 한 턴 남아, 적 턴 끝에 그 위의 적에게 피해 1", "fx": {"linger": 1}},
		{"n": 5, "desc": "그림자 길이 +1, 먼 그림자 피해 +1", "fx": {"length": 1, "dmg_far": 1}}],
}

const INSCRIPTIONS := {
	# ── 불꽃 ──
	"f_ember": {"name": "불씨 각인", "tag": "fire", "rarity": 0, "desc": "그림자에 맞은 적에게 화상 1", "fx": {"burn_on_hit": 1}},
	"f_blaze": {"name": "타오르는 그림자", "tag": "fire", "rarity": 0, "desc": "화상 입은 적에게 피해 +1", "fx": {"dmg_vs_burning": 1}},
	"f_spread": {"name": "번지는 불", "tag": "fire", "rarity": 1, "desc": "화상 입은 적이 쓰러지면 주변 적에게 화상 2", "fx": {"burn_spread": 2}},
	"f_coal": {"name": "숯 심장", "tag": "fire", "rarity": 1, "desc": "화상 피해 +1", "fx": {"burn_tick": 1}},
	"f_ashward": {"name": "재의 보호막", "tag": "fire", "rarity": 0, "desc": "적 턴마다 받는 피해 1 막기", "fx": {"ward": 1}},
	"f_pillar": {"name": "화염 기둥", "tag": "fire", "rarity": 0, "desc": "기둥·상자의 그림자가 화상 1을 입힌다", "fx": {"pillar_burn": 1}},
	"f_cinder": {"name": "불티", "tag": "fire", "rarity": 0, "desc": "적을 쓰러뜨릴 때마다 기름 +1", "fx": {"oil_on_kill": 1}},
	"f_furnace": {"name": "용광로", "tag": "fire", "rarity": 1, "desc": "그림자 피해 +1, 최대 체력 -1", "fx": {"dmg": 1, "max_hp": -1}},
	"f_heat": {"name": "열기", "tag": "fire", "rarity": 0, "desc": "등불 곁 한 칸의 적에게 화상 2", "fx": {"lantern_burn": 2}},
	"f_will": {"name": "불사르는 의지", "tag": "fire", "rarity": 2, "desc": "화상 입은 적이 쓰러지면 체력 1 회복 (점화당 1회)", "fx": {"heal_burn_kill": 1}},
	# ── 서리 ──
	"i_frost": {"name": "서리 각인", "tag": "frost", "rarity": 0, "desc": "적이 굳는 시간 +1턴", "fx": {"freeze_duration": 1}},
	"i_blade": {"name": "얼음 칼날", "tag": "frost", "rarity": 0, "desc": "굳은 적에게 피해 +1", "fx": {"dmg_vs_frozen": 1}},
	"i_layer": {"name": "겹서리", "tag": "frost", "rarity": 1, "desc": "그림자 둘 이상에 동시에 맞은 적은 굳는다", "fx": {"freeze_on_multi": 1}},
	"i_cold": {"name": "차가운 그림자", "tag": "frost", "rarity": 1, "desc": "기둥·상자의 그림자로도 적 그림자를 밟아 굳힐 수 있다", "fx": {"freeze_any_shadow": 1}},
	"i_rime": {"name": "서릿발", "tag": "frost", "rarity": 0, "desc": "굳은 적은 적 턴 끝에 피해 1", "fx": {"frost_tick": 1}},
	"i_armor": {"name": "얼음 갑옷", "tag": "frost", "rarity": 0, "desc": "굳은 적이 있으면 적 턴 피해 1 막기", "fx": {"ward_frozen": 1}},
	"i_time": {"name": "얼어붙은 시간", "tag": "frost", "rarity": 0, "desc": "되돌리기 +1", "fx": {"undo": 1}},
	"i_wave": {"name": "결빙 파동", "tag": "frost", "rarity": 1, "desc": "굳은 적이 쓰러지면 주변 적도 굳는다", "fx": {"shatter": 1}},
	"i_lens": {"name": "냉기 렌즈", "tag": "frost", "rarity": 0, "desc": "그림자 길이 +1", "fx": {"length": 1}},
	"i_cold_snap": {"name": "한파", "tag": "frost", "rarity": 2, "desc": "매 점화 첫 번째로 맞은 적이 굳는다", "fx": {"freeze_first": 1}},
	# ── 독 ──
	"p_venom": {"name": "독 각인", "tag": "poison", "rarity": 0, "desc": "그림자에 맞은 적에게 독 1", "fx": {"poison_on_hit": 1}},
	"p_thick": {"name": "진한 독", "tag": "poison", "rarity": 0, "desc": "중독된 적에게 피해 +1", "fx": {"dmg_vs_poisoned": 1}},
	"p_spread": {"name": "퍼지는 독", "tag": "poison", "rarity": 1, "desc": "중독된 적이 쓰러지면 주변 적에게 독 2", "fx": {"poison_spread": 2}},
	"p_water": {"name": "썩은 물", "tag": "poison", "rarity": 0, "desc": "물길로 번진 그림자가 독 2를 입힌다", "fx": {"water_poison": 2}},
	"p_mist": {"name": "독 안개", "tag": "poison", "rarity": 1, "desc": "방에 들어서면 모든 적이 독 2", "fx": {"start_poison": 2}},
	"p_herb": {"name": "해독초", "tag": "poison", "rarity": 0, "desc": "방을 마칠 때 체력 +1", "fx": {"heal_on_room": 1}},
	"p_thorn": {"name": "독침", "tag": "poison", "rarity": 0, "desc": "나를 때린 적은 피해 1", "fx": {"thorns": 1}},
	"p_wick": {"name": "중독된 심지", "tag": "poison", "rarity": 1, "desc": "독 부여 +2, 그림자 피해 -1", "fx": {"poison_on_hit": 2, "dmg": -1}},
	"p_strong": {"name": "맹독", "tag": "poison", "rarity": 1, "desc": "독 피해 +1", "fx": {"poison_tick": 1}},
	"p_lord": {"name": "독의 군주", "tag": "poison", "rarity": 2, "desc": "독이 줄어들지 않는다", "fx": {"poison_no_decay": 1}},
	# ── 연쇄 ──
	"c_chain": {"name": "연쇄 각인", "tag": "chain", "rarity": 0, "desc": "적을 쓰러뜨리면 가까운 적에게 그림자가 튀어 피해 1", "fx": {"chain": 1}},
	"c_echo": {"name": "메아리", "tag": "chain", "rarity": 1, "desc": "연쇄 도약 +1", "fx": {"chain_jumps": 1}},
	"c_leap": {"name": "먼 도약", "tag": "chain", "rarity": 0, "desc": "연쇄 거리 +2", "fx": {"chain_range": 2}},
	"c_hunt": {"name": "사냥 본능", "tag": "chain", "rarity": 0, "desc": "한 번에 둘 이상 쓰러뜨리면 체력 1 회복", "fx": {"heal_on_kill_multi": 1}},
	"c_react": {"name": "연쇄 반응", "tag": "chain", "rarity": 0, "desc": "적을 쓰러뜨릴 때마다 기름 +2", "fx": {"oil_on_kill": 2}},
	"c_reso": {"name": "공명", "tag": "chain", "rarity": 1, "desc": "한 번에 적 셋 이상을 맞히면 모두 피해 +1", "fx": {"dmg_crowd": 1}},
	"c_spark": {"name": "잔불 연결", "tag": "chain", "rarity": 1, "desc": "연쇄에 맞은 적은 화상 1", "fx": {"chain_burn": 1, "chain": 1}},
	"c_hand": {"name": "날랜 손", "tag": "chain", "rarity": 0, "desc": "등불 놓는 거리 +1", "fx": {"range": 1}},
	"c_cond": {"name": "전도체", "tag": "chain", "rarity": 0, "desc": "물길로 번진 그림자 피해 +1", "fx": {"water_dmg": 1}},
	"c_storm": {"name": "폭풍의 눈", "tag": "chain", "rarity": 2, "desc": "연쇄가 범위 안의 모든 적에게 번진다", "fx": {"chain_all": 1, "chain": 1}},
	# ── 거울 ──
	"m_mirror": {"name": "거울 각인", "tag": "mirror", "rarity": 0, "desc": "거울 빛 반경 +1", "fx": {"mirror_radius": 1.0}},
	"m_shard": {"name": "반사의 날", "tag": "mirror", "rarity": 0, "desc": "유리 파편 피해 +1", "fx": {"glass_dmg": 1}},
	"m_self": {"name": "은빛 피부", "tag": "mirror", "rarity": 1, "desc": "내 몸이 작은 거울이 되어 빛을 한 번 더 비춘다", "fx": {"player_mirror": 1}},
	"m_more": {"name": "거울 조각", "tag": "mirror", "rarity": 0, "desc": "방마다 거울 +1", "fx": {"extra_mirrors": 1}},
	"m_glass": {"name": "유리 장인", "tag": "mirror", "rarity": 0, "desc": "방마다 유리 기둥 +2", "fx": {"extra_glass": 2}},
	"m_refract": {"name": "굴절", "tag": "mirror", "rarity": 1, "desc": "거울 빛의 그림자 피해 +1", "fx": {"mirror_dmg": 1}},
	"m_twin": {"name": "두 개의 나", "tag": "mirror", "rarity": 2, "desc": "나를 기준으로 반대편에 등불의 거울상이 생긴다", "fx": {"mirror_copy": 1}},
	"m_glint": {"name": "반짝임", "tag": "mirror", "rarity": 0, "desc": "등불 반경 +0.5", "fx": {"radius": 0.5}},
	"m_stone": {"name": "돌 거울", "tag": "mirror", "rarity": 0, "desc": "기둥·상자의 그림자 피해 +1", "fx": {"pillar_dmg": 1}},
	"m_path": {"name": "빛의 길", "tag": "mirror", "rarity": 1, "desc": "가까운 그림자(2칸 이내) 피해 +1", "fx": {"dmg_near": 1}},
	# ── 어둠 ──
	"d_dark": {"name": "어둠 각인", "tag": "dark", "rarity": 0, "desc": "그림자 길이 +1", "fx": {"length": 1}},
	"d_long": {"name": "긴 그림자", "tag": "dark", "rarity": 0, "desc": "먼 그림자(3칸 이상) 피해 +1", "fx": {"dmg_far": 1}},
	"d_linger": {"name": "남은 그림자", "tag": "dark", "rarity": 1, "desc": "그림자가 한 턴 남아 적 턴 끝에 피해 1", "fx": {"linger": 1}},
	"d_blade": {"name": "그림자 칼", "tag": "dark", "rarity": 0, "desc": "내 그림자 피해 +1", "fx": {"player_shadow_dmg": 1}},
	"d_wide": {"name": "넓은 그림자", "tag": "dark", "rarity": 1, "desc": "내 그림자가 양옆으로 넓어진다", "fx": {"player_wide": 1}},
	"d_step": {"name": "그림자 걸음", "tag": "dark", "rarity": 2, "desc": "지난 턴 내 그림자 위라면 어디로든 이동", "fx": {"shadow_step": 1}},
	"d_night": {"name": "밤의 가호", "tag": "dark", "rarity": 0, "desc": "최대 체력 +2", "fx": {"max_hp": 2}},
	"d_pact": {"name": "어둠의 계약", "tag": "dark", "rarity": 1, "desc": "그림자 피해 +1, 등불 반경 -0.5", "fx": {"dmg": 1, "radius": -0.5}},
	"d_dagger": {"name": "그림자 단검", "tag": "dark", "rarity": 0, "desc": "내 곁의 적에게 피해 +2", "fx": {"dmg_adjacent": 2}},
	"d_pitch": {"name": "칠흑", "tag": "dark", "rarity": 1, "desc": "체력이 절반 이하일 때 피해 +2", "fx": {"dmg_low_hp": 2}},
}

const RELICS := {
	"r_match": {"name": "여행자의 성냥", "desc": "방마다 첫 점화 피해 +2", "fx": {"first_cast_dmg": 2}},
	"r_oilbag": {"name": "기름 주머니", "desc": "얻는 기름 +50%", "fx": {"oil_gain": 50}},
	"r_crackmirror": {"name": "금 간 손거울", "desc": "내 몸이 작은 거울이 되어 빛을 한 번 더 비춘다", "fx": {"player_mirror": 1}},
	"r_moonshard": {"name": "달 조각", "desc": "그림자 길이 +1", "fx": {"length": 1}},
	"r_bigwick": {"name": "굵은 심지", "desc": "등불 반경 +1", "fx": {"radius": 1.0}},
	"r_boots": {"name": "가벼운 장화", "desc": "이동력 +1", "fx": {"move": 1}},
	"r_hourglass": {"name": "되감기 모래시계", "desc": "되돌리기 +2", "fx": {"undo": 2}},
	"r_phoenix": {"name": "불사조 깃털", "desc": "한 번 쓰러져도 체력 절반으로 일어난다", "fx": {"revive": 1}},
	"r_shield": {"name": "그을린 방패", "desc": "적 턴마다 받는 피해 1 막기", "fx": {"ward": 1}},
	"r_cloak": {"name": "가시 망토", "desc": "나를 때린 적은 피해 1", "fx": {"thorns": 1}},
	"r_iceheart": {"name": "얼음 심장", "desc": "적이 굳는 시간 +1턴", "fx": {"freeze_duration": 1}},
	"r_venomwick": {"name": "독 바른 심지", "desc": "그림자에 맞은 적에게 독 1", "fx": {"poison_on_hit": 1}},
	"r_coalring": {"name": "숯불 반지", "desc": "그림자에 맞은 적에게 화상 1", "fx": {"burn_on_hit": 1}},
	"r_chainlink": {"name": "사슬 고리", "desc": "적을 쓰러뜨리면 가까운 적에게 피해 1이 튄다", "fx": {"chain": 1}},
	"r_sandglass": {"name": "모래 유리", "desc": "유리 파편 피해 +2, 방마다 유리 기둥 +2", "fx": {"glass_dmg": 2, "extra_glass": 2}},
	"r_wetglove": {"name": "젖은 장갑", "desc": "물길 그림자 피해 +1", "fx": {"water_dmg": 1}},
	"r_pillarblessing": {"name": "기둥의 축복", "desc": "기둥·상자 그림자 피해 +1", "fx": {"pillar_dmg": 1}},
	"r_lonely": {"name": "고독한 등불", "desc": "적 하나만 맞히면 그 적에게 피해 +2", "fx": {"solo_dmg": 2}},
	"r_pack": {"name": "무리 사냥", "desc": "한 번에 적 셋 이상을 맞히면 모두 피해 +1", "fx": {"dmg_crowd": 1}},
	"r_bloodpact": {"name": "피의 계약", "desc": "그림자 피해 +2, 최대 체력 -3", "fx": {"dmg": 2, "max_hp": -3}},
	"r_secondshadow": {"name": "두 번째 그림자", "desc": "내 그림자가 양옆으로 넓어진다", "fx": {"player_wide": 1}},
	"r_starmap": {"name": "별빛 지도", "desc": "보상 선택지 +1", "fx": {"reward_choices": 1}},
	"r_seal": {"name": "상인의 인장", "desc": "상점 가격 -25%", "fx": {"shop_discount": 25}},
	"r_tea": {"name": "쉼의 차", "desc": "휴식 회복량 +20%", "fx": {"rest_heal_bonus": 20}},
	"r_ashcrown": {"name": "재의 왕관", "desc": "얻는 불씨 +50%", "fx": {"ember_gain": 50}},
	"r_brokenclock": {"name": "멈춘 시계", "desc": "방마다 적이 첫 턴을 쉰다", "fx": {"start_freeze": 1}},
	"r_hungryflame": {"name": "굶주린 불꽃", "desc": "점화로 적을 쓰러뜨리면 체력 1 회복", "fx": {"heal_on_kill": 1}},
	"r_swingstand": {"name": "흔들리는 촛대", "desc": "적 턴이 끝나면 마지막 등불이 한 번 더 빛난다 (피해 1)", "fx": {"echo": 1}},
	"r_dagger": {"name": "그림자 단도", "desc": "내 곁의 적에게 피해 +2", "fx": {"dmg_adjacent": 2}},
	"r_night": {"name": "영원한 밤", "desc": "그림자가 한 턴 남아 적 턴 끝에 피해 1", "fx": {"linger": 1}},
	"r_frostcrown": {"name": "서리 왕관", "desc": "그림자 둘 이상에 동시에 맞은 적은 굳는다", "fx": {"freeze_on_multi": 1}},
	"r_fireheart": {"name": "불꽃 심장", "desc": "화상 입은 적이 쓰러지면 주변에 폭발 피해 1", "fx": {"burning_explode": 1}},
	"r_fang": {"name": "독사의 이빨", "desc": "독이 줄어들지 않는다", "fx": {"poison_no_decay": 1}},
	"r_bell": {"name": "공명하는 종", "desc": "연쇄 도약 +1", "fx": {"chain_jumps": 1, "chain": 1}},
	"r_lens": {"name": "수정 렌즈", "desc": "거울 빛 반경 +1, 방마다 거울 +1", "fx": {"mirror_radius": 1.0, "extra_mirrors": 1}},
	"r_heavy": {"name": "무거운 등잔", "desc": "그림자 피해 +1, 등불 놓는 거리 -1", "fx": {"dmg": 1, "range": -1}},
	# ── 저주 (강하지만 대가가 있다. 휴식처에서 정화할 수 있다) ──
	"x_mask": {"name": "그을음 가면", "curse": true, "desc": "저주: 적 체력 +1. 대신 얻는 기름 +100%", "fx": {"enemy_hp": 1, "oil_gain": 100}},
	"x_wick": {"name": "금 간 심지", "curse": true, "desc": "저주: 등불 반경 -1. 대신 그림자 길이 +2", "fx": {"radius": -1.0, "length": 2}},
	"x_coin": {"name": "피 묻은 동전", "curse": true, "desc": "저주: 휴식으로 회복할 수 없다. 대신 그림자 피해 +1", "fx": {"no_rest_heal": 1, "dmg": 1}},
	"x_greed": {"name": "탐욕의 그림자", "curse": true, "desc": "저주: 방마다 체력 -1. 대신 적을 쓰러뜨릴 때 기름 +3", "fx": {"hp_loss_room": 1, "oil_on_kill": 3}},
}


static func inscription(id: String) -> Dictionary:
	return INSCRIPTIONS.get(id, {})


static func relic(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func normal_relic_ids() -> Array:
	var out := []
	for k in RELICS.keys():
		if not RELICS[k].get("curse", false):
			out.append(k)
	return out


static func curse_ids() -> Array:
	var out := []
	for k in RELICS.keys():
		if RELICS[k].get("curse", false):
			out.append(k)
	return out
