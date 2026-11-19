import Foundation

/// Everything the web version keeps in weapons.js / i18n.js / the tables at the top of app.js.
/// It is exported to Resources/GameData.json by apple/tools/export-game-data.js so the
/// native app and the web app always use the same weapons, sprites, rewards and texts.
struct GameData: Decodable {
    struct CategoryDef: Decodable {
        let key: String
        let icon: String?
        let color: String
        let reward: [Reward]
    }
    /// One `[stat, amount]` pair; kept as an ordered list so reward text reads like the web version.
    struct Reward: Decodable {
        let stat: String
        let amount: Int
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            stat = try c.decode(String.self)
            amount = try c.decode(Int.self)
        }
    }
    struct BossReward: Decodable { let exp: Int; let gold: Int }
    struct Rules: Decodable {
        let categories: [CategoryDef]
        let bossReward: [String: BossReward]
        let bossRounds: [String]
        /// [threshold, name index, color]
        let armors: [[JSONScalar]]
        /// [level, name index]
        let titles: [[Int]]
        let packsPerLevel: Int
    }
    struct Rarity: Decodable { let rate: Double; let atk: Int; let color: String }
    struct WeaponDef: Decodable {
        let id: String
        let shape: String
        let pal: String
        let rarity: String
        let name: [String: String]
        let desc: [String: String]
    }
    struct Weapons: Decodable {
        let shapes: [String: [String]]
        let palettes: [String: [String: String]]
        let rarities: [String: Rarity]
        let rarityOrder: [String]
        let pity: Int
        let maxStars: Int
        let list: [WeaponDef]
    }
    struct Held: Decodable { let top: Int; let rows: [String] }
    struct Icon: Decodable { let map: [String]; let pal: [String: String] }
    struct Art: Decodable {
        let hero: [String]
        let held: [String: Held]
        let heldKeys: [String: String]
        let boss: [String]
        let icons: [String: Icon]
    }

    let rules: Rules
    let weapons: Weapons
    let art: Art
    let strings: [String: [String: I18nValue]]

    static let shared: GameData = {
        guard let url = Bundle.main.url(forResource: "GameData", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("GameData.json missing from the app bundle")
        }
        do { return try JSONDecoder().decode(GameData.self, from: data) }
        catch { fatalError("GameData.json is broken: \(error)") }
    }()
}

enum JSONScalar: Decodable {
    case int(Int), string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i) } else { self = .string(try c.decode(String.self)) }
    }
    var int: Int { if case .int(let i) = self { return i }; return 0 }
    var string: String { if case .string(let s) = self { return s }; return "" }
}

enum I18nValue: Decodable {
    case text(String), list([String]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let s = try? c.decode(String.self) { self = .text(s) }
        else { self = .list(try c.decode([String].self)) }
    }
}
