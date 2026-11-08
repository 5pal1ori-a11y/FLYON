import SwiftUI

struct Service: Hashable {
    let name: String
    let aliases: [String]
    let category: Category
    let color: UInt32
    let mark: String        // 로고 에셋이 없을 때 쓰는 이니셜
    let cancelURL: String
    let defaultPrice: Int
    /// 2026년 11월 기준 공개 자료로 확인한 요금이면 true
    var verified: Bool = false
    var assetName: String { "logo_" + name }
}

/// 공식 로고 파일은 Assets.xcassets 에 `logo_서비스명` 이름으로 넣으면 자동으로 사용돼요.
/// (예: logo_넷플릭스). 없으면 브랜드 색 + 이니셜로 보여줘요.
enum Catalog {
    static let all: [Service] = [
        Service(name: "넷플릭스", aliases: ["netflix", "넷플"], category: .ott, color: 0x141414, mark: "N", cancelURL: "https://www.netflix.com/cancelplan", defaultPrice: 13500, verified: true),
        Service(name: "유튜브 프리미엄", aliases: ["youtube", "유튜브", "youtube premium"], category: .ott, color: 0xFF0000, mark: "▶", cancelURL: "https://www.youtube.com/paid_memberships", defaultPrice: 14900, verified: true),
        Service(name: "티빙", aliases: ["tving"], category: .ott, color: 0xFF153C, mark: "T", cancelURL: "https://www.tving.com/account", defaultPrice: 13900),
        Service(name: "웨이브", aliases: ["wavve", "웨에브"], category: .ott, color: 0x1351F9, mark: "W", cancelURL: "https://www.wavve.com/my", defaultPrice: 13900),
        Service(name: "디즈니 플러스", aliases: ["disney", "디즈니", "disney+"], category: .ott, color: 0x0B2A4A, mark: "D+", cancelURL: "https://www.disneyplus.com/account", defaultPrice: 13900),
        Service(name: "쿠팡 와우", aliases: ["coupang", "쿠팡", "와우"], category: .membership, color: 0xE52528, mark: "C", cancelURL: "https://www.coupang.com/np/mypage", defaultPrice: 7890, verified: true),
        Service(name: "스포티파이", aliases: ["spotify"], category: .ott, color: 0x1DB954, mark: "S", cancelURL: "https://www.spotify.com/account/subscription", defaultPrice: 10900),
        Service(name: "멜론", aliases: ["melon"], category: .ott, color: 0x00CD3C, mark: "M", cancelURL: "https://www.melon.com", defaultPrice: 13200),
        Service(name: "플로", aliases: ["flo"], category: .ott, color: 0x3F3FFF, mark: "F", cancelURL: "https://www.music-flo.com", defaultPrice: 10900),
        Service(name: "ChatGPT", aliases: ["gpt", "지피티", "챗지피티", "openai", "chat gpt"], category: .ai, color: 0x10A37F, mark: "G", cancelURL: "https://chatgpt.com/#settings/Account", defaultPrice: 29000),
        Service(name: "Claude", aliases: ["클로드", "anthropic"], category: .ai, color: 0xD97757, mark: "C", cancelURL: "https://claude.ai/settings/billing", defaultPrice: 28000),
        Service(name: "Gemini", aliases: ["제미나이", "google one", "구글 원"], category: .ai, color: 0x4285F4, mark: "G", cancelURL: "https://one.google.com/settings", defaultPrice: 29000, verified: true),
        Service(name: "Creative Cloud", aliases: ["adobe", "어도비"], category: .etc, color: 0xFA0F00, mark: "Cc", cancelURL: "https://account.adobe.com/plans", defaultPrice: 78100),
        Service(name: "iCloud+", aliases: ["icloud", "아이클라우드"], category: .etc, color: 0x3693F5, mark: "☁︎", cancelURL: "https://support.apple.com/ko-kr/118428", defaultPrice: 1100),
        Service(name: "네이버 플러스 멤버십", aliases: ["naver", "네이버"], category: .membership, color: 0x03C75A, mark: "N", cancelURL: "https://nid.naver.com", defaultPrice: 4900),
        Service(name: "Nintendo Switch Online", aliases: ["닌텐도", "nintendo"], category: .game, color: 0xE60012, mark: "N", cancelURL: "https://accounts.nintendo.com", defaultPrice: 24000),
        Service(name: "PlayStation Plus", aliases: ["ps plus", "플스", "플레이스테이션"], category: .game, color: 0x003791, mark: "PS", cancelURL: "https://www.playstation.com/ko-kr/", defaultPrice: 9900),
        Service(name: "Xbox Game Pass", aliases: ["xbox", "게임패스"], category: .game, color: 0x107C10, mark: "X", cancelURL: "https://account.microsoft.com/services", defaultPrice: 13900),
        Service(name: "Microsoft 365", aliases: ["office", "오피스", "ms365"], category: .etc, color: 0xD83B01, mark: "M", cancelURL: "https://account.microsoft.com/services", defaultPrice: 14900),
        Service(name: "밀리의 서재", aliases: ["밀리"], category: .life, color: 0xFFD400, mark: "밀", cancelURL: "https://www.millie.co.kr", defaultPrice: 9900),
        Service(name: "왓챠", aliases: ["watcha"], category: .ott, color: 0xFF0558, mark: "W", cancelURL: "https://watcha.com/settings", defaultPrice: 12900),
        Service(name: "라프텔", aliases: ["laftel"], category: .ott, color: 0x6C5CE7, mark: "L", cancelURL: "https://laftel.net", defaultPrice: 14900),
        Service(name: "쿠팡플레이", aliases: ["coupang play"], category: .ott, color: 0xE52528, mark: "▶", cancelURL: "https://www.coupang.com/np/mypage", defaultPrice: 7890),
        Service(name: "애플 TV+", aliases: ["apple tv", "appletv"], category: .ott, color: 0x000000, mark: "tv", cancelURL: "https://support.apple.com/ko-kr/118428", defaultPrice: 9900),
        Service(name: "애플 뮤직", aliases: ["apple music"], category: .ott, color: 0xFA243C, mark: "♪", cancelURL: "https://support.apple.com/ko-kr/118428", defaultPrice: 10900),
        Service(name: "유튜브 뮤직", aliases: ["youtube music"], category: .ott, color: 0xFF0000, mark: "♪", cancelURL: "https://www.youtube.com/paid_memberships", defaultPrice: 10900),
        Service(name: "지니뮤직", aliases: ["genie", "지니"], category: .ott, color: 0x2D7BFF, mark: "G", cancelURL: "https://www.genie.co.kr", defaultPrice: 10900),
        Service(name: "바이브", aliases: ["vibe"], category: .ott, color: 0xFF2A5B, mark: "V", cancelURL: "https://vibe.naver.com", defaultPrice: 8400),
        Service(name: "Perplexity", aliases: ["퍼플렉시티"], category: .ai, color: 0x1F8A8A, mark: "P", cancelURL: "https://www.perplexity.ai/settings/account", defaultPrice: 28000),
        Service(name: "Midjourney", aliases: ["미드저니"], category: .ai, color: 0x111111, mark: "M", cancelURL: "https://www.midjourney.com/account", defaultPrice: 14000),
        Service(name: "Cursor", aliases: ["커서"], category: .ai, color: 0x111111, mark: "C", cancelURL: "https://cursor.com/settings", defaultPrice: 28000),
        Service(name: "GitHub Copilot", aliases: ["copilot", "코파일럿", "깃허브"], category: .ai, color: 0x24292F, mark: "Gh", cancelURL: "https://github.com/settings/billing", defaultPrice: 14000),
        Service(name: "Notion", aliases: ["노션"], category: .etc, color: 0x111111, mark: "N", cancelURL: "https://www.notion.so/my-account", defaultPrice: 14000),
        Service(name: "Dropbox", aliases: ["드롭박스"], category: .etc, color: 0x0061FF, mark: "D", cancelURL: "https://www.dropbox.com/account/plan", defaultPrice: 14000),
        Service(name: "Google One", aliases: ["구글 원", "구글원", "구글 드라이브"], category: .etc, color: 0x4285F4, mark: "G1", cancelURL: "https://one.google.com/settings", defaultPrice: 2400),
        Service(name: "토스 프라임", aliases: ["토스프라임"], category: .membership, color: 0x3182F6, mark: "T", cancelURL: "https://toss.im", defaultPrice: 4900),
        Service(name: "배민클럽", aliases: ["배달의민족", "배민", "baemin"], category: .membership, color: 0x2AC1BC, mark: "배", cancelURL: "https://www.baemin.com", defaultPrice: 3990),
        Service(name: "컬리멤버스", aliases: ["마켓컬리", "컬리", "kurly"], category: .membership, color: 0x5F0080, mark: "K", cancelURL: "https://www.kurly.com", defaultPrice: 1900),
        Service(name: "카카오 이모티콘 플러스", aliases: ["카카오이모티콘", "이모티콘플러스"], category: .membership, color: 0xFEE500, mark: "K", cancelURL: "https://emoticon.kakao.com", defaultPrice: 4900),
        Service(name: "SKT", aliases: ["에스케이티", "sk텔레콤"], category: .life, color: 0xE60012, mark: "SK", cancelURL: "", defaultPrice: 55000),
        Service(name: "KT", aliases: ["케이티"], category: .life, color: 0x0AA0FA, mark: "KT", cancelURL: "", defaultPrice: 55000),
        Service(name: "LG U+", aliases: ["엘지유플러스", "lgu", "유플러스"], category: .life, color: 0xEB0A8C, mark: "U+", cancelURL: "", defaultPrice: 55000),
        Service(name: "스팀", aliases: ["steam"], category: .game, color: 0x171A21, mark: "S", cancelURL: "https://store.steampowered.com/account", defaultPrice: 10000),
        Service(name: "블리자드", aliases: ["blizzard", "디아블로", "wow"], category: .game, color: 0x00AEFF, mark: "B", cancelURL: "https://account.blizzard.com", defaultPrice: 15000),
        Service(name: "눔", aliases: ["noom", "다이어트"], category: .health, color: 0xFF7A00, mark: "n", cancelURL: "", defaultPrice: 30000),
        Service(name: "필라테스", aliases: ["요가", "크로스핏"], category: .health, color: 0xEF4444, mark: "P", cancelURL: "", defaultPrice: 150000),
        Service(name: "Prime Video", aliases: ["아마존 프라임", "prime video", "amazon prime"], category: .ott, color: 0x00A8E1, mark: "P", cancelURL: "", defaultPrice: 6900),
        Service(name: "HBO Max", aliases: ["hbo", "hbomax"], category: .ott, color: 0x5822B4, mark: "M", cancelURL: "", defaultPrice: 13900),
        Service(name: "Paramount+", aliases: ["파라마운트"], category: .ott, color: 0x0064FF, mark: "P+", cancelURL: "", defaultPrice: 9900),
        Service(name: "Crunchyroll", aliases: ["크런치롤"], category: .ott, color: 0xF47521, mark: "C", cancelURL: "", defaultPrice: 9900),
        Service(name: "CGV", aliases: ["씨지브이"], category: .ott, color: 0xE71A0F, mark: "CG", cancelURL: "", defaultPrice: 14000),
        Service(name: "메가박스", aliases: ["megabox"], category: .ott, color: 0x351F65, mark: "M", cancelURL: "", defaultPrice: 14000),
        Service(name: "롯데시네마", aliases: ["lotte cinema"], category: .ott, color: 0xED1D24, mark: "L", cancelURL: "", defaultPrice: 14000),
        Service(name: "U+모바일tv", aliases: ["유플러스tv", "uplus tv"], category: .ott, color: 0xEB0A8C, mark: "tv", cancelURL: "", defaultPrice: 9900),
        Service(name: "SoundCloud", aliases: ["사운드클라우드"], category: .ott, color: 0xFF5500, mark: "S", cancelURL: "", defaultPrice: 6900),
        Service(name: "치지직", aliases: ["chzzk"], category: .ott, color: 0x00FFA3, mark: "치", cancelURL: "", defaultPrice: 4900),
        Service(name: "Apple One", aliases: ["애플원"], category: .membership, color: 0x000000, mark: "1", cancelURL: "", defaultPrice: 19500),
        Service(name: "Apple Arcade", aliases: ["애플 아케이드"], category: .game, color: 0xFF2D55, mark: "A", cancelURL: "", defaultPrice: 6500),
        Service(name: "Apple Fitness+", aliases: ["애플 피트니스"], category: .health, color: 0xFF375F, mark: "F", cancelURL: "", defaultPrice: 11000),
        Service(name: "Grok", aliases: ["그록", "xai"], category: .ai, color: 0x111111, mark: "G", cancelURL: "", defaultPrice: 40000),
        Service(name: "Microsoft Copilot", aliases: ["코파일럿", "ms copilot"], category: .ai, color: 0x0F6CBD, mark: "C", cancelURL: "", defaultPrice: 30000),
        Service(name: "Canva", aliases: ["캔바"], category: .etc, color: 0x00C4CC, mark: "C", cancelURL: "", defaultPrice: 16000),
        Service(name: "Figma", aliases: ["피그마"], category: .etc, color: 0xF24E1E, mark: "F", cancelURL: "", defaultPrice: 20000),
        Service(name: "Slack", aliases: ["슬랙"], category: .etc, color: 0x4A154B, mark: "S", cancelURL: "", defaultPrice: 10000),
        Service(name: "Zoom", aliases: ["줌"], category: .etc, color: 0x0B5CFF, mark: "Z", cancelURL: "", defaultPrice: 20000),
        Service(name: "Grammarly", aliases: ["그래머리"], category: .etc, color: 0x15C39A, mark: "G", cancelURL: "", defaultPrice: 15000),
        Service(name: "Evernote", aliases: ["에버노트"], category: .etc, color: 0x00A82D, mark: "E", cancelURL: "", defaultPrice: 10000),
        Service(name: "1Password", aliases: ["원패스워드"], category: .etc, color: 0x0572EC, mark: "1P", cancelURL: "", defaultPrice: 4000),
        Service(name: "NordVPN", aliases: ["노드vpn"], category: .etc, color: 0x4687FF, mark: "N", cancelURL: "", defaultPrice: 12000),
        Service(name: "OneDrive", aliases: ["원드라이브"], category: .etc, color: 0x0078D4, mark: "O", cancelURL: "", defaultPrice: 2400),
        Service(name: "Roblox", aliases: ["로블록스"], category: .game, color: 0xE2231A, mark: "R", cancelURL: "", defaultPrice: 10000),
        Service(name: "넥슨", aliases: ["nexon", "메이플"], category: .game, color: 0x1C1C1C, mark: "N", cancelURL: "", defaultPrice: 10000),
        Service(name: "구글 플레이 패스", aliases: ["play pass", "google play"], category: .game, color: 0x34A853, mark: "G", cancelURL: "", defaultPrice: 6500),
        Service(name: "EA Play", aliases: ["이에이"], category: .game, color: 0xFF4747, mark: "EA", cancelURL: "", defaultPrice: 6000),
        Service(name: "GeForce NOW", aliases: ["지포스나우"], category: .game, color: 0x76B900, mark: "G", cancelURL: "", defaultPrice: 13000),
        Service(name: "스타벅스", aliases: ["starbucks", "스벅"], category: .membership, color: 0x00704A, mark: "S", cancelURL: "", defaultPrice: 5000),
        Service(name: "올리브영", aliases: ["oliveyoung"], category: .membership, color: 0x9ACD32, mark: "O", cancelURL: "", defaultPrice: 3900),
        Service(name: "무신사", aliases: ["musinsa"], category: .membership, color: 0x111111, mark: "M", cancelURL: "", defaultPrice: 3900),
        Service(name: "에이블리", aliases: ["ably"], category: .membership, color: 0xFF4E8B, mark: "A", cancelURL: "", defaultPrice: 3900),
        Service(name: "지그재그", aliases: ["zigzag"], category: .membership, color: 0xFF2D87, mark: "Z", cancelURL: "", defaultPrice: 3900),
        Service(name: "요기요", aliases: ["yogiyo", "요기패스"], category: .membership, color: 0xFA0050, mark: "Y", cancelURL: "", defaultPrice: 2900),
        Service(name: "쿠팡이츠", aliases: ["coupang eats"], category: .membership, color: 0x00B7FF, mark: "E", cancelURL: "", defaultPrice: 0),
        Service(name: "11번가", aliases: ["우주패스", "11st"], category: .membership, color: 0xFF0038, mark: "11", cancelURL: "", defaultPrice: 3900),
        Service(name: "G마켓", aliases: ["지마켓", "스마일클럽"], category: .membership, color: 0x00B050, mark: "G", cancelURL: "", defaultPrice: 3000),
        Service(name: "SSG", aliases: ["쓱닷컴", "신세계"], category: .membership, color: 0xFFC800, mark: "S", cancelURL: "", defaultPrice: 3000),
        Service(name: "롯데ON", aliases: ["lotte on"], category: .membership, color: 0xED1B24, mark: "L", cancelURL: "", defaultPrice: 3900),
        Service(name: "카카오페이지", aliases: ["kakaopage"], category: .life, color: 0xFFDD00, mark: "P", cancelURL: "", defaultPrice: 5900),
        Service(name: "네이버 시리즈", aliases: ["시리즈온", "네이버웹툰", "웹툰"], category: .life, color: 0x03C75A, mark: "S", cancelURL: "", defaultPrice: 5900),
        Service(name: "리디", aliases: ["ridi", "리디북스"], category: .life, color: 0x1F8CE6, mark: "R", cancelURL: "", defaultPrice: 4900),
        Service(name: "윌라", aliases: ["welaaa"], category: .life, color: 0xFF5A00, mark: "W", cancelURL: "", defaultPrice: 12900),
        Service(name: "예스24 크레마클럽", aliases: ["yes24", "크레마"], category: .life, color: 0x0B5FFF, mark: "Y", cancelURL: "", defaultPrice: 9900),
        Service(name: "클래스101", aliases: ["class101"], category: .life, color: 0xFF5700, mark: "C", cancelURL: "", defaultPrice: 19900),
        Service(name: "인프런", aliases: ["inflearn"], category: .life, color: 0x1DC078, mark: "I", cancelURL: "", defaultPrice: 20000),
        Service(name: "Duolingo", aliases: ["듀오링고"], category: .life, color: 0x58CC02, mark: "D", cancelURL: "", defaultPrice: 13000),
        Service(name: "말해보카", aliases: ["mallae"], category: .life, color: 0x2D6BFF, mark: "말", cancelURL: "", defaultPrice: 9900),
        Service(name: "스픽", aliases: ["speak"], category: .life, color: 0x111111, mark: "S", cancelURL: "", defaultPrice: 15000),
        Service(name: "야나두", aliases: ["yanadoo"], category: .life, color: 0xFF5B00, mark: "Y", cancelURL: "", defaultPrice: 30000),
        Service(name: "SK 브로드밴드", aliases: ["sk인터넷", "skb", "브로드밴드"], category: .life, color: 0xE60012, mark: "SK", cancelURL: "", defaultPrice: 30000),
        Service(name: "KT 인터넷", aliases: ["kt tv", "올레"], category: .life, color: 0x0AA0FA, mark: "KT", cancelURL: "", defaultPrice: 30000),
        Service(name: "LG U+ 인터넷", aliases: ["유플러스 인터넷", "u+tv"], category: .life, color: 0xEB0A8C, mark: "U+", cancelURL: "", defaultPrice: 30000),
        Service(name: "코웨이", aliases: ["coway"], category: .life, color: 0x0A8FDC, mark: "C", cancelURL: "", defaultPrice: 30000),
        Service(name: "쿠쿠 렌탈", aliases: ["cuckoo", "쿠쿠"], category: .life, color: 0xE60012, mark: "Q", cancelURL: "", defaultPrice: 30000),
        Service(name: "SK매직", aliases: ["skmagic"], category: .life, color: 0xEA002C, mark: "S", cancelURL: "", defaultPrice: 30000),
        Service(name: "ADT캡스", aliases: ["adt", "캡스"], category: .life, color: 0xE60012, mark: "A", cancelURL: "", defaultPrice: 40000),
        Service(name: "Calm", aliases: ["캄"], category: .health, color: 0x4A90E2, mark: "C", cancelURL: "", defaultPrice: 8000),
        Service(name: "Headspace", aliases: ["헤드스페이스"], category: .health, color: 0xFF8A00, mark: "H", cancelURL: "", defaultPrice: 12000),
        Service(name: "마보", aliases: ["mabo", "명상"], category: .health, color: 0x3DD6C4, mark: "마", cancelURL: "", defaultPrice: 9900),
        Service(name: "Fitbit Premium", aliases: ["핏빗"], category: .health, color: 0x00B0B9, mark: "F", cancelURL: "", defaultPrice: 10000),
        Service(name: "삼성화재", aliases: ["samsung fire", "삼성 화재"], category: .insurance, color: 0x0B3D91, mark: "삼", cancelURL: "", defaultPrice: 50000),
        Service(name: "현대해상", aliases: ["hyundai marine"], category: .insurance, color: 0x007A3D, mark: "현", cancelURL: "", defaultPrice: 50000),
        Service(name: "DB손해보험", aliases: ["db손보", "동부화재"], category: .insurance, color: 0x0A7B3C, mark: "DB", cancelURL: "", defaultPrice: 50000),
        Service(name: "KB손해보험", aliases: ["kb손보"], category: .insurance, color: 0xF5A100, mark: "KB", cancelURL: "", defaultPrice: 50000),
        Service(name: "메리츠화재", aliases: ["meritz"], category: .insurance, color: 0xE4002B, mark: "M", cancelURL: "", defaultPrice: 50000),
        Service(name: "한화생명", aliases: ["hanwha life"], category: .insurance, color: 0xF37321, mark: "한", cancelURL: "", defaultPrice: 50000),
        Service(name: "삼성생명", aliases: ["samsung life"], category: .insurance, color: 0x0B3D91, mark: "삼", cancelURL: "", defaultPrice: 50000),
        Service(name: "교보생명", aliases: ["kyobo life"], category: .insurance, color: 0x0072CE, mark: "교", cancelURL: "", defaultPrice: 50000),
        Service(name: "헬스장", aliases: ["피트니스", "pt", "필라테스"], category: .health, color: 0xEF4444, mark: "H", cancelURL: "", defaultPrice: 50000),
        Service(name: "보험", aliases: ["실손", "화재", "생명", "손해", "자동차"], category: .insurance, color: 0x06B6D4, mark: "보", cancelURL: "", defaultPrice: 50000),
        Service(name: "정수기 렌탈", aliases: ["렌탈", "코웨이", "청호"], category: .life, color: 0xF59E0B, mark: "렌", cancelURL: "", defaultPrice: 30000),
    ]

