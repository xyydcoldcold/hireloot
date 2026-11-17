import Foundation

enum Effort: String, CaseIterable, Codable, Identifiable {
    case project, resume, application, networking, interviewPrep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project: "做项目"
        case .resume: "改简历"
        case .application: "投递"
        case .networking: "Networking"
        case .interviewPrep: "面试准备"
        }
    }

    var gear: String {
        switch self {
        case .project: "武器"
        case .resume: "护甲"
        case .application: "补给"
        case .networking: "盟友"
        case .interviewPrep: "招式"
        }
    }

    func equipment(at level: Int) -> String {
        let upgrades: [String]
        switch self {
        case .project: upgrades = ["训练短剑", "钢刃", "符文长剑", "星铸之刃"]
        case .resume: upgrades = ["旅人斗篷", "皮革护甲", "轻钢甲", "星钢战甲"]
        case .application: upgrades = ["布囊", "远行背包", "补给箱", "补给车"]
        case .networking: upgrades = ["独行", "同行伙伴", "冒险小队", "远征联盟"]
        case .interviewPrep: upgrades = ["基础招式", "模拟对练", "连携技", "临战专精"]
        }
        return upgrades[min(max(level - 1, 0), upgrades.count - 1)]
    }
}

struct Quest: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var effort: Effort?
    let createdAt: Date
    var completedAt: Date?

    init(title: String, effort: Effort?, createdAt: Date) {
        self.id = UUID()
        self.title = title
        self.effort = effort
        self.createdAt = createdAt
    }
}

enum InterviewStatus: String, CaseIterable, Codable, Identifiable {
    case scheduled, awaiting, passed, declined, cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scheduled: "待面试"
        case .awaiting: "等待结果"
        case .passed: "通过"
        case .declined: "未通过"
        case .cancelled: "取消"
        }
    }

    var isClosed: Bool {
        switch self {
        case .scheduled, .awaiting: false
        case .passed, .declined, .cancelled: true
        }
    }
}

struct Interview: Codable, Equatable, Identifiable {
    var id = UUID()
    var company = ""
    var role = ""
    var round = "第 1 轮"
    var scheduledAt = Date()
    var status: InterviewStatus = .scheduled
    var notes = ""
}

struct QuestDay: Identifiable {
    let date: Date
    let quests: [Quest]
    var id: Date { date }
}

struct Experience: Equatable {
    let points: Int
    let pointsPerLevel: Int

    var level: Int { 1 + points / pointsPerLevel }
    var progress: Int { points % pointsPerLevel }
}

struct Journal: Codable, Equatable {
    private(set) var quests: [Quest] = []
    private(set) var interviews: [Interview] = []

    var openQuests: [Quest] {
        quests.filter { $0.completedAt == nil }
    }

    func completedDays(calendar: Calendar) -> [QuestDay] {
        let completed = quests.compactMap { quest in
            quest.completedAt.map { (quest: quest, timestamp: $0) }
        }
        let groups = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.timestamp) }
        return groups.map { date, entries in
            let ordered = entries.sorted { $0.timestamp > $1.timestamp }
            return QuestDay(date: date, quests: ordered.map(\.quest))
        }
        .sorted { $0.date > $1.date }
    }

    var experienceByEffort: [Effort: Int] {
        quests.reduce(into: [:]) { points, quest in
            if quest.completedAt != nil, let effort = quest.effort {
                points[effort, default: 0] += 1
            }
        }
    }

    @discardableResult
    mutating func addQuest(_ title: String, effort: Effort?, now: Date = .now) -> Bool {
        let title = title.trimmed
        guard !title.isEmpty else { return false }
        quests.append(Quest(title: title, effort: effort, createdAt: now))
        return true
    }

    @discardableResult
    mutating func editQuest(_ id: UUID, title: String, effort: Effort?) -> Bool {
        let title = title.trimmed
        guard !title.isEmpty, let index = quests.firstIndex(where: { $0.id == id }) else { return false }
        quests[index].title = title
        quests[index].effort = effort
        return true
    }

    @discardableResult
    mutating func toggleQuest(_ id: UUID, now: Date = .now) -> Bool {
        guard let index = quests.firstIndex(where: { $0.id == id }) else { return false }
        quests[index].completedAt = quests[index].completedAt == nil ? now : nil
        return true
    }

    @discardableResult
    mutating func saveInterview(_ interview: Interview) -> Bool {
        var interview = interview
        interview.company = interview.company.trimmed
        interview.role = interview.role.trimmed
        interview.round = interview.round.trimmed
        interview.notes = interview.notes.trimmed
        guard !interview.company.isEmpty, !interview.role.isEmpty, !interview.round.isEmpty else { return false }
        if let index = interviews.firstIndex(where: { $0.id == interview.id }) {
            interviews[index] = interview
        } else {
            interviews.append(interview)
        }
        return true
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
