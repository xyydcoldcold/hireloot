import Foundation

/// A Lv.7 demo save for screenshots (launch with `-HLDemo YES`). Same data as the web README screenshots.
enum DemoSave {
    static func make() -> SaveState {
        let zh = (UserDefaults.standard.string(forKey: "HLLang") ?? "zh") == "zh"
        func d(_ n: Int) -> String { Day.string(Calendar.current.date(byAdding: .day, value: -n, to: Date())!) }
        var tasks: [TaskItem] = []
        var id = 0
        let now = IDs.nowMs()
        func T(_ title: String, _ cat: String, _ created: String, _ done: String?) {
            id += 1
            var t = TaskItem(id: "t\(id)", title: title, category: cat, createdDate: created, createdAt: now - 1e9 + Double(id) * 1000)
            t.doneDate = done
            t.doneAt = done == nil ? nil : now - 1e8 + Double(id)
            tasks.append(t)
        }
        var n = 0
        for (c, k) in [("project", 8), ("resume", 6), ("prep", 6), ("network", 3), ("apply", 5)] {
            for _ in 0..<k { n += 1; T((zh ? "过去的任务 " : "Past quest ") + "\(n)", c, d(3 + n % 9), d(2 + n % 9)) }
        }
        if let i = tasks.firstIndex(where: { $0.category == "project" }) { tasks[i].doneDate = d(0) }
        let pend: [(String, String, Int)] = zh
            ? [("简历项目经历加上量化成果", "resume", 2), ("投递 Shopify、Wealthsimple、Cohere", "apply", 0),
               ("在领英上约 2 位校友 coffee chat", "network", 0), ("刷 2 道 LeetCode 中等题 + 复习系统设计", "prep", 0), ("去干洗店取衣服", "none", 0)]
            : [("Quantify impact in resume project bullets", "resume", 2), ("Apply to Shopify, Wealthsimple, Cohere", "apply", 0),
               ("Message 2 alumni on LinkedIn for coffee chats", "network", 0), ("2 LeetCode mediums + review system design", "prep", 0),
               ("Pick up dry cleaning", "none", 0)]
        for (t, c, a) in pend { T(t, c, d(a), nil) }
        T(zh ? "更新 LinkedIn 简介" : "Refresh LinkedIn headline", "resume", d(5), d(4))

        var s = SaveState()
        s.tasks = tasks
        s.interviews = [
            Interview(id: "i1", company: "Wealthsimple", round: "phone", result: "fail", date: d(9), note: "", bonus: 10, createdAt: 1),
            Interview(id: "i2", company: "Shopify", round: "r2", result: "pass", date: d(4), note: zh ? "系统设计聊得不错" : "System design went well", bonus: 15, createdAt: 2),
            Interview(id: "i3", company: "Cohere", round: "final", result: "pending", date: d(0), note: zh ? "准备讲过去项目的细节" : "Prep deep-dive on past projects", bonus: 30, createdAt: 3)
        ]
        let ssr = Weapons.byId["holy_blade"] ?? Weapons.all.first { $0.rarity == "SSR" }!
        var owned = [ssr.id: 1]
        let others = Weapons.all.filter { $0.id != ssr.id && $0.rarity != "SSR" }
        for i in 0..<13 { owned[others[(i * 3) % others.count].id] = 1 + (i % 3 == 0 ? 1 : 0) }
        s.armory = Armory()
        s.armory.owned = owned
        s.armory.equipped = ssr.id
        s.armory.opened = UserDefaults.standard.bool(forKey: "HLDemoPacks") ? 12 : 15
        s.armory.pity = 2
        s.profile = Profile(name: zh ? "小羊有点凉凉" : "xyydcoldcold")
        return s
    }
}
