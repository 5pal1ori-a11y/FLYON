import SwiftUI

struct Service: Hashable {
    let name: String
    let aliases: [String]
    let category: Category
    let color: UInt32
    let mark: String        // 로고 에셋이 없을 때 쓰는 이니셜
    let cancelURL: String
    let defaultPrice: Int
    var assetName: String { "logo_" + name }
}

/// 공식 로고 파일은 Assets.xcassets 에 `logo_서비스명` 이름으로 넣으면 자동으로 사용돼요.
/// (예: logo_넷플릭스). 없으면 브랜드 색 + 이니셜로 보여줘요.
enum Catalog {
    static let all: [Service] = [
        Service(name: "넷플릭스", aliases: ["netflix", "넷플"], category: .ott, color: 0x141414, mark: "N", cancelURL: "https://www.netflix.com/cancelplan", defaultPrice: 17000),
        Service(name: "유튜브 프리미엄", aliases: ["youtube", "유튜브", "youtube premium"], category: .ott, color: 0xFF0000, mark: "▶", cancelURL: "https://www.youtube.com/paid_memberships", defaultPrice: 14900),
        Service(name: "티빙", aliases: ["tving"], category: .ott, color: 0xFF153C, mark: "T", cancelURL: "https://www.tving.com/account", defaultPrice: 13900),
        Service(name: "웨이브", aliases: ["wavve", "웨에브"], category: .ott, color: 0x1351F9, mark: "W", cancelURL: "https://www.wavve.com/my", defaultPrice: 13900),
        Service(name: "디즈니 플러스", aliases: ["disney", "디즈니", "disney+"], category: .ott, color: 0x0B2A4A, mark: "D+", cancelURL: "https://www.disneyplus.com/account", defaultPrice: 13900),
        Service(name: "쿠팡 와우", aliases: ["coupang", "쿠팡", "와우"], category: .membership, color: 0xE52528, mark: "C", cancelURL: "https://www.coupang.com/np/mypage", defaultPrice: 7890),
        Service(name: "스포티파이", aliases: ["spotify"], category: .ott, color: 0x1DB954, mark: "S", cancelURL: "https://www.spotify.com/account/subscription", defaultPrice: 10900),
        Service(name: "멜론", aliases: ["melon"], category: .ott, color: 0x00CD3C, mark: "M", cancelURL: "https://www.melon.com", defaultPrice: 13200),
        Service(name: "플로", aliases: ["flo"], category: .ott, color: 0x3F3FFF, mark: "F", cancelURL: "https://www.music-flo.com", defaultPrice: 10900),
        Service(name: "ChatGPT", aliases: ["gpt", "지피티", "챗지피티", "openai", "chat gpt"], category: .ai, color: 0x10A37F, mark: "G", cancelURL: "https://chatgpt.com/#settings/Account", defaultPrice: 29000),
        Service(name: "Claude", aliases: ["클로드", "anthropic"], category: .ai, color: 0xD97757, mark: "C", cancelURL: "https://claude.ai/settings/billing", defaultPrice: 28000),
        Service(name: "Gemini", aliases: ["제미나이", "google one", "구글 원"], category: .ai, color: 0x4285F4, mark: "G", cancelURL: "https://one.google.com/settings", defaultPrice: 29000),
        Service(name: "Creative Cloud", aliases: ["adobe", "어도비"], category: .etc, color: 0xFA0F00, mark: "Cc", cancelURL: "https://account.adobe.com/plans", defaultPrice: 78100),
        Service(name: "iCloud+", aliases: ["icloud", "아이클라우드"], category: .etc, color: 0x3693F5, mark: "☁︎", cancelURL: "https://support.apple.com/ko-kr/118428", defaultPrice: 1100),
        Service(name: "네이버 플러스 멤버십", aliases: ["naver", "네이버"], category: .membership, color: 0x03C75A, mark: "N", cancelURL: "https://nid.naver.com", defaultPrice: 4900),
        Service(name: "Nintendo Switch Online", aliases: ["닌텐도", "nintendo"], category: .game, color: 0xE60012, mark: "N", cancelURL: "https://accounts.nintendo.com", defaultPrice: 24000),
        Service(name: "PlayStation Plus", aliases: ["ps plus", "플스", "플레이스테이션"], category: .game, color: 0x003791, mark: "PS", cancelURL: "https://www.playstation.com/ko-kr/", defaultPrice: 9900),
        Service(name: "Xbox Game Pass", aliases: ["xbox", "게임패스"], category: .game, color: 0x107C10, mark: "X", cancelURL: "https://account.microsoft.com/services", defaultPrice: 13900),
        Service(name: "Microsoft 365", aliases: ["office", "오피스", "ms365"], category: .etc, color: 0xD83B01, mark: "M", cancelURL: "https://account.microsoft.com/services", defaultPrice: 14900),
        Service(name: "밀리의 서재", aliases: ["밀리"], category: .life, color: 0xFFD400, mark: "밀", cancelURL: "https://www.millie.co.kr", defaultPrice: 9900),
        Service(name: "헬스장", aliases: ["피트니스", "pt", "필라테스"], category: .health, color: 0xEF4444, mark: "H", cancelURL: "", defaultPrice: 50000),
        Service(name: "보험", aliases: ["실손", "화재", "생명", "손해", "자동차"], category: .insurance, color: 0x06B6D4, mark: "보", cancelURL: "", defaultPrice: 50000),
        Service(name: "정수기 렌탈", aliases: ["렌탈", "코웨이", "청호"], category: .life, color: 0xF59E0B, mark: "렌", cancelURL: "", defaultPrice: 30000),
    ]

    static func find(_ text: String) -> Service? {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return all.first { s in
            ([s.name.lowercased()] + s.aliases.map { $0.lowercased() }).contains { t.contains($0) || ($0.count >= 2 && $0.contains(t) && t.count >= 2) }
        }
    }
    static func search(_ q: String) -> [Service] {
        let t = q.lowercased()
        if t.isEmpty { return Array(all.prefix(8)) }
        return all.filter { s in ([s.name] + s.aliases).contains { $0.lowercased().contains(t) } }
    }
    /// 이름만 입력해도 카테고리 자동 분류
    static func classify(_ name: String) -> Category {
        if let s = find(name) { return s.category }
        let t = name.lowercased()
        let rules: [(Category, [String])] = [
            (.ott, ["tv", "영상", "음악", "music", "video", "플러스", "+"]),
            (.ai, ["ai", "gpt", "봇", "copilot", "perplexity", "midjourney"]),
            (.game, ["게임", "game", "pass", "steam", "플레이"]),
            (.insurance, ["보험", "생명", "화재", "손해"]),
            (.health, ["헬스", "운동", "요가", "필라", "병원", "영양제"]),
            (.membership, ["멤버십", "membership", "프라임", "prime", "club", "클럽"]),
            (.life, ["렌탈", "정수기", "통신", "인터넷", "구독배송", "청소"]),
        ]
        return rules.first { r in r.1.contains { t.contains($0) } }?.0 ?? .etc
    }
}

struct LogoView: View {
    let name: String
    var category: Category = .etc
    var size: CGFloat = 44
    var body: some View {
        let svc = Catalog.find(name)
        ZStack {
            if let svc, UIImage(named: svc.assetName) != nil {
                Image(svc.assetName).resizable().scaledToFill()
            } else if let svc {
                Color(hex: svc.color)
                Text(svc.mark).font(.system(size: size * 0.42, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            } else {
                category.color.opacity(0.15)
                Image(systemName: category.icon).font(.system(size: size * 0.42)).foregroundStyle(category.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
