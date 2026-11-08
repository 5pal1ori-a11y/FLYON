import Charts
import SwiftUI

/// 가격 알림 만들기. 항공권 하나(flight)를 넘기면 그 날짜·그 항공편 가격이 내려갈 때 알린다.
struct CreateAlertView: View {
    let search: RouteSearch
    let selectedDate: Date?
    let month: Date
    let currentPrice: Int?
    var flight: Flight? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(PushManager.self) private var push

    @State private var wholeMonth = false
    @State private var anyDrop = true
    @State private var target: Int = 0
    @State private var saving = false
    @State private var done = false
    @State private var message: String?

    private var effectiveTarget: Int {
        if anyDrop, let currentPrice { return max(1, currentPrice - 1) }
        return target
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                if flight == nil, let selectedDate {
                    Picker("기간", selection: $wholeMonth) {
                        Text(selectedDate.dayTitle).tag(false)
                        Text("\(month.monthShort) 전체").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 14) {
                    if currentPrice != nil {
                        HStack(spacing: 8) {
                            modeChip("내려가면 바로", selected: anyDrop) { anyDrop = true }
                            modeChip("목표 가격", selected: !anyDrop) {
                                anyDrop = false
                                if target == 0 { setTarget(percent: 10) }
                            }
                        }
                    }

                    if anyDrop, let currentPrice {
                        VStack(spacing: 6) {
                            Text(currentPrice.won)
                                .font(.app(34, .heavy))
                            Text("지금 가격보다 조금이라도 내려가면 알려 드려요")
                                .font(.app(13))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity)
                    } else {
                        VStack(spacing: 10) {
                            HStack(spacing: 18) {
                                stepButton("minus", -5_000)
                                Text(target > 0 ? target.won : "––")
                                    .font(.app(32, .heavy))
                                    .contentTransition(.numericText(value: Double(target)))
                                    .animation(.snappy, value: target)
                                    .frame(minWidth: 160)
                                stepButton("plus", 5_000)
                            }
                            Text("이 가격 이하가 되면 알려 드려요")
                                .font(.app(13))
                                .foregroundStyle(.secondary)
                            if currentPrice != nil {
                                HStack(spacing: 8) {
                                    ForEach([5, 10, 20], id: \.self) { pct in
                                        Button("-\(pct)%") { setTarget(percent: pct) }
                                            .font(.app(14, .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.accentSoft, in: Capsule())
                                            .foregroundStyle(Theme.accent)
                                            .buttonStyle(PressableStyle())
                                    }
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.snappy, value: anyDrop)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .card()

                if let message {
                    Text(message)
                        .font(.app(13))
                        .foregroundStyle(Theme.expensive)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button { Task { await save() } } label: {
                    ZStack {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 20, weight: .bold))
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
                .disabled(saving || done || effectiveTarget <= 0)
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
                wholeMonth = selectedDate == nil && flight == nil
                anyDrop = currentPrice != nil
                if currentPrice == nil { target = 100_000 }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(search.origin.city) → \(search.destination.city)")
                .font(.app(22, .bold))
            if let flight {
                HStack(spacing: 8) {
                    AirlineLogo(code: flight.airline.code, size: 26)
                    Text([selectedDate?.dayTitle, flight.airline.name, flight.flightNumber, flight.departureTime]
                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.app(13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("\(search.cabin.title) · \(search.airlines.isEmpty ? "전체 항공사" : search.airlines.map(\.name).sorted().joined(separator: ", "))")
                    .font(.app(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.top, 8)
    }

    private func modeChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(14, .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Theme.accent : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(PressableStyle())
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

    private func setTarget(percent: Int) {
        guard let base = currentPrice else { return }
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
        let useDate = flight != nil || (!wholeMonth && selectedDate != nil)
        let airlines: [String]? = flight.map { [$0.airline.code] }
            ?? (search.airlines.isEmpty ? nil : search.airlines.map(\.code).sorted())
        let flightNumber = flight?.flightNumber.filter { $0.isLetter || $0.isNumber }
        let alert = NewAlert(
            deviceToken: token,
            origin: search.origin.code,
            destination: search.destination.code,
            departDate: useDate ? selectedDate.map { day.string(from: $0) } : nil,
            departMonth: useDate ? nil : day.string(from: month),
            airlines: airlines,
            flightNumber: (flightNumber?.isEmpty ?? true) ? nil : flightNumber,
            cabin: search.cabin.rawValue,
            targetPrice: effectiveTarget,
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

/// 항공권 하나의 상세: 가격 기록 그래프와 알림
struct FlightDetailView: View {
    let search: RouteSearch
    let date: Date
    let flight: Flight

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var history: [PricePoint] = []
    @State private var loading = true
    @State private var showAlert = false
    @State private var reveal: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        AirlineLogo(code: flight.airline.code, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.airline.name + (flight.flightNumber.isEmpty ? "" : " \(flight.flightNumber)"))
                                .font(.app(17, .bold))
                            Text([date.dayTitle, flight.durationText, flight.transfers == 0 ? "직항" : "경유 \(flight.transfers)회"]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.app(13))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let dep = flight.departureTime {
                        HStack {
                            timeBlock(dep, search.origin.code)
                            Spacer()
                            Image(systemName: "airplane").foregroundStyle(Theme.accent)
                            Spacer()
                            timeBlock(flight.arrivalTime?.text ?? "––", search.destination.code)
                        }
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("지금 가격").font(.app(13, .medium)).foregroundStyle(.secondary)
                        Text(flight.price.won).font(.app(34, .heavy))
                        if let change = priceChange {
                            Pill(text: change.text, systemImage: change.symbol, color: change.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("이 항공권 가격 기록").font(.app(16, .bold))
                        if loading {
                            SkeletonBlock(height: 160, radius: 14)
                        } else if history.count >= 2 {
                            chart
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "hourglass").foregroundStyle(Theme.accent).symbolEffect(.pulse)
                                Text("오늘부터 매일 이 항공권 가격을 기록해요")
                                    .font(.app(13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .card()
                }
                .padding(20)
            }
            .background(Theme.screenBackground)
            .safeAreaInset(edge: .bottom) {
                Button { showAlert = true } label: {
                    Label("이 항공권 가격 알림", systemImage: "bell.badge")
                        .font(.app(17, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("항공권")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .sheet(isPresented: $showAlert) {
                CreateAlertView(search: search, selectedDate: date, month: date, currentPrice: flight.price, flight: flight)
            }
            .task { await load() }
        }
    }

    private var priceChange: (text: String, symbol: String, color: Color)? {
        guard history.count >= 2 else { return nil }
        let prev = history[history.count - 2].price
        let diff = flight.price - prev
        if diff < 0 { return ("어제보다 \((-diff).won) 내림", "arrow.down.right", Theme.cheap) }
        if diff > 0 { return ("어제보다 \(diff.won) 오름", "arrow.up.right", Theme.expensive) }
        return ("어제와 같음", "equal", Theme.normal)
    }

    private func timeBlock(_ time: String, _ code: String) -> some View {
        VStack(spacing: 2) {
            Text(time).font(.app(22, .bold))
            Text(code).font(.app(12, .semibold)).foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(history) { p in
                LineMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Theme.accent)
                PointMark(x: .value("날짜", p.date), y: .value("가격", p.price))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(30)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel { if let v = value.as(Int.self) { Text(v.shortWon).font(.app(10)) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month().day()) }
        }
        .frame(height: 170)
        .mask(alignment: .leading) { GeometryReader { g in Rectangle().frame(width: g.size.width * reveal) } }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { reveal = 1 } }
    }

    private func load() async {
        history = (try? await appState.provider.flightHistory(
            origin: search.origin, destination: search.destination, date: date, flight: flight, cabin: search.cabin)) ?? []
        loading = false
    }
}
