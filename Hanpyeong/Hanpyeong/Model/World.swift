import Foundation

// 게임 속 달력: 하루 = 달력 3일, 한 달 = 10일, 일 년 = 120일. 1일차는 1년차 3월 1일(봄).

enum Season: String, Codable, CaseIterable {
    case spring, summer, autumn, winter

    var title: String {
        switch self {
        case .spring: return "봄"
        case .summer: return "여름"
        case .autumn: return "가을"
        case .winter: return "겨울"
        }
    }

    var symbol: String {
        switch self {
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .autumn: return "wind"
        case .winter: return "snowflake"
        }
    }

    /// 이 계절에 나올 수 있는 날씨와 확률
    var weatherTable: [(Weather, Double)] {
        switch self {
        case .spring: return [(.sunny, 0.5), (.cloudy, 0.3), (.rain, 0.2)]
        case .summer: return [(.sunny, 0.35), (.heat, 0.3), (.rain, 0.3), (.cloudy, 0.05)]
        case .autumn: return [(.sunny, 0.55), (.cloudy, 0.3), (.rain, 0.15)]
        case .winter: return [(.sunny, 0.3), (.cloudy, 0.25), (.snow, 0.25), (.cold, 0.2)]
        }
    }
}

enum Weather: String, Codable, CaseIterable {
    case sunny, cloudy, rain, snow, heat, cold

    var title: String {
        switch self {
        case .sunny:  return "맑음"
        case .cloudy: return "흐림"
        case .rain:   return "비"
        case .snow:   return "눈"
        case .heat:   return "폭염"
        case .cold:   return "한파"
        }
    }

    var symbol: String {
        switch self {
        case .sunny:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain:   return "cloud.rain.fill"
        case .snow:   return "cloud.snow.fill"
        case .heat:   return "thermometer.sun.fill"
        case .cold:   return "thermometer.snowflake"
        }
    }

    var forecast: String {
        switch self {
        case .sunny:  return "나들이하기 좋은 날. 관광지가 붐빈다."
        case .cloudy: return "그럭저럭 무난한 하루."
        case .rain:   return "우산 쓴 손님은 적다. 빨래방·치킨·PC방은 대목."
        case .snow:   return "길이 미끄럽다. 붕어빵과 배달이 잘 나간다."
        case .heat:   return "아이스 음료와 편의점이 불티난다."
        case .cold:   return "뜨끈한 붕어빵과 국물이 당기는 날."
        }
    }

    static func roll(for season: Season) -> Weather {
        let table = season.weatherTable
        var r = Double.random(in: 0..<table.reduce(0) { $0 + $1.1 })
        for (w, p) in table {
            if r < p { return w }
            r -= p
        }
        return table[0].0
    }
}

enum GameCalendar {
    static func monthIndex(_ day: Int) -> Int { (max(1, day) - 1) / 10 }

    static func month(_ day: Int) -> Int { (2 + monthIndex(day)) % 12 + 1 }

    static func year(_ day: Int) -> Int { (2 + monthIndex(day)) / 12 + 1 }

    static func dayOfMonth(_ day: Int) -> Int { ((max(1, day) - 1) % 10) * 3 + 1 }

    static func season(_ day: Int) -> Season {
        switch month(day) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    static func text(_ day: Int) -> String {
        "\(year(day))년차 \(month(day))월 \(dayOfMonth(day))일"
    }

    static func shortText(_ day: Int) -> String {
        "\(month(day))월 \(dayOfMonth(day))일"
    }
}
