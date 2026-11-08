import SwiftUI

/// 가격 알림 만들기: 원하는 가격 이하로 내려가면 푸시 알림
struct CreateAlertView: View {
    let search: RouteSearch
    let selectedDate: Date?
    let month: Date
    let currentPrice: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(PushManager.self) private var push

    @State private var wholeMonth = false
    @State private var target: Int = 0
    @State private var saving = false
    @State private var done = false
    @State private var message: String?

    private let steps = [5, 10, 20]

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("\(search.origin.city) → \(search.destination.city)")
                        .font(.app(22, .bold))
                    Text("\(search.cabin.title) · \(search.airlines.isEmpty ? "전체 항공사" : search.airlines.map(\.name).sorted().joined(separator: ", "))")
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 8)

                if let selectedDate {
                    Picker("기간", selection: $wholeMonth) {
                        Text(selectedDate.dayTitle).tag(false)
                        Text("\(month.monthShort) 전체").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 8) {
                    Text("이 가격 이하가 되면 알려 드려요")
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        stepButton("minus", -5_000)
                        Text(target > 0 ? target.won : "––")
                            .font(.app(34, .heavy))
                            .contentTransition(.numericText(value: Double(target)))
                            .animation(.snappy, value: target)
                            .frame(minWidth: 170)
                        stepButton("plus", 5_000)
                    }
                    if let currentPrice {
                        Text("지금 최저가 \(currentPrice.won)")
                            .font(.app(13, .medium))
                            .foregroundStyle(.secondary)
                    }
                    if currentPrice != nil {
                        HStack(spacing: 8) {
                            ForEach(steps, id: \.self) { pct in
                                Button("-\(pct)%") { setTarget(percent: pct) }
                                    .font(.app(14, .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.accentSoft, in: Capsule())
                                    .foregroundStyle(Theme.accent)
                                    .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .card()

                if let message {
                    Text(message)
                        .font(.app(13))
                        .foregroundStyle(Theme.expensive)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Spacer()

                Button { Task { await save() } } label: {
                    ZStack {
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .transition(.scale.combined(with: .opacity))
                        } else if saving {
                            ProgressView().tint(.white)
                        } else {
                            Text("알림 받기").font(.app(17, .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(done ? Theme.cheap : Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .disabled(saving || done || target <= 0)
                .sensoryFeedback(.success, trigger: done)
            }
            .padding(20)
            .background(Theme.screenBackground)
            .navigationTitle("가격 알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onAppear {
                wholeMonth = selectedDate == nil
                if target == 0, let currentPrice { setTarget(percent: 10, from: currentPrice) }
                if target == 0 { target = 100_000 }
            }
        }
        .presentationDetents([.large])
    }

    private func stepButton(_ symbol: String, _ delta: Int) -> some View {
        Button {
            target = max(1_000, target + delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemFill), in: Circle())
                .foregroundStyle(.primary)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: target)
    }

    private func setTarget(percent: Int, from price: Int? = nil) {
        guard let base = price ?? currentPrice else { return }
        target = max(1_000, Int(Double(base) * (1 - Double(percent) / 100) / 1_000) * 1_000)
    }

    private func save() async {
        guard let client = AppConfig.makeAlertsClient() else {
            withAnimation { message = "서버가 연결된 앱에서만 알림을 만들 수 있어요" }
            return
        }
        saving = true
        defer { saving = false }

        guard let token = await push.requestAndRegister() else {
            withAnimation { message = "알림 권한이 필요해요. 설정 앱에서 FLYON 알림을 켜 주세요." }
            return
        }

        let day = ServerPriceProvider.dayParser
        let useDate = !wholeMonth && selectedDate != nil
        let alert = NewAlert(
            deviceToken: token,
            origin: search.origin.code,
            destination: search.destination.code,
            departDate: useDate ? selectedDate.map { day.string(from: $0) } : nil,
            departMonth: useDate ? nil : day.string(from: month),
            airlines: search.airlines.isEmpty ? nil : search.airlines.map(\.code).sorted(),
            cabin: search.cabin.rawValue,
            targetPrice: target,
            baselinePrice: currentPrice
        )
        do {
            try await client.create(alert)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { done = true }
            appState.alertsVersion += 1
            try? await Task.sleep(for: .seconds(0.9))
            dismiss()
        } catch PriceError.http(429) {
            withAnimation { message = "알림은 최대 20개까지 만들 수 있어요" }
        } catch {
            withAnimation { message = "알림을 만들지 못했어요. 잠시 후 다시 시도해 주세요." }
        }
    }
}
