import Foundation

// 세금 · 임대차 · 최저임금 · 기준금리 · 명절 · 시설 노후화

extension Game {

    // MARK: - 명절·시즌

    var holidays: [Holiday] { Holiday.active(onDay: day) }

    func holidayFactor(_ kind: BusinessKind, _ district: DistrictID) -> Double {
        holidays.reduce(1) { $0 * $1.factor(kind, district) }
    }

    // MARK: - 시설 노후화

    /// 노후도 40까지는 영향 없음, 100이면 매출 -30%
    func wearFactor(_ s: Store) -> Double {
        s.wear < 40 ? 1 : 1 - (s.wear - 40) / 200
    }

    func repairCost(_ s: Store) -> Double {
        (s.kind.info.openCost * 0.04 * s.wear / 100).rounded()
    }

    func repair(_ id: UUID) {
        guard let i = stores.firstIndex(where: { $0.id == id }) else { return }
        let cost = repairCost(stores[i])
        guard stores[i].wear >= 1, cash >= cost else { return }
        cash -= cost
        stores[i].wear = 0
        stores[i].invested += cost
        record(.upgrade, "\(stores[i].displayName) 시설 보수", -cost)
        toast = "\(stores[i].displayName) 수리 완료"
    }

    // MARK: - 원가

    func grossIncome(_ s: Store) -> Double { income(s) / (1 - s.kind.cogsRatio) }

    // MARK: - 임대차

    func baseRent(_ k: BusinessKind, _ d: DistrictID) -> Double {
        k.info.rent * d.info.rentMult
    }

    /// 새로 들어갈 때 내는 보증금. 내 건물이면 없음
    func newDeposit(_ k: BusinessKind, _ d: DistrictID) -> Double {
        ownsBuilding(in: d) ? 0 : Lease.deposit(dailyRent: baseRent(k, d))
    }

    var depositsValue: Double { stores.reduce(0) { $0 + $1.deposit } }

    func monthlyRent(_ s: Store) -> Double { rent(s) * Lease.daysPerMonth }

    func leaseDaysLeft(_ s: Store) -> Int { max(0, Lease.term - (day - s.leaseStart)) }

    func renewalRightLeft(_ s: Store) -> Int { max(0, Lease.renewalRightDays - (day - s.openedDay)) }

    // MARK: - 금리

    var loanAnnualRate: Double {
        baseRate + (hasTalent("banker") ? Money.bankerSpread : Money.spread)
    }

    // MARK: - 세금

    var legalName: String { isCorporation ? "(주)\(companyName)" : companyName }

    var projectedIncomeTax: Double { Tax.income(incomeTaxBase, corporation: isCorporation) }

    var projectedVAT: Double { Tax.vat(onMargin: vatBase + today.revenue) }

    var marginalRate: Double {
        let table = isCorporation ? Tax.corporate : Tax.personal
        return (table.first { incomeTaxBase <= $0.limit }?.rate ?? table.last!.rate) * 1.1
    }

    /// 다음 부가세 납부일(1·4·7·10월 25일)까지 남은 날
    var daysToVAT: Int {
        for offset in 0...130 {
            let d = day + offset
            if [1, 4, 7, 10].contains(GameCalendar.month(d)) && GameCalendar.dayOfMonth(d) == 25 {
                return offset
            }
        }
        return 0
    }

    var canIncorporate: Bool { highestRank >= 3 && !isCorporation }

    func incorporate() {
        guard canIncorporate, cash >= Tax.incorporationCost else { return }
        cash -= Tax.incorporationCost
        isCorporation = true
        record(.settle, "법인 설립 등기 · 주식회사 \(companyName)", -Tax.incorporationCost)
        pushNews(NewsItem(day: day, headline: "주식회사 \(companyName) 설립",
                          detail: "개인사업자에서 법인으로. 이제 법인세를 냅니다", tone: .neutral))
        toast = "법인 전환 완료 · (주)\(companyName)"
    }

    // MARK: - 매일 마감 직후

