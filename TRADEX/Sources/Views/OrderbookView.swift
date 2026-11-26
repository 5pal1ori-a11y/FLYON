import SwiftUI

/// 실시간 호가 (1초마다 갱신) — 위쪽 파랑: 매도 호가, 아래쪽 빨강: 매수 호가
struct OrderbookView: View {
    let market: Market
    let prevClose: Double
    var levels = 12

    @State private var book: Orderbook?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            if let book {
                let units = Array(book.units.prefix(levels))
                let maxSize = units.flatMap { [$0.askSize, $0.bidSize] }.max() ?? 1
                ForEach(units.reversed(), id: \.self) { u in
                    row(price: u.askPrice, size: u.askSize, maxSize: maxSize, isAsk: true)
                }
                ForEach(units, id: \.self) { u in
                    row(price: u.bidPrice, size: u.bidSize, maxSize: maxSize, isAsk: false)
                }
            } else if failed {
                Text("호가를 불러오지 못했어요").font(.footnote).foregroundStyle(.secondary).padding(30)
            } else {
                ProgressView().padding(30)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: market.market) {
            while !Task.isCancelled {
                if let b = try? await UpbitAPI.orderbook(market: market.market) {
                    book = b; failed = false
                } else if book == nil {
                    failed = true
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func row(price: Double, size: Double, maxSize: Double, isAsk: Bool) -> some View {
        let rate = prevClose > 0 ? price / prevClose - 1 : 0
        let tint = isAsk ? Theme.fall : Theme.rise
        return HStack(spacing: 0) {
            // 매도 잔량(왼쪽)
            sizeCell(isAsk ? size : nil, maxSize: maxSize, tint: tint, alignment: .trailing)
            // 가격
            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.price(price)).font(.footnote.weight(.semibold))
                Text(Fmt.rate(rate)).font(.caption2)
            }
            .foregroundStyle(Theme.color(for: rate))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.08))
            // 매수 잔량(오른쪽)
            sizeCell(isAsk ? nil : size, maxSize: maxSize, tint: tint, alignment: .leading)
        }
        .frame(height: 38)
    }

    private func sizeCell(_ size: Double?, maxSize: Double, tint: Color, alignment: Alignment) -> some View {
        GeometryReader { geo in
            ZStack(alignment: alignment) {
                if let size {
                    Rectangle().fill(tint.opacity(0.18))
                        .frame(width: geo.size.width * min(1, size / maxSize))
                    Text(Fmt.qty((size * 1000).rounded() / 1000))
                        .font(.caption2).monospacedDigit()
                        .padding(.horizontal, 6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
        }
        .frame(maxWidth: .infinity)
    }
}
