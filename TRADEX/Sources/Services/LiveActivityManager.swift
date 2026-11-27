import Foundation
import ActivityKit

/// 선물 포지션을 잠금화면·다이내믹 아일랜드에 띄우고 갱신한다.
/// 앱이 켜져 있는 동안만 갱신되고, 앱이 꺼지면 마지막 값이 남는다(15분 뒤 '오래됨' 표시).
@MainActor
enum LiveActivityManager {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
    }

    static func start(_ p: FuturesPosition, price: Double) {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard !Activity<PositionActivityAttributes>.activities.contains(where: { $0.attributes.positionID == p.id.uuidString }) else { return }
        let attrs = PositionActivityAttributes(positionID: p.id.uuidString, market: p.market, symbol: p.symbol,
                                               koreanName: p.koreanName, isLong: p.side == .long, leverage: p.leverage,
                                               entryPrice: p.entryPrice, liquidationPrice: p.liquidationPrice)
        let state = PositionActivityAttributes.ContentState(price: price, pnl: p.pnl(at: price), roe: p.roe(at: price))
        _ = try? Activity.request(attributes: attrs,
                                  content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)))
    }

    /// 열린 포지션은 새 가격으로 갱신, 닫히거나 청산된 포지션은 종료
    static func sync(positions: [FuturesPosition], prices: [String: Ticker]) async {
        for activity in Activity<PositionActivityAttributes>.activities {
            guard let p = positions.first(where: { $0.id.uuidString == activity.attributes.positionID }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            guard let price = prices[p.market]?.tradePrice else { continue }
            let state = PositionActivityAttributes.ContentState(price: price, pnl: p.pnl(at: price), roe: p.roe(at: price))
            guard state != activity.content.state else { continue }
            await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)))
        }
    }

    static func endAll() async {
        for activity in Activity<PositionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
