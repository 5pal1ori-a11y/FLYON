import Foundation

/// 하루가 끝날 때 굴리는 뉴스. 매출 배율 이벤트(기간제)와 시세 급변(즉시)이 있다.
enum NewsDesk {
    enum Outcome {
        case lasting(MarketEvent, NewsItem)
        case indexShock(DistrictID, Double, NewsItem)
    }

    static func roll(day: Int, districts: [DistrictID], kinds: [BusinessKind]) -> Outcome? {
        guard Double.random(in: 0..<1) < 0.4,
              let d = districts.randomElement(),
              let k = kinds.randomElement() else { return nil }

        let name = d.info.name
        let kind = k.info.title

        switch Int.random(in: 0..<10) {
        case 0:
            let days = Int.random(in: 2...4)
            return lasting(.traffic(d, 1.4), days: days, day: day,
                           headline: ["\(name) 축제 시즌 개막", "\(name)에 버스킹 거리 공연", "\(name) 야시장 개장"].randomElement()!,
                           detail: "\(days)일간 \(name) 손님 +40%", tone: .good)
        case 1:
            let days = Int.random(in: 2...3)
            return lasting(.traffic(d, 0.7), days: days, day: day,
                           headline: ["\(name) 도로 공사로 통행 막혀", "\(name) 상수도 공사 시작", "\(name) 주차 단속 강화"].randomElement()!,
                           detail: "\(days)일간 \(name) 손님 -30%", tone: .bad)
        case 2:
            let days = Int.random(in: 2...3)
            return lasting(.business(k, 1.5), days: days, day: day,
                           headline: ["SNS에서 '\(kind)' 열풍", "'\(kind)' 먹방 영상 조회수 1,000만", "연예인 단골 \(kind) 화제", "MZ세대 사이 '\(kind)' 붐"].randomElement()!,
                           detail: "\(days)일간 \(kind) 매출 +50%", tone: .good)
        case 3:
            let days = Int.random(in: 2...3)
            return lasting(.business(k, 0.75), days: days, day: day,
                           headline: ["\(kind) 업계 원가 급등", "\(kind) 관련 위생 논란 확산", "\(kind) 과포화, 출혈 경쟁"].randomElement()!,
                           detail: "\(days)일간 \(kind) 매출 -25%", tone: .bad)
        case 4:
            let days = Int.random(in: 3...5)
            return lasting(.economy(0.85), days: days, day: day,
                           headline: ["소비 심리 위축, 지갑 닫혔다", "금리 인상 여파, 외식 줄어", "물가 급등에 소비 한파"].randomElement()!,
                           detail: "\(days)일간 전 점포 매출 -15%", tone: .bad)
        case 5:
            let days = Int.random(in: 2...4)
            return lasting(.economy(1.2), days: days, day: day,
                           headline: ["황금연휴 소비 폭발", "명절 대목, 지갑이 열렸다", "보너스 시즌, 소비 심리 회복"].randomElement()!,
                           detail: "\(days)일간 전 점포 매출 +20%", tone: .good)
        case 6:
            let pct = Double.random(in: 0.12...0.25)
            let headlines = ["\(name) 재개발 확정 발표", "\(name) 지하철 신설 노선 확정", "\(name)에 대기업 사옥 이전 소식"]
            return .indexShock(d, pct, NewsItem(day: day, headline: headlines.randomElement()!,
                                                detail: "\(name) 시세 +\(Int(pct * 100))%", tone: .good))
        case 7:
            let pct = -Double.random(in: 0.10...0.22)
            let headlines = ["\(name) 공실률 급증", "\(name) 재개발 무산", "\(name) 앵커 매장 철수"]
            return .indexShock(d, pct, NewsItem(day: day, headline: headlines.randomElement()!,
                                                detail: "\(name) 시세 \(Int(pct * 100))%", tone: .bad))
        case 8:
            let days = Int.random(in: 2...3)
            return lasting(.traffic(d, 1.25), days: days, day: day,
                           headline: "방송 맛집 프로그램, \(name) 촬영",
                           detail: "\(days)일간 \(name) 손님 +25%", tone: .good)
        default:
            let days = Int.random(in: 1...2)
            return lasting(.economy(0.9), days: days, day: day,
                           headline: "장마 시작, 거리 한산",
                           detail: "\(days)일간 전 점포 매출 -10%", tone: .bad)
        }
    }

    private static func lasting(_ effect: EventEffect, days: Int, day: Int,
                                headline: String, detail: String, tone: NewsItem.Tone) -> Outcome {
        .lasting(MarketEvent(effect: effect, daysLeft: days, headline: detail),
                 NewsItem(day: day, headline: headline, detail: detail, tone: tone))
    }
}