    func realismStep() {
        let m = GameCalendar.month(day)
        let d = GameCalendar.dayOfMonth(day)

        // 시설 노후화
        for i in stores.indices {
            var add = 0.5
            switch stores[i].kind.info.trait {
            case .night: add = 0.7
            case .unmanned: add = 0.9
            default: break
            }
            stores[i].wear = min(100, stores[i].wear + add)
        }

        // 임대차 갱신 (2년마다)
        for i in stores.indices where !ownsBuilding(in: stores[i].district) {
            guard day - stores[i].leaseStart >= Lease.term else { continue }
            let protected = day - stores[i].openedDay <= Lease.renewalRightDays
            let raise = protected ? Double.random(in: 0...Lease.renewalCap) : Double.random(in: 0.05...0.25)
            stores[i].rentFactor *= 1 + raise
            stores[i].leaseStart = day
            let extra = stores[i].deposit * raise
            cash -= extra
            stores[i].deposit += extra
            let name = stores[i].displayName
            pushNews(NewsItem(
                day: day, headline: "\(name) 임대차 계약 갱신",
                detail: protected
                    ? "임대료 +\(String(format: "%.1f", raise * 100))% (법정 상한 5%)"
                    : "갱신요구권 10년 만료 · 임대료 +\(String(format: "%.1f", raise * 100))%",
                tone: raise > 0.03 ? .bad : .neutral))
        }

        // 1월 1일: 최저임금 인상 + 작년 소득세 고지
        if m == 1 && d == 1 {
            let hike = Double.random(in: 0.025...0.05)
            wageIndex *= 1 + hike
            minimumWage = (minimumWage * (1 + hike) / 10).rounded() * 10
            pushNews(NewsItem(day: day, headline: "올해 최저시급 \(Won.full(minimumWage))",
                              detail: "작년보다 \(String(format: "%.1f", hike * 100))% 인상 · 전 점포 인건비 상승", tone: .bad))

            let taxable = incomeTaxBase
            incomeTaxBase = 0
            let amount = Tax.income(taxable, corporation: isCorporation)
            if amount >= 1 {
                let title = isCorporation ? "법인세" : "종합소득세"
                taxBill = TaxBill(title: title, amount: amount,
                                  dueDay: day + (isCorporation ? 29 : 49), taxable: taxable)
                pushNews(NewsItem(day: day, headline: "\(title) \(Won.short(amount)) 고지",
                                  detail: "작년 소득 \(Won.short(taxable)) · \(isCorporation ? "3월" : "5월") 말까지 납부",
                                  tone: .neutral))
            }
        }

        // 부가세: 1·4·7·10월 25일
        if [1, 4, 7, 10].contains(m) && d == 25 {
            let vat = Tax.vat(onMargin: vatBase)
            vatBase = 0
            if vat >= 1 {
                cash -= vat
                taxesPaid += vat
                record(.settle, "부가가치세 납부", -vat)
                toast = "부가가치세 \(Won.short(vat)) 납부"
            }
        }

        // 소득세·법인세 납부일
        if let bill = taxBill, day >= bill.dueDay {
            cash -= bill.amount
            taxesPaid += bill.amount
            record(.settle, "\(bill.title) 납부", -bill.amount)
            toast = "\(bill.title) \(Won.short(bill.amount)) 납부"
            taxBill = nil
        }

        // 기준금리 결정 (15일마다 금통위)
        if day % 15 == 0 {
            let pull = (Money.startingBaseRate - baseRate) * 0.15
            let r = Double.random(in: 0..<1)
            var change = 0.0
            if r < 0.25 + pull { change = -0.25 } else if r > 0.75 + pull { change = 0.25 }
            baseRate = min(6, max(0.5, baseRate + change))
            if change != 0 {
                for i in markets.indices {
                    markets[i].index = min(2.4, max(0.5, markets[i].index * (1 - change * 0.08)))
                    if let last = markets[i].history.indices.last { markets[i].history[last] = markets[i].index }
                }
            }
            let rateText = String(format: "%.2f", baseRate)
            pushNews(NewsItem(
                day: day,
                headline: change > 0 ? "한은, 기준금리 \(rateText)%로 인상"
                    : change < 0 ? "한은, 기준금리 \(rateText)%로 인하" : "한은, 기준금리 \(rateText)% 동결",
                detail: change > 0 ? "대출 이자 부담 증가 · 부동산 시세 하락 압력"
                    : change < 0 ? "대출 이자 부담 감소 · 부동산 시세 상승 기대" : "대출 금리 변동 없음",
                tone: change > 0 ? .bad : change < 0 ? .good : .neutral))
        }
    }
}
