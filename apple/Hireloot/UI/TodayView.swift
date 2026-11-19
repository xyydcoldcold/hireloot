import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState
    @State private var text = ""
    @State private var category = "none"
    @State private var suggestion: String?
    @State private var doneOpen = true

    var body: some View {
        let l = store.l
        let today = store.today
        let pending = store.state.tasks.filter { $0.doneDate == nil }
            .sorted { ($0.createdDate, $0.createdAt) < ($1.createdDate, $1.createdAt) }
        let doneToday = store.state.tasks.filter { $0.doneDate == today }
            .sorted { ($0.doneAt ?? 0) > ($1.doneAt ?? 0) }
        let gained = doneToday.reduce(0) { $0 + Rules.catExp($1) } +
            store.state.interviews.filter { $0.date == today }.reduce(0) { $0 + Rules.bossReward($1).exp }

        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelTitle(text: l.prettyDate(today))
                    Spacer()
                    Pill(text: l.t("today.exp", ["n": gained]))
                }
                addForm(l)
                hint(l)
                VStack(spacing: 8) {
                    if pending.isEmpty {
                        EmptyLine(text: l.t("today.empty"))
                    } else {
                        ForEach(pending) { TaskRow(task: $0, today: today) }
                    }
                }
            }
            .pixelWindow()

            VStack(alignment: .leading, spacing: 10) {
                Button { withAnimation(.easeOut(duration: 0.15)) { doneOpen.toggle() } } label: {
                    HStack(spacing: 8) {
                        Text(doneOpen ? "▼" : "▶").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold)
                        Text("\(l.t("today.doneTitle")) (\(doneToday.count))").pixelText(Theme.m)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if doneOpen {
                    VStack(spacing: 8) {
                        if doneToday.isEmpty { EmptyLine(text: l.t("today.doneEmpty")) }
                        ForEach(doneToday) { TaskRow(task: $0, today: today) }
                    }
                }
            }
            .pixelWindow()
        }
    }

    @ViewBuilder private func addForm(_ l: L10n) -> some View {
        let submit = {
            store.addTask(text, category: category)
            text = ""; category = "none"; suggestion = nil
        }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                PixelField(placeholder: l.t("add.ph"), text: $text, onSubmit: submit).frame(minWidth: 260)
                PixelPicker(options: PixelPicker.categories(l), value: $category)
                Button(l.t("add.submit"), action: submit).buttonStyle(.pixelPrimary)
            }
            VStack(alignment: .leading, spacing: 10) {
                PixelField(placeholder: l.t("add.ph"), text: $text, onSubmit: submit)
                HStack(spacing: 10) {
                    PixelPicker(options: PixelPicker.categories(l), value: $category)
                    Spacer(minLength: 0)
                    Button(l.t("add.submit"), action: submit).buttonStyle(.pixelPrimary)
                }
            }
        }
        .onChange(of: text) { v in
            let s = v.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Categorizer.suggest(v)
            if s != suggestion { suggestion = s }
        }
    }

    @ViewBuilder private func hint(_ l: L10n) -> some View {
        let c = Rules.category(category)
        HStack(spacing: 8) {
            if category != "none" {
                Text(l.t("add.hint", ["label": l.catLabel(category), "desc": l.t("desc." + category), "reward": l.rewardText(c.reward)]))
                    .pixelText(Theme.s, Theme.muted, shadow: false)
            }
            if let s = suggestion, s != category {
                Button { category = s } label: {
                    HStack(spacing: 6) {
                        PixelIcon(name: Rules.category(s).icon ?? "none")
                        Text(l.t("add.suggest", ["c": l.catLabel(s)]))
                    }
                }
                .buttonStyle(.pixel(Color(hex: "#3a3f86"), size: Theme.s, compact: true))
            }
        }
        .frame(minHeight: 24, alignment: .leading)
    }
}

struct EmptyLine: View {
    let text: String
    var body: some View {
        Text(text).pixelText(Theme.s, Theme.muted, shadow: false)
            .frame(maxWidth: .infinity).padding(.vertical, 18).multilineTextAlignment(.center)
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState
    let task: TaskItem
    let today: String

    var body: some View {
        let l = store.l
        let c = Rules.category(task.category)
        let color = Color(hex: c.color)
        let done = task.doneDate != nil
        let late = done ? 0 : Day.between(task.createdDate, today)
        HStack(alignment: .center, spacing: 12) {
            Button { store.toggle(task.id) } label: {
                ZStack {
                    Theme.deep
                    if done { Text("✔").font(Theme.font(Theme.m)).foregroundStyle(Theme.green) }
                }
                .frame(width: 30, height: 30)
                .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? l.t("task.undo") : l.t("task.complete"))

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .pixelText(Theme.m, done ? Theme.muted : Theme.ink)
                    .strikethrough(done, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    PixelPicker(options: PixelPicker.categories(l),
                                value: Binding(get: { Rules.validCategory(task.category) }, set: { store.setCategory(task.id, $0) }),
                                small: true, tint: Color(hex: "#20245a"))
                    if late > 0 {
                        Text(l.t("task.late", ["n": late])).font(Theme.font(Theme.s)).foregroundStyle(Color(hex: "#ffb36b"))
                    }
                    let r = l.rewardText(c.reward)
                    Text(r.isEmpty ? l.t("task.noReward") : r)
                        .font(Theme.font(Theme.s))
                        .foregroundStyle(r.isEmpty ? Theme.muted.opacity(0.8) : Theme.gold)
                        .italic(r.isEmpty)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button {
                ui.dialog = DialogRequest(title: l.t("task.delTitle"), body: l.t("task.delConfirm", ["t": task.title]),
                                          note: done ? l.t("task.delConfirmDone") : "", ok: l.t("task.del"),
                                          cancel: l.t("dlg.cancel"), danger: true) { store.deleteTask(task.id) }
            } label: {
                Text("✕").font(Theme.font(Theme.m)).foregroundStyle(Theme.muted).frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l.t("task.del"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(done ? Theme.row.opacity(0.6) : Theme.row)
        .overlay(alignment: .leading) { color.frame(width: 6) }
        .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
    }
}
