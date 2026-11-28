import SpriteKit
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

enum Palette {
    static let bg = UIColor(hex: 0x120E1C)
    static let outline = UIColor(hex: 0x1A1424)
    static let p1 = UIColor(hex: 0x4AA3FF)
    static let p1Dark = UIColor(hex: 0x2D6CC0)
    static let p2 = UIColor(hex: 0xFF9A3C)
    static let p2Dark = UIColor(hex: 0xC0602D)
    static let skin = UIColor(hex: 0xFFD7B0)
    static let gold = UIColor(hex: 0xFFC83C)

    static func player(_ i: Int) -> UIColor { i == 0 ? p1 : p2 }
}

/// 픽셀 아트를 글자 그림으로 그려 텍스처로 만든다. (외부 그림 파일 없음)
@MainActor
enum Sprites {
    static func make(_ rows: [String], _ pal: [Character: UIColor]) -> SKTexture {
        let w = max(1, rows.map { $0.count }.max() ?? 1)
        let h = max(1, rows.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let c = pal[ch] else { continue }
                    c.setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let t = SKTexture(image: image)
        t.filteringMode = .nearest
        return t
    }

    static func emoji(_ s: String, size: CGFloat = 64) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size * 0.78)]
            let str = s as NSString
            let sz = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (size - sz.width) / 2, y: (size - sz.height) / 2), withAttributes: attrs)
        }
        return SKTexture(image: image)
    }

    // MARK: 캐릭터

    private static let playerRows = [
        "....kkkk....",
        "...kbbbbk...",
        "..kbbbbbbk..",
        "..kbbssssk..",
        "..kbsksksk..",
        "..kbssssssk.",
        "...kkkkkkk..",
        "..kccbbbcck.",
        ".kcbbbbbbbck",
        ".kcbbbbbbbck",
        "..kbbkkbbk..",
        "..kkk..kkk..",
    ]

    static let players: [SKTexture] = [
        make(playerRows, ["k": Palette.outline, "b": Palette.p1, "c": Palette.p1Dark, "s": Palette.skin]),
        make(playerRows, ["k": Palette.outline, "b": Palette.p2, "c": Palette.p2Dark, "s": Palette.skin]),
    ]

    static let slime = make([
        "...kkkk...",
        "..kggggk..",
        ".kgwggggk.",
        ".kgggggggk",
        "kgggkgkggk",
        "kggggggggk",
        "kddddddddk",
        ".kkkkkkkk.",
    ], ["k": Palette.outline, "g": UIColor(hex: 0x6BE070), "w": .white, "d": UIColor(hex: 0x3FA048)])

    private static let batPal: [Character: UIColor] = ["k": Palette.outline, "p": UIColor(hex: 0x9B6BE0), "r": UIColor(hex: 0xFF4D6D)]

    static let bat = [
        make([
            "k..........k",
            "kk........kk",
            "kpk.kkkk.kpk",
            "kppkppppkppk",
            ".kpprpprppk.",
            "..kppppppk..",
            "...kpkkpk...",
            "....k..k....",
        ], batPal),
        make([
            "............",
            "....kkkk....",
            "...kppppk...",
            "kkkprpprpkkk",
            "kppppppppppk",
            "kpk.kppk.kpk",
            "k...kkkk...k",
            "............",
        ], batPal),
    ]

    static let eye = make([
        "...kkkk...",
        ".kkwwwwkk.",
        ".kwwwwwwk.",
        "kwwrrrrwwk",
        "kwwrkkrwwk",
        "kwwrkkrwwk",
        "kwwrrrrwwk",
        ".kwwwwwwk.",
        ".kkwwwwkk.",
        "...kkkk...",
    ], ["k": Palette.outline, "w": UIColor(hex: 0xF2EEF8), "r": UIColor(hex: 0xE0405A)])

    static let charger = make([
        "k..........k",
        "wk........kw",
        ".wk.kkkk.kw.",
        "..kkrrrrkk..",
        ".krrrrrrrrk.",
        "krryrrrryrrk",
        "krrrrrrrrrrk",
        "krrkwkkwkrrk",
        ".krrrrrrrrk.",
        "..kk.kk.kk..",
    ], ["k": Palette.outline, "w": UIColor(hex: 0xF2EEF8), "r": UIColor(hex: 0xD9473B), "y": Palette.gold])

    static let boss = make([
        "...y...yy...y...",
        "...yy.yyyy.yy...",
        "...yyyyyyyyyy...",
        "...yryyyyyyry...",
        "..kkkkkkkkkkkk..",
        ".kmmmmmmmmmmmmk.",
        "kmmmmmmmmmmmmmmk",
        "kmmwwwmmmmwwwmmk",
        "kmmwkkmmmmkkwmmk",
        "kmmmmmmmmmmmmmmk",
        "kmmmmkkkkkkmmmmk",
        "kmmmkwkwwkwkmmmk",
        "kmmmmkkkkkkmmmmk",
        ".kmmmmmmmmmmmmk.",
        "..kddddddddddk..",
        "...kkkkkkkkkk...",
    ], ["k": Palette.outline, "y": Palette.gold, "r": UIColor(hex: 0xE0405A),
        "m": UIColor(hex: 0x5A3A8C), "w": .white, "d": UIColor(hex: 0x3A2460)])

    static func enemy(_ kind: EnemyKind, time: Double) -> SKTexture {
        switch kind {
        case .slime: return slime
        case .bat: return bat[Int(time * 8) % 2]
        case .eye: return eye
        case .charger: return charger
        case .boss: return boss
        }
    }

    static func enemySize(_ kind: EnemyKind) -> CGSize {
        switch kind {
        case .slime: return CGSize(width: 10.0 / 12, height: 8.0 / 12)
        case .bat: return CGSize(width: 1, height: 8.0 / 12)
        case .eye: return CGSize(width: 10.0 / 12, height: 10.0 / 12)
        case .charger: return CGSize(width: 1, height: 10.0 / 12)
        case .boss: return CGSize(width: 2.2, height: 2.2)
        }
    }

    static func enemyColor(_ kind: EnemyKind) -> UIColor {
        switch kind {
        case .slime: return UIColor(hex: 0x6BE070)
        case .bat: return UIColor(hex: 0x9B6BE0)
        case .eye: return UIColor(hex: 0xF2EEF8)
        case .charger: return UIColor(hex: 0xD9473B)
        case .boss: return Palette.gold
        }
    }

    // MARK: 아이템

    static let heart = make([
        ".kk.kk.",
        "krwkrrk",
        "krrrrrk",
        ".krrrk.",
        "..krk..",
        "...k...",
    ], ["k": Palette.outline, "r": UIColor(hex: 0xFF4D6D), "w": .white])

    static let heartEmpty = make([
        ".kk.kk.",
        "kggkggk",
        "kgggggk",
        ".kgggk.",
        "..kgk..",
        "...k...",
    ], ["k": Palette.outline, "g": UIColor(hex: 0x4A4058)])

    static let stairs = make([
        "kkkkkkkkkkkk",
        "khhhhhhhhhhk",
        "kddddddddddk",
        "kkhhhhhhhhkk",
        "kkddddddddkk",
        "kkkhhhhhhkkk",
        "kkkddddddkkk",
        "kkkkhhhhkkkk",
        "kkkkddddkkkk",
        "kkkkkhhkkkkk",
        "kkkkkkkkkkkk",
        "kkkkkkkkkkkk",
    ], ["k": UIColor(hex: 0x0A0710), "h": UIColor(hex: 0x8A7FA0), "d": UIColor(hex: 0x4A4058)])

    static let pedestal = make([
        "..gggggggg..",
        "..kkkkkkkk..",
        "...gggggg...",
        "...gddddg...",
        "..gggggggg..",
        "..kkkkkkkk..",
    ], ["k": Palette.outline, "g": UIColor(hex: 0x9C93B0), "d": UIColor(hex: 0x6A6080)])

    static let pickupEmoji: [PickupKind: SKTexture] = {
        var d: [PickupKind: SKTexture] = [:]
        for k in PickupKind.upgrades { d[k] = emoji(k.emoji) }
        return d
    }()

    // MARK: 탄환

    static let bulletFriendly = make([
        ".yyy.",
        "yywyy",
        "ywwwy",
        "yywyy",
        ".yyy.",
    ], ["y": Palette.gold, "w": .white])

    static let bulletEnemy = make([
        ".ppp.",
        "ppwpp",
        "pwwwp",
        "ppwpp",
        ".ppp.",
    ], ["p": UIColor(hex: 0xFF4DA6), "w": .white])

    // MARK: 타일

    private static func floorRows(_ v: Int) -> [String] {
        var rng = SplitMix64(seed: UInt64(v * 977 + 13))
        return (0..<12).map { y -> String in
            String((0..<12).map { x -> Character in
                if x == 0 || y == 0 { return "c" }
                return rng.int(9) == 0 ? "b" : "a"
            })
        }
    }

    static let floors: [SKTexture] = (0..<4).map { v in
        make(floorRows(v), ["a": UIColor(hex: 0x2E2640), "b": UIColor(hex: 0x272035), "c": UIColor(hex: 0x241D31)])
    }

    static let wall: SKTexture = {
        let rows = (0..<12).map { y -> String in
            String((0..<12).map { x -> Character in
                if y % 4 == 3 { return "m" }
                if (x + (y / 4 % 2) * 6) % 12 == 0 { return "m" }
                return y % 4 == 0 ? "h" : "w"
            })
        }
        return make(rows, ["w": UIColor(hex: 0x56467A), "h": UIColor(hex: 0x6A5A90), "m": UIColor(hex: 0x3A2F52)])
    }()

    static let rock = make([
        "............",
        "...kkkkkk...",
        "..krrhhrrk..",
        ".krhhhrrrrk.",
        ".krhrrrrrrk.",
        "krrrrrrrrrdk",
        "krrrrrrrrddk",
        "krrrrrrrdddk",
        ".krrrrrdddk.",
        ".kdddddddk..",
        "..kkkkkkk...",
        "............",
    ], ["k": Palette.outline, "r": UIColor(hex: 0x8A8299), "h": UIColor(hex: 0xB4ADC2), "d": UIColor(hex: 0x5E5670)])

    static let gate: SKTexture = {
        let rows = (0..<12).map { y -> String in
            String((0..<12).map { x -> Character in
                if y == 0 || y == 11 || y == 5 { return "i" }
                return x % 3 == 1 ? "i" : "d"
            })
        }
        return make(rows, ["i": UIColor(hex: 0xA08A5A), "d": UIColor(hex: 0x15101F)])
    }()

    static let pixel: SKTexture = make(["w"], ["w": .white])
}
