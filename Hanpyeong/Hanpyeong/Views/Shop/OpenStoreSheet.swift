import SwiftUI

struct OpenStoreSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var district: DistrictID = .alley

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("어디에 열까요").sectionLabel()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DistrictID.allCases) { d in chip(d) }
                        }
                        .padding(.horizontal, 1)
                    }
                    districtSummary

                    Text("무엇을 열까요").sectionLabel().padding(.top, 8)
                    ForEach(BusinessKind.allCases) { k in row(k) }
                }
                .padding(16)
            }
            .background(Palette.paper)
            .navigationTitle("새 점포 열기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .onAppear {
                if let best = DistrictID.allCases.last(where: { game.isUnlocked($0) && game.freeSlots(in: $0) > 0 }) {
                    district = best
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func chip(_ d: DistrictID) -> some View {
        let unlocked = game.isUnlocked(d)
        let selected = d == district
        return Button {
            if unlocked { withAnimation(.snappy) { district = d } }
        } label: {
            HStack(spacing: 5) {
                if !unlocked { Image(systemName: "lock.fill").font(.system(size: 10)) }
                Text(d.info.name).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? .white : unlocked ? Palette.ink : Palette.inkFaint)
            .background(
                Capsule().fill(selected ? Palette.ink : Palette.card)
            )
            .overlay(Capsule().strokeBorder(selected ? .clear : Palette.line))
        }
        .buttonStyle(.plain)
    }

    private var districtSummary: some View {
        let info = district.info
        let free = game.freeSlots(in: district)
        let idx = game.index(district)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.name).font(.myeongjo(19))
                Spacer()
                Text("자리 \(info.slots - free)/\(info.slots)")
                    .font(.num(12, .bold))
                    .foregroundStyle(free > 0 ? Palette.inkSoft : Palette.sign)
            }
            Text(info.mood).font(.system(size: 12)).foregroundStyle(Palette.inkSoft)
            HStack {
                StatCell(label: "유동인구", value: "×\(String(format: "%.2f", info.traffic))")
                StatCell(label: "임대료", value: game.ownsBuilding(in: district) ? "내 건물" : "×\(String(format: "%.1f", info.rentMult))")
                StatCell(label: "시세지수", value: String(format: "%.1f", idx * 100), tint: trendColor(idx - 1))
            }
        }
        .paperCard(padding: 14)
    }

    private func row(_ k: BusinessKind) -> some View {
        let info = k.info
        let unlocked = game.isUnlocked(k)
        let cost = game.openCost(k, in: district)
        let blocker = game.openBlocker(k, in: district)
        let firstIncome = game.baseIncome(kind: k, level: 1, staff: 0, district: district)
        let rent = game.ownsBuilding(in: district) ? 0 : info.rent * district.info.rentMult

        return HStack(spacing: 12) {
            KindTile(kind: k, size: 46)
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(info.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    if info.trait != .normal { Tag(text: info.trait.title, color: k.color) }
                }
                if unlocked {
                    let deposit = game.newDeposit(k, district)
                    Text(deposit > 0 ? "개업비 \(Won.short(cost)) + 보증금 \(Won.short(deposit))" : "개업비 \(Won.short(cost))")
                        .font(.num(12, .semibold)).foregroundStyle(Palette.ink)
                    Text("Lv.1 초당 \(Won.short(firstIncome)) · 월세 \(Won.short(rent * Lease.daysPerMonth)) · 원가율 \(Int(k.cogsRatio * 100))%")
                        .font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
                    Text(info.blurb)
                        .font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
                        .lineLimit(2)
                } else {
                    Label("\(Rank.all[info.unlockRank].title) 되면 열림", systemImage: "lock.fill")
                        .font(.system(size: 12)).foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 0)
            if unlocked {
                Button {
                    if game.openStore(k, in: district) { dismiss() }
                } label: {
                    Text(blocker ?? "열기")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(blocker == nil ? .white : Palette.inkFaint)
                        .frame(width: 74, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(blocker == nil ? Palette.sign : Palette.cardDeep)
                        )
                }
                .buttonStyle(PressStyle())
                .disabled(blocker != nil)
            }
        }
        .paperCard(padding: 12)
    }
}
