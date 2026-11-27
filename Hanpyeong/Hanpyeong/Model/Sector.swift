import SwiftUI

/// 업종을 묶는 분야
enum Sector: String, CaseIterable, Identifiable {
    case food, retail, life, edu, tech, media, industry, leisure, finance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "외식"
        case .retail: return "유통"
        case .life: return "생활"
        case .edu: return "교육"
        case .tech: return "IT"
        case .media: return "엔터"
        case .industry: return "제조"
        case .leisure: return "레저·관광"
        case .finance: return "금융"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .retail: return "cart.fill"
        case .life: return "house.fill"
        case .edu: return "graduationcap.fill"
        case .tech: return "laptopcomputer"
        case .media: return "sparkles.tv.fill"
        case .industry: return "building.2.fill"
        case .leisure: return "airplane"
        case .finance: return "wonsign.circle.fill"
        }
    }
}

extension BusinessKind {
    var sector: Sector {
        switch self {
        case .bungeoppang, .snackBar, .cafe, .chicken, .bbq, .franchiseHQ: return .food
        case .cornerShop, .convenience, .supermarket, .departmentStore, .logistics: return .retail
        case .flowerShop, .laundromat, .hairSalon, .carRepair, .gym: return .life
        case .academy: return .edu
        case .appStudio, .gameCompany, .pcBang: return .tech
        case .webtoon, .entertainment: return .media
        case .foodFactory, .pharma, .chipFab: return .industry
        case .hotel, .themePark, .airline: return .leisure
        case .securities, .holdings: return .finance
        }
    }

    /// 흥행형 업종의 오늘 운: 0.6 ~ 1.8 (날짜와 업종으로 정해진다)
    func hitFactor(day: Int) -> Double {
        guard info.trait == .hit else { return 1 }
        let k = UInt64(BusinessKind.allCases.firstIndex(of: self) ?? 0)
        var x = UInt64(max(0, day)) &* 0x9E37_79B9_7F4A_7C15 &+ k &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 31
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 29
        return 0.6 + 1.2 * Double(x % 10_000) / 10_000
    }
}
