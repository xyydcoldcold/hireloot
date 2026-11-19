import Foundation

/// Game rules, ported 1:1 from app.js / weapons.js. All numbers come from GameData.json.
enum Rules {
    static let data = GameData.shared

    // MARK: Categories
    static let categoryKeys: [String] = data.rules.categories.map(\.key)
    static let effortKeys: [String] = categoryKeys.filter { $0 != "none" }
    static let categories: [String: GameData.CategoryDef] =
        Dictionary(uniqueKeysWithValues: data.rules.categories.map { ($0.key, $0) })
    static func category(_ key: String) -> GameData.CategoryDef { categories[key] ?? categories["none"]! }
    static func validCategory(_ key: String) -> String { categories[key] == nil ? "none" : key }
    static func catExp(_ t: TaskItem) -> Int { category(t.category).reward.first { $0.stat == "exp" }?.amount ?? 0 }

    // MARK: Boss fights
    static let bossRounds = data.rules.bossRounds
    static func bossBase(_ result: String) -> GameData.BossReward {
        data.rules.bossReward[result] ?? data.rules.bossReward["pending"]!
    }
    static func bossReward(_ iv: Interview) -> (exp: Int, gold: Int) {
        let base = bossBase(iv.result)
        let bonus = iv.result == "pending" ? 0 : iv.bonus
        return (base.exp + bonus, base.gold)
    }
    /// INT -> bonus EXP for boss fights, locked in when the fight is logged.
    static func intBonus(_ int: Int) -> Int { min(100, (int / 3) * 5) }
    static let legacyRounds = ["笔试 / OA": "oa", "电话面": "phone", "一面": "r1", "二面": "r2",
                               "三面": "r3", "终面": "final", "HR 面": "hr", "其他": "other"]

    // MARK: Tiers
    static let packsPerLevel = data.rules.packsPerLevel
    static func armorTier(_ def: Int) -> (name: Int, color: String) {
        var cur = data.rules.armors[0]
        for a in data.rules.armors where def >= a[0].int { cur = a }
        return (cur[1].int, cur[2].string)
    }
    /// Index into the `titles` list; the hero portrait background uses the same thresholds.
    static func titleIndex(_ lv: Int) -> Int {
        var cur = data.rules.titles[0]
        for t in data.rules.titles where lv >= t[0] { cur = t }
        return cur[1]
    }

    static func levelInfo(_ exp: Int) -> (lv: Int, cur: Int, need: Int) {
        // EXP needed per level: 50, 75, 100, 125…
        var lv = 1, need = 50, rest = exp
        while rest >= need { rest -= need; lv += 1; need = 50 + (lv - 1) * 25 }
        return (lv, rest, need)
    }

    static func stats(_ s: SaveState) -> Stats {
        var st = Stats()
        for t in s.tasks where t.doneDate != nil {
            for r in category(t.category).reward { st.add(r.stat, r.amount) }
        }
        for iv in s.interviews {
            let r = bossReward(iv)
            st.exp += r.exp; st.gold += r.gold
            st.bosses += 1
            if iv.result == "pass" { st.wins += 1 }
        }
        let l = levelInfo(st.exp)
        st.lv = l.lv; st.cur = l.cur; st.need = l.need
        st.packs = max(0, (st.lv - 1) * packsPerLevel - s.armory.opened)
        st.weapon = equippedWeapon(s)
        st.wAtk = st.weapon.map { Weapons.atk(of: $0.id, count: s.armory.owned[$0.id] ?? 0) } ?? 0
        return st
    }

    static func equippedWeapon(_ s: SaveState) -> Weapon? {
        guard let id = s.armory.equipped, let w = Weapons.byId[id], (s.armory.owned[id] ?? 0) > 0 else { return nil }
        return w
    }
}

struct Stats: Equatable {
    var atk = 0, def = 0, int = 0, cha = 0, ally = 0, exp = 0, gold = 0, bosses = 0, wins = 0
    var lv = 1, cur = 0, need = 50, packs = 0
    var weapon: Weapon?
    var wAtk = 0
    mutating func add(_ stat: String, _ n: Int) {
        switch stat {
        case "atk": atk += n
        case "def": def += n
        case "int": int += n
        case "cha": cha += n
        case "ally": ally += n
        case "exp": exp += n
        case "gold": gold += n
        default: break
        }
    }
}

struct Weapon: Identifiable, Equatable, Hashable {
    let id: String
    let shape: String
    let pal: String
    let rarity: String
    let order: Int
    let name: [String: String]
    let desc: [String: String]
    func name(_ lang: String) -> String { name[lang] ?? name["zh"] ?? id }
    func desc(_ lang: String) -> String { desc[lang] ?? desc["zh"] ?? "" }
}

enum Weapons {
    static let d = GameData.shared.weapons
    static let all: [Weapon] = d.list.enumerated().map { i, w in
        Weapon(id: w.id, shape: w.shape, pal: w.pal, rarity: w.rarity, order: i, name: w.name, desc: w.desc)
    }
    static let byId: [String: Weapon] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let rarityOrder = d.rarityOrder
    static let pity = d.pity
    static let maxStars = d.maxStars
    static func rarity(_ r: String) -> GameData.Rarity { d.rarities[r] ?? d.rarities["N"]! }
    static func isHigh(_ r: String) -> Bool { r == "SR" || r == "SSR" }

    static func rollRarity(_ pityCount: Int) -> String {
        if pityCount >= pity - 1 {
            // Pity: only SR / SSR, in proportion to their rates
            let sr = rarity("SR").rate, ssr = rarity("SSR").rate
            return Double.random(in: 0..<(sr + ssr)) < ssr ? "SSR" : "SR"
        }
        var r = Double.random(in: 0..<100)
        for k in rarityOrder {
            r -= rarity(k).rate
            if r < 0 { return k }
        }
        return "N"
    }
    static func roll(_ pityCount: Int) -> Weapon {
        let r = rollRarity(pityCount)
        return all.filter { $0.rarity == r }.randomElement() ?? all[0]
    }
    /// Weapon ATK = rarity base + (stars - 1)
    static func atk(of id: String, count: Int) -> Int {
        guard let w = byId[id], count > 0 else { return 0 }
        return rarity(w.rarity).atk + min(count, maxStars) - 1
    }
}
