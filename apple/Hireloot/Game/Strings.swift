import Foundation

/// UI texts, shared with the web version (i18n.js). `{n}` style placeholders are replaced by `vars`.
struct L10n {
    let lang: String  // "zh" | "en"

    private static let table = GameData.shared.strings

    func t(_ key: String, _ vars: [String: CustomStringConvertible] = [:]) -> String {
        var s: String
        switch L10n.table[lang]?[key] ?? L10n.table["zh"]?[key] {
        case .text(let v): s = v
        case .list(let l): s = l.joined(separator: ", ")
        default: s = L10n.native[lang]?[key] ?? L10n.native["zh"]?[key] ?? key
        }
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v.description) }
        return s
    }
    func list(_ key: String) -> [String] {
        if case .list(let l)? = L10n.table[lang]?[key] { return l }
        if case .list(let l)? = L10n.table["zh"]?[key] { return l }
        return []
    }

    func catLabel(_ k: String) -> String { t("cat." + Rules.validCategory(k)) }
    func statLabel(_ k: String) -> String { t("stat." + k) }
    func titleName(_ lv: Int) -> String {
        let l = list("titles"); let i = Rules.titleIndex(lv)
        return i < l.count ? l[i] : ""
    }
    func armorName(_ def: Int) -> String {
        let l = list("armors"); let i = Rules.armorTier(def).name
        return i < l.count ? l[i] : ""
    }
    func roundLabel(_ r: String) -> String {
        let k = Rules.bossRounds.contains(r) ? r : Rules.legacyRounds[r]
        return k.map { t("round." + $0) } ?? r
    }
    func rewardText(_ r: [GameData.Reward]) -> String {
        r.filter { $0.amount != 0 }.map { "+\($0.amount) \(statLabel($0.stat))" }.joined(separator: " ")
    }
    func rewardText(exp: Int, gold: Int) -> String {
        var parts: [String] = []
        if exp != 0 { parts.append("+\(exp) \(statLabel("exp"))") }
        if gold != 0 { parts.append("+\(gold) \(statLabel("gold"))") }
        return parts.joined(separator: " ")
    }
    func prettyDate(_ s: String) -> String {
        guard let d = Day.date(s) else { return s }
        if lang == "en" {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "EEE, MMM d"
            return f.string(from: d)
        }
        let c = Calendar.current.dateComponents([.month, .day, .weekday], from: d)
        let wd = list("weekdays")
        let w = (c.weekday ?? 1) - 1
        return "\(c.month ?? 0)月\(c.day ?? 0)日 周\(w < wd.count ? wd[w] : "")"
    }

    /// The few texts only the native app needs.
    static let native: [String: [String: String]] = [
        "zh": [
            "native.recoverWeb": "重设密码的链接会在网页版 hireloot.com 打开，设置好新密码后回到这里登录。"
        ],
        "en": [
            "native.recoverWeb": "The reset link opens the web version at hireloot.com. Set your new password there, then sign in here."
        ]
    ]
}
