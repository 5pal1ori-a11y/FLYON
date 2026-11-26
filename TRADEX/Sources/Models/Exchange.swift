import SwiftUI

/// 시세를 가져오는 거래소. 두 거래소 모두 같은 형식의 공개 시세 API(v1)를 제공한다.
/// ⚠️ 출시 전 각 거래소 Open API 이용약관에서 제3자 앱 시세 표시 허용 범위를 확인할 것.
/// 거래소 로고는 상표이므로 쓰지 않고 이름 글자 배지로 표시한다.
enum ExchangeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case upbit, bithumb

    var id: String { rawValue }
    var name: String { self == .upbit ? "업비트" : "빗썸" }
    var initial: String { self == .upbit ? "U" : "B" }
    var tint: Color { self == .upbit ? Color(red: 0.05, green: 0.24, blue: 0.62) : Color(red: 0.95, green: 0.45, blue: 0.13) }

    var restBase: URL {
        URL(string: self == .upbit ? "https://api.upbit.com/v1/" : "https://api.bithumb.com/v1/")!
    }
    var socketURL: URL {
        URL(string: self == .upbit ? "wss://api.upbit.com/websocket/v1" : "wss://ws-api.bithumb.com/websocket/v1")!
    }
}

/// 거래소 이름 배지
struct ExchangeBadge: View {
    let exchange: ExchangeID
    var size: CGFloat = 22
    var body: some View {
        Text(exchange.initial)
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.primary, lineWidth: 1.2))
            .accessibilityHidden(true)
    }
}

/// 거래소 선택 메뉴 (예: "업비트 ⌃")
struct ExchangePicker: View {
    @Binding var selection: ExchangeID
    var body: some View {
        Menu {
            Picker("거래소", selection: $selection) {
                ForEach(ExchangeID.allCases) { Text($0.name).tag($0) }
            }
        } label: {
            HStack(spacing: 6) {
                ExchangeBadge(exchange: selection, size: 18)
                Text(selection.name).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.card, in: Capsule())
        }
        .accessibilityLabel("거래소: \(selection.name)")
    }
}
