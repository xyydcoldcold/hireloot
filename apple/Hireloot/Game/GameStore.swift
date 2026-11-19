import SwiftUI

struct FloatEvent: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

struct LevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    let lv: Int
    let packs: Int
}

struct PullResult: Equatable {
    let weapon: Weapon
    let isNew: Bool
    let starUp: Bool
    let count: Int
}

/// Holds the save and every game action. Stats are always derived from the records,
/// so undoing a task can never leave the numbers out of sync.
@MainActor
final class GameStore: ObservableObject {
    static let storeKey = "hireloot.v1"
    static let langKey = "hireloot.lang"
    static let sfxKey = "hireloot.sfx"
    static let nameMax = 12

    @Published private(set) var state: SaveState
    @Published private(set) var stats: Stats
    @Published var lang: String { didSet { UserDefaults.standard.set(lang, forKey: Self.langKey) } }
    @Published var sfxOn: Bool {
        didSet { UserDefaults.standard.set(sfxOn ? "on" : "off", forKey: Self.sfxKey); Sfx.shared.enabled = sfxOn }
    }
    @Published var float: FloatEvent?
    @Published var levelUp: LevelUpEvent?
    @Published var packStageOpen = false
    @Published var today = Day.today()

    /// Called after every local change (cloud sync listens here).
    var onSave: (() -> Void)?
    private var lastLevel: Int

    var l: L10n { L10n(lang: lang) }

    init() {
        let d = UserDefaults.standard
        // Old JobQuest-era keys from the web build are not relevant here; the native app starts fresh or from the cloud.
        var s = SaveState()
        if let str = d.string(forKey: Self.storeKey), let loaded = SaveState.decodeStrict(Data(str.utf8)) { s = loaded }
        if d.bool(forKey: "HLDemo") { s = DemoSave.make() }
        state = s
        let st = Rules.stats(s)
        stats = st
        lastLevel = st.lv
        if let saved = d.string(forKey: Self.langKey) { lang = saved == "en" ? "en" : "zh" }
        else { lang = (Locale.preferredLanguages.first ?? "zh").hasPrefix("zh") ? "zh" : "en" }
        if let forced = d.string(forKey: "HLLang") { lang = forced }
        let sfx = d.string(forKey: Self.sfxKey) != "off"
        sfxOn = sfx
        Sfx.shared.enabled = sfx
    }

    // MARK: Persistence
    private func persist() {
        UserDefaults.standard.set(String(decoding: state.jsonData(), as: UTF8.self), forKey: Self.storeKey)
    }

    /// Saves, re-derives stats and fires level-up / float effects.
    private func commit(float text: String? = nil, color: Color = Theme.gold) {
        persist()
        onSave?()
        let st = Rules.stats(state)
        stats = st
        if let text, !text.isEmpty { float = FloatEvent(text: text, color: color) }
        if st.lv > lastLevel {
            let gained = st.lv - lastLevel
            levelUp = LevelUpEvent(lv: st.lv, packs: min(gained * Rules.packsPerLevel, st.packs))
            Sfx.shared.levelUp()
        }
        lastLevel = st.lv
    }

    /// A save from the cloud replaces the local one without level-up effects and without re-uploading.
    func replaceState(_ s: SaveState) {
        state = s
        persist()
        stats = Rules.stats(s)
        lastLevel = stats.lv
    }

    func refreshDay() { let d = Day.today(); if d != today { today = d } }

    // MARK: Tasks
    func addTask(_ title: String, category: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        state.tasks.append(TaskItem(id: IDs.make(), title: String(t.prefix(200)), category: Rules.validCategory(category),
                                    createdDate: Day.today(), createdAt: IDs.nowMs()))
        Sfx.shared.click()
        commit()
    }

    func toggle(_ id: String) {
        guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        let c = Rules.category(state.tasks[i].category)
        if state.tasks[i].doneDate != nil {
            state.tasks[i].doneDate = nil
            state.tasks[i].doneAt = nil
            commit()
        } else {
            state.tasks[i].doneDate = Day.today()
            state.tasks[i].doneAt = IDs.nowMs()
            Sfx.shared.complete()
            commit(float: l.rewardText(c.reward), color: Color(hex: c.color))
        }
    }

    func setCategory(_ id: String, _ cat: String) {
        guard let i = state.tasks.firstIndex(where: { $0.id == id }), state.tasks[i].category != cat else { return }
        state.tasks[i].category = Rules.validCategory(cat)
        commit()
    }

    func deleteTask(_ id: String) {
        state.tasks.removeAll { $0.id == id }
        commit()
    }

    // MARK: Boss fights
    func addInterview(company: String, round: String, date: Date, result: String, note: String) {
        let c = company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        let iv = Interview(id: IDs.make(), company: String(c.prefix(80)), round: round, result: result,
                           date: Day.string(date), note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)),
                           bonus: Rules.intBonus(stats.int), createdAt: IDs.nowMs())
        state.interviews.append(iv)
        let r = Rules.bossReward(iv)
        Sfx.shared.complete()
        commit(float: result == "pending" ? l.t("boss.engage") : l.rewardText(exp: r.exp, gold: r.gold),
               color: result == "pass" ? Theme.gold : Color(hex: "#ff8a80"))
    }

    func settle(_ id: String, pass: Bool) {
        guard let i = state.interviews.firstIndex(where: { $0.id == id }) else { return }
        state.interviews[i].result = pass ? "pass" : "fail"
        let r = Rules.bossReward(state.interviews[i])
        Sfx.shared.complete()
        commit(float: l.rewardText(exp: r.exp, gold: r.gold), color: pass ? Theme.gold : Color(hex: "#ff8a80"))
    }

    func deleteInterview(_ id: String) {
        state.interviews.removeAll { $0.id == id }
        commit()
    }

    // MARK: Hero
    func setName(_ v: String) {
        let clean = v.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let name = String(clean.prefix(Self.nameMax))
        guard name != state.heroName else { return }
        var p = state.profile ?? Profile()
        p.name = name
        state.profile = p
        commit()
    }

    // MARK: Armory
    /// Draws one card and writes it to the save right away (closing the app mid-animation loses nothing).
    func pull() -> PullResult {
        let w = Weapons.roll(state.armory.pity)
        state.armory.pity = Weapons.isHigh(w.rarity) ? 0 : state.armory.pity + 1
        let before = state.armory.owned[w.id] ?? 0
        state.armory.owned[w.id] = before + 1
        state.armory.opened += 1
        if state.armory.equipped.map({ (state.armory.owned[$0] ?? 0) == 0 }) ?? true {
            state.armory.equipped = w.id  // first weapon is equipped automatically
        }
        commit()
        return PullResult(weapon: w, isNew: before == 0, starUp: before > 0 && before < Weapons.maxStars, count: before + 1)
    }

    func equip(_ id: String?) {
        state.armory.equipped = id
        if id != nil { Sfx.shared.star() }
        commit()
    }

    func count(_ w: Weapon) -> Int { state.armory.owned[w.id] ?? 0 }

}
