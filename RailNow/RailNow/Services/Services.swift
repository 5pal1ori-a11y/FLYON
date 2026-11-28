import Foundation

struct ServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 8
    config.timeoutIntervalForResource = 15
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
}()

private func text(_ value: Any?) -> String {
    if let s = value as? String { return s }
    if let n = value as? NSNumber { return n.stringValue }
    return ""
}

/// 서울 열린데이터광장 "지하철 실시간 열차 위치정보" (realtimePosition).
/// 응답 필드: trainNo, statnNm, statnTnm(종착역), updnLine(0 상행·내선 / 1 하행·외선),
/// trainSttus(0 진입 / 1 도착 / 2 출발 / 3 전역출발), directAt(1 급행, 7 특급), lstcarAt(1 막차), recptnDt
enum SubwayLiveService {
    static func fetch(lineName: String, key: String) async throws -> [SubwayTrain] {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let name = lineName.addingPercentEncoding(withAllowedCharacters: allowed),
              let safeKey = key.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "http://swopenapi.seoul.go.kr/api/subway/\(safeKey)/json/realtimePosition/0/200/\(name)")
        else { throw ServiceError(message: "요청 주소를 만들지 못했어요") }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw ServiceError(message: "서울시 서버 응답 오류 (\(http.statusCode))")
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError(message: "서울시 응답을 읽지 못했어요")
        }
        guard let rows = root["realtimePositionList"] as? [[String: Any]] else {
            let code = text(root["code"])
            if code == "INFO-200" { return [] }   // 해당하는 데이터 없음 (운행 종료 시간대)
            let message = text(root["message"])
            throw ServiceError(message: message.isEmpty ? "서울시 응답에 열차 정보가 없어요" : message)
        }

        var seen = Set<String>()
        var out: [SubwayTrain] = []
        for row in rows {
            let number = text(row["trainNo"])
            let station = text(row["statnNm"])
            guard !number.isEmpty, !station.isEmpty, seen.insert(number).inserted else { continue }
            let direct = text(row["directAt"])
            out.append(SubwayTrain(
                id: number,
                number: number,
                station: station,
                destination: text(row["statnTnm"]),
                upbound: text(row["updnLine"]) == "0",
                status: SubwayTrain.Status(rawValue: Int(text(row["trainSttus"])) ?? 1) ?? .arrived,
                express: direct == "1" || direct == "7",
                lastCar: text(row["lstcarAt"]) == "1",
                receivedAt: KST.parseDashed(text(row["recptnDt"])),
                estimated: false
            ))
        }
        return out
    }
}

/// 공공데이터포털 국토교통부 TAGO 열차정보(TrainInfoService).
/// 출발역·도착역·날짜로 그날 열차 목록(열차번호, 종류, 출발·도착 시각)을 준다.
/// 열차의 현재 좌표를 주는 공개 API는 없어서, 이 시간표로 위치를 추정한다.
enum RailScheduleService {
    private static let base = "https://apis.data.go.kr/1613000/TrainInfoService"
    private static let stationCacheKey = "tagoStationIDs.v1"

    private static func encodedKey(_ key: String) -> String {
        if key.contains("%") { return key }   // 이미 인코딩된 키
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
    }

    private static func items(_ operation: String, key: String, query: String) async throws -> [[String: Any]] {
        let address = "\(base)/\(operation)?serviceKey=\(encodedKey(key))&_type=json&numOfRows=400&pageNo=1\(query)"
        guard let url = URL(string: address) else { throw ServiceError(message: "요청 주소를 만들지 못했어요") }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw ServiceError(message: "공공데이터포털 응답 오류 (\(http.statusCode))")
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = (root["response"] as? [String: Any])?["body"] as? [String: Any]
        else {
            // 인증 오류는 _type=json이어도 XML로 온다.
            let raw = String(data: data, encoding: .utf8) ?? ""
            if raw.contains("SERVICE_KEY") { throw ServiceError(message: "공공데이터포털 인증키가 등록되지 않았어요") }
            if raw.contains("LIMITED_NUMBER") { throw ServiceError(message: "공공데이터포털 하루 호출 한도를 넘었어요") }
            throw ServiceError(message: "공공데이터포털 응답을 읽지 못했어요")
        }
        guard let wrapper = body["items"] as? [String: Any] else { return [] }   // 결과가 없으면 빈 문자열
        if let list = wrapper["item"] as? [[String: Any]] { return list }
        if let one = wrapper["item"] as? [String: Any] { return [one] }
        return []
    }

    /// 역 이름 → 역 ID. 한 번 받아 기기에 저장해 둔다.
    private static func stationIDs(key: String) async throws -> [String: String] {
        if let cached = UserDefaults.standard.dictionary(forKey: stationCacheKey) as? [String: String],
           cached.count > 50 {
            return cached
        }
        var map: [String: String] = [:]
        let cities = try await items("getCtyCodeList", key: key, query: "")
        for city in cities {
            let code = text(city["citycode"])
            guard !code.isEmpty else { continue }
            let stations = try await items("getCtyAcctoTrainSttnList", key: key, query: "&cityCode=\(code)")
            for s in stations {
                let name = text(s["nodename"])
                let id = text(s["nodeid"])
                if !name.isEmpty, !id.isEmpty { map[name] = id }
            }
        }
        guard !map.isEmpty else { throw ServiceError(message: "역 목록을 받지 못했어요") }
        UserDefaults.standard.set(map, forKey: stationCacheKey)
        return map
    }

    private static func lookup(_ names: [String], in map: [String: String]) -> String? {
        for name in names {
            if let id = map[name] { return id }
        }
        for name in names {
            if let hit = map.first(where: { $0.key.hasPrefix(name) }) { return hit.value }
        }
        return nil
    }

    static func trains(day: Date, key: String) async throws -> [RailTrain] {
        let ids = try await stationIDs(key: key)
        let date = KST.ymd(day)
        var cache: [String: [[String: Any]]] = [:]
        var out: [RailTrain] = []

        for route in RailCatalog.routes {
            guard let origin = lookup(route.originNames, in: ids),
                  let destination = lookup(route.destinationNames, in: ids) else { continue }
            for reversed in [false, true] {
                let from = reversed ? destination : origin
                let to = reversed ? origin : destination
                let pair = "\(from)>\(to)"
                let rows: [[String: Any]]
                if let hit = cache[pair] {
                    rows = hit
                } else {
                    rows = try await items(
                        "getStrtpntAlocFndTrainInfo", key: key,
                        query: "&depPlaceId=\(from)&arrPlaceId=\(to)&depPlandTime=\(date)"
                    )
                    cache[pair] = rows
                }
                for row in rows {
                    let grade = text(row["traingradename"])
                    guard route.kind.matches(grade),
                          let depart = KST.parseStamp(text(row["depplandtime"])),
                          let arrive = KST.parseStamp(text(row["arrplandtime"])),
                          arrive > depart else { continue }
                    let number = text(row["trainno"])
                    out.append(RailTrain(
                        id: "\(route.id)-\(reversed ? "r" : "f")-\(number)-\(Int(depart.timeIntervalSince1970))",
                        routeID: route.id, reversed: reversed, number: number, kindName: grade,
                        depart: depart, arrive: arrive, scheduled: true
                    ))
                }
            }
        }
        guard !out.isEmpty else { throw ServiceError(message: "오늘 시간표를 받지 못했어요") }
        return out
    }
}
