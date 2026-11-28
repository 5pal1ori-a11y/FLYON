import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// 탑승 안내 중 잠금화면과 다이내믹 아일랜드에 보여 줄 내용. 앱과 위젯 확장이 함께 쓴다.
struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "출발역", "이번 역", "도착"
        var label: String
        var station: String
        var lineShort: String
        var colorHex: String
        /// 다음에 내리거나 갈아탈 역까지 남은 정거장 수
        var remaining: Int
        var target: String
        /// "환승" 또는 "도착"
        var action: String
    }

    var destination: String
}
#endif
