import SwiftUI

/// 알림 탭: 내가 만든 가격 알림 목록
struct AlertsView: View {
    @Environment(AppState.self) private var appState
    @Environment(PushManager.self) private var push

    @State private var alerts: [PriceAlert] = []
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                if !push.isAuthorized {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.accent)
                                .symbolEffect(.bounce, value: push.isAuthorized)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("알림을 켜 주세요").font(.app(15, .semibold))
                                Text("원하는 가격이 나오면 바로 알려 드려요").font(.app(13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("켜기") { Task { _ = await push.requestAndRegister(); await load() } }
                                .font(.app(14, .semibold))
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if loading && alerts.isEmpty {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonBlock(height: 70, radius: 12).listRowSeparator(.hidden)
                    }
                } else if alerts.isEmpty {
                    ContentUnavailableView {
                        Label(failed ? "불러오지 못했어요" : "가격 알림이 없어요", systemImage: failed ? "wifi.exclamationmark" : "bell.slash")
                    } description: {
                        Text(failed ? "아래로 당겨 다시 시도해 주세요" : "FLY에서 노선을 고른 뒤 종 버튼을 눌러 보세요")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(alerts) { alert in
                            AlertRow(alert: alert)
                                .contentShape(Rectangle())
                                .onTapGesture { open(alert) }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .animation(.snappy, value: alerts)
            .navigationTitle("가격 알림")
            .refreshable { await load() }
            .task(id: appState.alertsVersion) { await load() }
            .task { await push.refreshStatus() }
        }
    }

    private func load() async {
        guard let client = AppConfig.makeAlertsClient(), let token = push.deviceToken else {
            loading = false
            return
        }
        do {
            alerts = try await client.list(token: token)
            failed = false
        } catch {
            failed = true
        }
        loading = false
    }

    private func delete(at offsets: IndexSet) {
        let removed = offsets.map { alerts[$0] }
        alerts.remove(atOffsets: offsets)
        guard let client = AppConfig.makeAlertsClient(), let token = push.deviceToken else { return }
        Task {
            for alert in removed { try? await client.delete(id: alert.id, token: token) }
        }
    }

    private func open(_ alert: PriceAlert) {
        appState.pendingDate = alert.departDate.flatMap { ServerPriceProvider.dayParser.date(from: $0) }
            ?? alert.departMonth.flatMap { ServerPriceProvider.dayParser.date(from: $0) }
        appState.pendingRoute = FavoriteRoute(originCode: alert.origin, destinationCode: alert.destination)
        appState.selectedTab = .fly
    }
}

private struct AlertRow: View {
    let alert: PriceAlert

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: alert.reached ? "bell.and.waves.left.and.right.fill" : "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(alert.reached ? Theme.cheap : Theme.accent)
                .frame(width: 40, height: 40)
                .background((alert.reached ? Theme.cheap : Theme.accent).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("\(city(alert.origin)) → \(city(alert.destination))")
                    .font(.app(16, .semibold))
                Text("\(alert.periodText) · \(alert.cabinValue.title) · \(alert.airlineText)")
                    .font(.app(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text("목표 \(alert.targetPrice.won)")
                    .font(.app(14, .bold))
                if let current = alert.currentPrice {
                    Text("지금 \(current.won)")
                        .font(.app(12, .medium))
                        .foregroundStyle(alert.reached ? Theme.cheap : .secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(alert.active ? 1 : 0.5)
    }

    private func city(_ code: String) -> String { Catalog.airport(code)?.city ?? code }
}
