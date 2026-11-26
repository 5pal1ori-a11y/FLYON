#if DEBUG
import Foundation

/// 디버그 빌드 전용: 화면 캡처를 위해 예시 데이터를 채운다. (실행 인자 -demoData YES)
/// 릴리스(TestFlight·앱스토어) 빌드에는 포함되지 않는다.
@MainActor
enum DebugDemo {
    static func seedIfRequested(wallet: Wallet, market: MarketStore) async {
        guard UserDefaults.standard.bool(forKey: "demoData") else { return }
        let a = wallet.account(.upbit)
        guard a.holdings.isEmpty, a.positions.isEmpty, wallet.state.tradex >= 4 else { return }

        // 시세가 들어올 때까지 최대 30초 대기
        for _ in 0..<60 where market.tickers.isEmpty {
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard !market.tickers.isEmpty else { return }

        try? wallet.charge(tradex: 3, to: .upbit, futures: false)
        try? wallet.charge(tradex: 1, to: .upbit, futures: true)

        let buys: [(String, Double)] = [("KRW-BTC", 4_000_000), ("KRW-ETH", 2_500_000), ("KRW-XRP", 1_500_000), ("KRW-SOL", 1_000_000)]
        for (code, krw) in buys {
            if let m = market.market(code), let p = market.tickers[code]?.tradePrice {
                try? wallet.buy(market: m, krwAmount: krw, price: p, on: .upbit)
            }
        }
        if let m = market.market("KRW-BTC"), let p = market.tickers["KRW-BTC"]?.tradePrice {
            try? wallet.openPosition(market: m, side: .long, leverage: 5, margin: 1_500_000, price: p * 0.995, on: .upbit)
        }
        if let m = market.market("KRW-ETH"), let p = market.tickers["KRW-ETH"]?.tradePrice {
            try? wallet.openPosition(market: m, side: .short, leverage: 3, margin: 1_000_000, price: p * 1.004, on: .upbit)
        }
        for code in ["KRW-BTC", "KRW-ETH", "KRW-XRP"] { wallet.recordEvent("chart:\(code)") }
    }
}
#endif
