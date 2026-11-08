import SafariServices
import SwiftUI

/// 실시간 가격 확인: 가격 비교 사이트(Aviasales)의 해당 노선·날짜 검색 결과를 앱 안 브라우저로 연다.
/// 저장된 가격이 아니라 열 때마다 새로 검색한 가격이 보인다.
enum LivePriceLink {
    private static let ddmm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "ddMM"
        return f
    }()

    /// 예: https://www.aviasales.com/search/GMP0512CJU1?currency=krw
    static func url(origin: Airport, destination: Airport, date: Date) -> URL? {
        URL(string: "https://www.aviasales.com/search/\(origin.code)\(ddmm.string(from: date))\(destination.code)1?currency=krw")
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Theme.accent)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