    /// 소문자, 공백·기호 제거 (예: "Chat GPT" == "chatgpt")
    static func norm(_ t: String) -> String {
        String(t.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
    static func edit(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }; if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count { cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) }
            prev = cur
        }
        return prev[b.count]
    }
    static func keys(_ s: Service) -> [String] { ([s.name] + s.aliases).map(norm).filter { !$0.isEmpty } }

    static func find(_ text: String) -> Service? {
        let t = norm(text)
        guard t.count >= 2 else { return nil }
        // 1) 정확히 일치  2) 입력에 서비스명이 들어있음(결제 문자 등)  3) 서비스명에 입력이 들어있음
        if let s = all.first(where: { keys($0).contains(t) }) { return s }
        if let s = all.first(where: { sv in keys(sv).contains { ($0.count >= 3 || !$0.allSatisfy { $0.isASCII }) && t.contains($0) } }) { return s }
        if t.count >= 3, let s = all.first(where: { sv in keys(sv).contains { $0.hasPrefix(t) } }) { return s }
        // 4) 오타 허용 (한 글자 차이)
        if t.count >= 4, t.count <= 20 {
            let tc = Array(t)
            if let s = all.first(where: { sv in keys(sv).contains { $0.count >= 4 && abs($0.count - t.count) <= 1 && edit(tc, Array($0)) <= 1 } }) { return s }
        }
        return nil
    }
    static func search(_ q: String) -> [Service] {
        let t = norm(q)
        if t.isEmpty { return Array(all.prefix(10)) }
        return all.filter { s in keys(s).contains { $0.contains(t) } }
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
                Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .heavy, design: .rounded)).foregroundStyle(category.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
