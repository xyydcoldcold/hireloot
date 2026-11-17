import SwiftUI

struct QuestBoard: View {
    let store: JournalStore
    let now: Date
    @Binding var title: String
    @Binding var effort: Effort?
    @Binding var expanded: Set<Date>
    let edit: (Quest) -> Void

    @FocusState private var titleFocused: Bool

    var body: some View {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        let days = store.journal.completedDays(calendar: calendar)
        let completedToday = days.first { $0.date == today }?.quests ?? []
        let history = days.filter { $0.date != today }
        let open = store.journal.openQuests

        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(Theme.day(now))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Text("今日任务")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(open.count) 项待办 · 今日完成 \(completedToday.count) 项")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }

                composer

                if open.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(Theme.moss)
                            .accessibilityHidden(true)
                        Text("当前没有待办")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 112)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).allowsHitTesting(false))
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("待完成")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        questList(open, today: today)
                    }
                }

                completionGroup(title: "今日已完成", quests: completedToday, date: today, today: today)

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("完成历史")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(history) { day in
                            completionGroup(title: Theme.historyDay(day.date), quests: day.quests, date: day.date, today: today)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("添加一项任务…", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .focused($titleFocused)
                .onSubmit(addQuest)
                .accessibilityLabel("任务名称")
                .padding(.leading, 5)

            EffortMenu(effort: $effort)

            Button(action: addQuest) {
                Label("添加", systemImage: "plus")
            }
            .buttonStyle(ActionButton())
            .disabled(title.trimmed.isEmpty)
        }
        .padding(8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(titleFocused ? Theme.moss : Theme.divider, lineWidth: 1).allowsHitTesting(false))
    }

    private func completionGroup(title: String, quests: [Quest], date: Date, today: Date) -> some View {
        let isExpanded = expanded.contains(date)
        return VStack(spacing: 0) {
            Button {
                if isExpanded {
                    expanded.remove(date)
                } else {
                    expanded.insert(date)
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 11)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(quests.count) 项")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 13)
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(TapButton())
            .disabled(quests.isEmpty)
            .accessibilityLabel("\(title)，\(quests.count) 项")
            .accessibilityValue(isExpanded ? "已展开" : "已折叠")

            if isExpanded && !quests.isEmpty {
                Rectangle().fill(Theme.divider).frame(height: 1)
                ForEach(quests) { quest in
                    questRow(quest, today: today)
                    if quest.id != quests.last?.id {
                        Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 42)
                    }
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.divider).allowsHitTesting(false))
    }

    private func questList(_ quests: [Quest], today: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(quests) { quest in
                questRow(quest, today: today)
                if quest.id != quests.last?.id {
                    Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 42)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.divider).allowsHitTesting(false))
    }

    private func questRow(_ quest: Quest, today: Date) -> some View {
        let completed = quest.completedAt != nil
        return HStack(spacing: 9) {
            Button {
                if store.update({ $0.toggleQuest(quest.id) }) && !completed {
                    expanded.insert(Calendar.autoupdatingCurrent.startOfDay(for: .now))
                }
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(completed ? Theme.moss : Theme.muted)
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TapButton())
            .accessibilityLabel(completed ? "取消完成 \(quest.title)" : "完成 \(quest.title)")
            .help(completed ? "移回待办" : "标记完成")

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(completed)
                    .foregroundStyle(completed ? Theme.muted : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !completed && quest.createdAt < today {
                    Text("结转自 \(Theme.day(quest.createdAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let effort = quest.effort {
                Label(effort.title, systemImage: effort.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(effort.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(effort.background, in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
            }

            Button {
                edit(quest)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 23, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TapButton())
            .accessibilityLabel("编辑 \(quest.title)")
            .help("编辑任务")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private func addQuest() {
        guard store.update({ $0.addQuest(title, effort: effort) }) else { return }
        title = ""
        effort = nil
        titleFocused = true
    }
}

struct EffortMenu: View {
    @Binding var effort: Effort?

    var body: some View {
        Menu {
            choice("普通待办", value: nil)
            Divider()
            ForEach(Effort.allCases) { item in
                choice(item.title, value: item)
            }
        } label: {
            Text(effort?.title ?? "普通待办")
        }
        .menuStyle(.borderlessButton)
        .font(.system(size: 12, weight: .medium))
        .fixedSize()
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(effort?.background ?? Theme.mint, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel("任务类别")
        .accessibilityValue(effort?.title ?? "普通待办")
    }

    private func choice(_ title: String, value: Effort?) -> some View {
        Button {
            effort = value
        } label: {
            if effort == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

struct QuestEditor: View {
    let save: (String, Effort?) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var effort: Effort?

    init(quest: Quest, save: @escaping (String, Effort?) -> Bool) {
        _title = State(initialValue: quest.title)
        _effort = State(initialValue: quest.effort)
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑任务").font(.title2.bold())
            TextField("任务名称", text: $title)
                .textFieldStyle(.roundedBorder)
            EffortMenu(effort: $effort)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    if save(title, effort) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.moss)
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmed.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
