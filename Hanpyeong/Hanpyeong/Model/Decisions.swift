import Foundation

// 하루가 끝날 때 가끔 찾아오는 '결정할 일'. 금액은 그때의 하루 매출 규모(scale)에 비례한다.

enum DecisionEffect: Hashable {
    /// 하루 매출 규모 × 배수 만큼 현금 증감
    case cash(Double)
    case reputation(Double)
    /// 며칠간 전 점포 매출 배율
    case boost(Double, Int, String)
}

struct DecisionOption: Hashable {
    let label: String
    let hint: String
    /// 성공 확률 (1 = 확정)
    var chance: Double = 1
    let success: [DecisionEffect]
    let successText: String
    var failure: [DecisionEffect] = []
    var failureText: String = ""
}

struct Decision: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let symbol: String
    var minRank = 0
    var maxRank = 8
    let options: [DecisionOption]

    static func find(_ id: String) -> Decision? { all.first { $0.id == id } }

    static let all: [Decision] = [
        Decision(id: "credit", title: "외상 부탁", body: "단골 할머니가 이번 달 연금이 늦게 나온다며 외상을 부탁하신다.",
                 symbol: "person.fill.questionmark", maxRank: 3, options: [
                    DecisionOption(label: "장부에 달아드린다", hint: "작은 손해, 동네 인심",
                                   success: [.cash(-0.1), .reputation(5)],
                                   successText: "할머니가 동네방네 소문을 내주셨다. \"저 집 사장 사람 좋아.\""),
                    DecisionOption(label: "정중히 거절한다", hint: "원칙은 원칙",
                                   success: [.reputation(-2)],
                                   successText: "할머니가 서운한 얼굴로 돌아가셨다.")
                 ]),
        Decision(id: "rentHike", title: "건물주의 문자", body: "\"사장님, 다음 달부터 월세 좀 올려야겠어요.\" 협상해 볼까?",
                 symbol: "envelope.fill", options: [
                    DecisionOption(label: "순순히 받아들인다", hint: "확실한 지출",
                                   success: [.cash(-0.5)],
                                   successText: "인상분을 냈다. 건물주와 사이는 좋다."),
                    DecisionOption(label: "협상한다", hint: "60% 확률로 동결", chance: 0.6,
                                   success: [.reputation(1)],
                                   successText: "\"그래요, 사장님 성실하시니까.\" 동결에 성공했다.",
                                   failure: [.cash(-1.0), .reputation(-2)],
                                   failureText: "건물주가 기분이 상했다. 더 큰 인상안을 받았다.")
                 ]),
        Decision(id: "tvShow", title: "방송국 섭외 전화", body: "'생활의 고수' 작가에게서 연락이 왔다. 촬영하면 가게 하루를 비워야 한다.",
                 symbol: "tv.fill", options: [
                    DecisionOption(label: "출연한다", hint: "준비비 들지만 대박 가능",
                                   success: [.cash(-0.3), .reputation(8), .boost(1.35, 3, "방송 출연 효과")],
                                   successText: "방송이 나가자 전화가 빗발친다. 3일간 손님 +35%."),
                    DecisionOption(label: "정중히 거절한다", hint: "조용히 장사",
                                   success: [], successText: "평소처럼 하루가 흘렀다.")
                 ]),
        Decision(id: "inspection", title: "위생 점검 예고", body: "구청에서 이번 주 위생 점검을 나온다는 소문이 돈다.",
                 symbol: "checkmark.shield.fill", options: [
                    DecisionOption(label: "대청소와 설비 점검", hint: "확실하게",
                                   success: [.cash(-0.3), .reputation(2)],
                                   successText: "점검관이 \"깨끗하네요\" 하고 돌아갔다."),
                    DecisionOption(label: "운에 맡긴다", hint: "70% 무사", chance: 0.7,
                                   success: [], successText: "점검은 다른 동네로 갔다. 휴.",
                                   failure: [.cash(-1.5), .reputation(-10)],
                                   failureText: "과태료에 지역 뉴스까지 탔다. 손님들이 수군댄다.")
                 ]),
        Decision(id: "badReview", title: "별점 테러", body: "지도 앱에 별 하나짜리 리뷰가 달렸다. \"불친절, 다신 안 감.\"",
                 symbol: "star.slash.fill", options: [
                    DecisionOption(label: "정중하게 사과 답글", hint: "무난한 대응",
                                   success: [.reputation(3)],
                                   successText: "다른 손님들이 \"사장님 답글 보고 왔어요\" 한다."),
                    DecisionOption(label: "조목조목 반박한다", hint: "도박. 50%", chance: 0.5,
                                   success: [.reputation(6)],
                                   successText: "알고 보니 경쟁 가게 직원의 글이었다. 여론이 내 편이다.",
                                   failure: [.reputation(-12)],
                                   failureText: "'사장님 갑질 답글' 캡처가 커뮤니티에 돌았다."),
                    DecisionOption(label: "무시한다", hint: "신경 끄기",
                                   success: [.reputation(-3)],
                                   successText: "리뷰가 맨 위에 계속 떠 있다.")
                 ]),
        Decision(id: "raise", title: "직원들의 면담 요청", body: "직원 대표가 찾아왔다. \"최저임금도 올랐는데, 저희도…\"",
                 symbol: "person.2.fill", minRank: 1, options: [
                    DecisionOption(label: "시원하게 올려준다", hint: "지출, 대신 사기 충전",
                                   success: [.cash(-0.4), .reputation(4), .boost(1.1, 3, "직원 사기 충전")],
                                   successText: "직원들 표정이 밝아졌다. 3일간 매출 +10%."),
                    DecisionOption(label: "지금은 어렵다", hint: "버티기",
                                   success: [.reputation(-5), .boost(0.9, 3, "직원 사기 저하")],
                                   successText: "분위기가 싸해졌다. 3일간 매출 -10%.")
                 ]),
        Decision(id: "donation", title: "복지관의 부탁", body: "동네 복지관에서 연말 김장 나눔에 후원해줄 수 있는지 묻는다.",
                 symbol: "gift.fill", options: [
                    DecisionOption(label: "후원한다", hint: "평판 크게 상승",
                                   success: [.cash(-0.5), .reputation(10)],
                                   successText: "복지관 게시판에 가게 이름이 붙었다."),
                    DecisionOption(label: "다음에 하겠다", hint: "지출 없음",
                                   success: [], successText: "담당자가 아쉬워하며 돌아갔다.")
                 ]),
        Decision(id: "scam", title: "수상한 투자 제안", body: "\"월 30% 수익 보장! 사장님만 특별히 모십니다.\" 낯선 사람이 명함을 내민다.",
                 symbol: "exclamationmark.triangle.fill", options: [
                    DecisionOption(label: "솔깃하다, 투자한다", hint: "10% 확률로 대박?", chance: 0.1,
                                   success: [.cash(4)],
                                   successText: "믿기 힘들지만 진짜 수익이 났다. 다신 이런 운 없다.",
                                   failure: [.cash(-2)],
                                   failureText: "연락이 끊겼다. 뉴스에 같은 수법 사기 기사가 떴다."),
                    DecisionOption(label: "경찰에 신고한다", hint: "원금 보장은 사기의 신호",
                                   success: [.reputation(3)],
                                   successText: "같은 수법 피해자가 많았다. 경찰서에서 감사장을 받았다.")
                 ]),
        Decision(id: "thief", title: "계산대가 비었다", body: "마감 정산을 하는데 돈이 맞지 않는다. 며칠째다.",
                 symbol: "video.fill", options: [
                    DecisionOption(label: "CCTV를 단다", hint: "확실한 예방",
                                   success: [.cash(-0.3)],
                                   successText: "범인은 뒷문으로 드나들던 좀도둑이었다. 다시는 안 온다."),
                    DecisionOption(label: "그냥 지켜본다", hint: "40% 확률로 또 털림", chance: 0.6,
                                   success: [], successText: "그 뒤로는 돈이 맞았다.",
                                   failure: [.cash(-1)], failureText: "또 털렸다. 이번엔 더 많이.")
                 ]),
        Decision(id: "youtuber", title: "유튜버 협찬 제안", body: "구독자 20만 먹방 유튜버가 협찬을 원한다. 출연료를 달라고 한다.",
                 symbol: "play.rectangle.fill", options: [
                    DecisionOption(label: "협찬한다", hint: "반반 도박", chance: 0.5,
                                   success: [.cash(-0.3), .boost(1.4, 3, "유튜브 영상 대박")],
                                   successText: "영상이 인기 급상승에 올랐다. 3일간 매출 +40%.",
                                   failure: [.cash(-0.3)],
                                   failureText: "조회수가 영 안 나왔다. 출연료만 나갔다."),
                    DecisionOption(label: "거절한다", hint: "",
                                   success: [], successText: "유튜버는 옆 가게로 갔다.")
                 ]),
        Decision(id: "blackout", title: "정전", body: "변압기 고장으로 상가 전체 전기가 나갔다. 복구까지 반나절.",
                 symbol: "bolt.slash.fill", options: [
                    DecisionOption(label: "발전기를 빌린다", hint: "돈으로 해결",
                                   success: [.cash(-0.25)],
                                   successText: "우리 가게만 불이 켜져 있다. 손님이 몰렸다."),
                    DecisionOption(label: "하루 쉰다", hint: "하루 매출 반토막",
                                   success: [.boost(0.5, 1, "정전 휴업")],
                                   successText: "모처럼 쉬었다. 내일 매출은 반토막.")
                 ]),
        Decision(id: "festival", title: "동네 축제 후원", body: "상인회에서 이번 주말 골목 축제를 연다. 후원 업체 모집 중.",
                 symbol: "party.popper.fill", options: [
                    DecisionOption(label: "메인 후원사로 참여", hint: "평판과 매출",
                                   success: [.cash(-0.4), .reputation(6), .boost(1.15, 2, "골목 축제")],
                                   successText: "현수막에 가게 이름이 크게 걸렸다."),
                    DecisionOption(label: "구경만 한다", hint: "",
                                   success: [.boost(1.05, 2, "골목 축제")],
                                   successText: "축제 덕에 손님이 조금 늘었다.")
                 ]),
        Decision(id: "bulk", title: "도매상의 특가 제안", body: "거래처 도매상이 재고 정리 중이라며 원재료를 반값에 넘기겠다고 한다.",
                 symbol: "shippingbox.fill", minRank: 1, options: [
                    DecisionOption(label: "대량으로 산다", hint: "선지출, 5일간 이익",
                                   success: [.cash(-1), .boost(1.25, 5, "원가 절감")],
                                   successText: "창고가 꽉 찼다. 5일간 마진 +25%."),
                    DecisionOption(label: "필요한 만큼만", hint: "",
                                   success: [], successText: "평소대로 들여왔다.")
                 ]),
        Decision(id: "rivalOpen", title: "길 건너 경쟁 가게", body: "길 건너편에 같은 업종 가게가 오픈 이벤트를 시작했다.",
                 symbol: "flag.2.crossed.fill", options: [
                    DecisionOption(label: "맞불 할인 행사", hint: "지출로 방어",
                                   success: [.cash(-0.3), .reputation(2), .boost(1.1, 3, "할인 행사")],
                                   successText: "단골들이 \"역시 원조\"라며 돌아왔다."),
                    DecisionOption(label: "품질로 버틴다", hint: "3일간 손님 감소",
                                   success: [.boost(0.9, 3, "경쟁 가게 오픈")],
                                   successText: "며칠은 손님을 뺏겼다.")
                 ]),
        Decision(id: "scout", title: "에이스 직원 스카우트", body: "가장 일 잘하는 직원이 대기업에서 스카우트 제안을 받았다고 털어놓는다.",
                 symbol: "person.crop.circle.badge.exclamationmark", minRank: 2, options: [
                    DecisionOption(label: "연봉을 올려 붙잡는다", hint: "지출",
                                   success: [.cash(-0.5), .reputation(2)],
                                   successText: "\"사장님 믿고 남겠습니다.\""),
                    DecisionOption(label: "축하하며 보낸다", hint: "3일간 공백",
                                   success: [.reputation(3), .boost(0.92, 3, "에이스 공백")],
                                   successText: "송별회를 열어줬다. 빈자리가 크다.")
                 ]),
        Decision(id: "taxAudit", title: "세무조사 통지서", body: "국세청에서 정기 세무조사 통지가 왔다.",
                 symbol: "doc.text.fill", minRank: 3, options: [
                    DecisionOption(label: "세무사와 성실 대응", hint: "확실한 비용",
                                   success: [.cash(-0.5)],
                                   successText: "장부가 깔끔해 금방 끝났다."),
                    DecisionOption(label: "알아서 버틴다", hint: "50% 확률로 추징", chance: 0.5,
                                   success: [], successText: "별 문제 없이 끝났다.",
                                   failure: [.cash(-3), .reputation(-5)],
                                   failureText: "누락된 신고가 발견돼 가산세까지 추징당했다.")
                 ]),
        Decision(id: "wallet", title: "손님이 두고 간 지갑", body: "마감 후 테이블 밑에서 두툼한 지갑을 발견했다.",
                 symbol: "wallet.pass.fill", options: [
                    DecisionOption(label: "경찰서에 맡긴다", hint: "당연한 일",
                                   success: [.reputation(5)],
                                   successText: "주인이 사례하겠다는 걸 사양했다. 가게 칭찬 글이 올라왔다."),
                    DecisionOption(label: "가게에 보관해 둔다", hint: "주인이 찾으러 오길",
                                   success: [.reputation(2)],
                                   successText: "다음 날 주인이 찾아가며 음료를 잔뜩 사갔다.")
                 ]),
        Decision(id: "interview", title: "경제지 인터뷰", body: "\"골목에서 시작한 성공 신화\" 기획 기사 인터뷰 요청이 들어왔다.",
                 symbol: "newspaper.fill", minRank: 3, options: [
                    DecisionOption(label: "인터뷰한다", hint: "평판 상승",
                                   success: [.reputation(5), .boost(1.1, 2, "인터뷰 기사")],
                                   successText: "기사가 포털 메인에 걸렸다."),
                    DecisionOption(label: "사양한다", hint: "",
                                   success: [], successText: "조용한 게 좋다.")
                 ]),
        Decision(id: "subsidy", title: "소상공인 지원금", body: "구청에서 소상공인 경영 안정 지원금 신청을 받는다. 서류가 좀 많다.",
                 symbol: "banknote.fill", maxRank: 2, options: [
                    DecisionOption(label: "서류 챙겨 신청한다", hint: "",
                                   success: [.cash(0.8)],
                                   successText: "지원금이 통장에 들어왔다."),
                    DecisionOption(label: "귀찮다, 넘긴다", hint: "",
                                   success: [], successText: "신청 기간이 지나갔다.")
                 ]),
        Decision(id: "union", title: "상인회장 추대", body: "상인회 정기 총회에서 다음 회장으로 사장님을 추대하자는 말이 나왔다.",
                 symbol: "person.3.fill", minRank: 1, maxRank: 4, options: [
                    DecisionOption(label: "맡겠다", hint: "평판 크게, 회비 부담",
                                   success: [.cash(-0.3), .reputation(8)],
                                   successText: "\"회장님\" 소리를 듣기 시작했다."),
                    DecisionOption(label: "고사한다", hint: "",
                                   success: [], successText: "다른 사장님이 맡았다.")
                 ]),
        Decision(id: "mna", title: "인수 제안", body: "중견 기업에서 회사 지분 일부를 사겠다며 프리미엄을 얹은 가격을 제시했다.",
                 symbol: "signature", minRank: 4, options: [
                    DecisionOption(label: "일부 지분만 판다", hint: "현금 확보",
                                   success: [.cash(3), .reputation(-2)],
                                   successText: "현금이 들어왔다. 업계에선 '팔았다'는 말이 돈다."),
                    DecisionOption(label: "독립 경영을 지킨다", hint: "",
                                   success: [.reputation(4)],
                                   successText: "\"우리 회사는 안 팝니다.\" 직원들이 박수를 쳤다.")
                 ]),
        Decision(id: "esg", title: "ESG 경영 요구", body: "투자자들이 친환경 포장과 탄소 감축 계획을 요구한다.",
                 symbol: "leaf.fill", minRank: 5, options: [
                    DecisionOption(label: "전사 도입한다", hint: "큰 지출, 장기 평판",
                                   success: [.cash(-1), .reputation(8), .boost(1.1, 5, "ESG 경영 호평")],
                                   successText: "ESG 평가 A등급. 착한 기업 이미지가 생겼다."),
                    DecisionOption(label: "시늉만 한다", hint: "50% 들통", chance: 0.5,
                                   success: [], successText: "무사히 넘어갔다.",
                                   failure: [.reputation(-10)],
                                   failureText: "'그린워싱' 기사가 났다.")
                 ]),
        Decision(id: "worldCup", title: "국가대표 경기 날", body: "오늘 밤 월드컵 16강전이 열린다. 단체 응원 이벤트를 열까?",
                 symbol: "soccerball", options: [
                    DecisionOption(label: "대형 스크린 설치", hint: "지출, 대목",
                                   success: [.cash(-0.3), .boost(1.5, 1, "단체 응원")],
                                   successText: "골이 터질 때마다 주문이 쏟아졌다."),
                    DecisionOption(label: "평소대로 영업", hint: "",
                                   success: [.boost(1.1, 1, "경기 특수")],
                                   successText: "그래도 손님이 꽤 왔다.")
                 ])
    ]
}
