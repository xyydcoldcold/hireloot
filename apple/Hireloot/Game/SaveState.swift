import Foundation

/// The save file. Field names and shapes match the web version's `hireloot.v1` JSON exactly,
/// so the same cloud save (Supabase `saves.data`) works on the web, iPhone and Mac.
struct SaveState: Codable, Equatable {
    var version: Int = 1
    var tasks: [TaskItem] = []
    var interviews: [Interview] = []
    var armory = Armory()
    var profile: Profile?

    init() {}

    var isEmpty: Bool { tasks.isEmpty && interviews.isEmpty && armory.opened == 0 }
    var heroName: String { profile?.name ?? "" }

    enum CodingKeys: String, CodingKey { case version, tasks, interviews, armory, profile }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        tasks = (try? c.decode([Lenient<TaskItem>].self, forKey: .tasks))?.compactMap(\.value) ?? []
        interviews = (try? c.decode([Lenient<Interview>].self, forKey: .interviews))?.compactMap(\.value) ?? []
        armory = (try? c.decode(Armory.self, forKey: .armory)) ?? Armory()
        profile = try? c.decode(Profile.self, forKey: .profile)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(interviews, forKey: .interviews)
        try c.encode(armory, forKey: .armory)
        try c.encodeIfPresent(profile, forKey: .profile)
    }

    /// Accepts a save only if it looks like one (web: `Array.isArray(s.tasks) && Array.isArray(s.interviews)`).
    static func decodeStrict(_ data: Data) -> SaveState? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["tasks"] is [Any], obj["interviews"] is [Any] else { return nil }
        return try? JSONDecoder().decode(SaveState.self, from: data)
    }
    func jsonData(pretty: Bool = false) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.withoutEscapingSlashes]
        return (try? e.encode(self)) ?? Data("{}".utf8)
    }
    func jsonObject() -> Any { (try? JSONSerialization.jsonObject(with: jsonData())) ?? [:] }
}

struct TaskItem: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var category: String
    var createdDate: String
    var createdAt: Double
    var doneDate: String?
    var doneAt: Double?

    enum CodingKeys: String, CodingKey { case id, title, category, createdDate, createdAt, doneDate, doneAt }
    init(id: String, title: String, category: String, createdDate: String, createdAt: Double) {
        self.id = id; self.title = title; self.category = category
        self.createdDate = createdDate; self.createdAt = createdAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeLoose(.id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? "none"
        createdDate = (try? c.decode(String.self, forKey: .createdDate)) ?? Day.today()
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? 0
        doneDate = try? c.decode(String.self, forKey: .doneDate)
        if doneDate?.isEmpty == true { doneDate = nil }
        doneAt = try? c.decode(Double.self, forKey: .doneAt)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(category, forKey: .category)
        try c.encode(createdDate, forKey: .createdDate)
        try c.encode(JSNumber(createdAt), forKey: .createdAt)
        try c.encode(doneDate, forKey: .doneDate)          // explicit null, like the web
        try c.encode(doneAt.map(JSNumber.init), forKey: .doneAt)
    }
}

struct Interview: Codable, Equatable, Identifiable {
    var id: String
    var company: String
    var round: String
    var result: String  // pass | fail | pending
    var date: String
    var note: String
    var bonus: Int
    var createdAt: Double

    enum CodingKeys: String, CodingKey { case id, company, round, result, date, note, bonus, createdAt }
    init(id: String, company: String, round: String, result: String, date: String, note: String, bonus: Int, createdAt: Double) {
        self.id = id; self.company = company; self.round = round; self.result = result
        self.date = date; self.note = note; self.bonus = bonus; self.createdAt = createdAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeLoose(.id)
        company = (try? c.decode(String.self, forKey: .company)) ?? ""
        round = (try? c.decode(String.self, forKey: .round)) ?? "other"
        result = (try? c.decode(String.self, forKey: .result)) ?? "pending"
        date = (try? c.decode(String.self, forKey: .date)) ?? Day.today()
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        bonus = (try? c.decode(Int.self, forKey: .bonus)) ?? Int((try? c.decode(Double.self, forKey: .bonus)) ?? 0)
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? 0
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(company, forKey: .company)
        try c.encode(round, forKey: .round)
        try c.encode(result, forKey: .result)
        try c.encode(date, forKey: .date)
        try c.encode(note, forKey: .note)
        try c.encode(bonus, forKey: .bonus)
        try c.encode(JSNumber(createdAt), forKey: .createdAt)
    }
}

/// owned = { weaponId: times pulled }, opened = packs opened, pity = packs since the last SR+
struct Armory: Codable, Equatable {
    var owned: [String: Int] = [:]
    var equipped: String?
    var opened = 0
    var pity = 0

    enum CodingKeys: String, CodingKey { case owned, equipped, opened, pity }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let o = try? c.decode([String: Double].self, forKey: .owned) {
            owned = o.mapValues { Int($0) }
        }
        equipped = try? c.decode(String.self, forKey: .equipped)
        opened = Int((try? c.decode(Double.self, forKey: .opened)) ?? 0)
        pity = Int((try? c.decode(Double.self, forKey: .pity)) ?? 0)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(owned, forKey: .owned)
        try c.encode(equipped, forKey: .equipped)
        try c.encode(opened, forKey: .opened)
        try c.encode(pity, forKey: .pity)
    }
}

struct Profile: Codable, Equatable {
    var name: String?
}

/// Skips a broken entry instead of failing the whole save.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// Writes whole numbers without a decimal point (JS `Date.now()` style).
struct JSNumber: Encodable {
    let v: Double
    init(_ v: Double) { self.v = v }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if v.rounded() == v, abs(v) < 9e15 { try c.encode(Int64(v)) } else { try c.encode(v) }
    }
}

extension KeyedDecodingContainer {
    /// ids are strings on the web, but tolerate numbers from hand-edited saves.
    func decodeLoose(_ key: Key) throws -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let d = try? decode(Double.self, forKey: key) { return String(Int64(d)) }
        return IDs.make()
    }
}

enum IDs {
    /// Same shape as the web's `Date.now().toString(36) + random`.
    static func make() -> String {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String(ms, radix: 36) + String((0..<5).map { _ in chars.randomElement()! })
    }
    static func nowMs() -> Double { (Date().timeIntervalSince1970 * 1000).rounded() }
}

/// Dates are stored as local `YYYY-MM-DD` strings, like the web.
enum Day {
    static func today() -> String { string(Date()) }
    static func string(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func date(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
    static func between(_ a: String, _ b: String) -> Int {
        guard let x = date(a), let y = date(b) else { return 0 }
        return Calendar.current.dateComponents([.day], from: x, to: y).day ?? 0
    }
}
