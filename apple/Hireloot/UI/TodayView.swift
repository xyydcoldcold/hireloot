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
                        ForEach(doneToday) { TaskRow(task: $0, today: today).opacity(0.85) }
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
                PixelPicker(options: PixelPicker.categories(l), value: $category, minWidth: 168, startOpen: UserDefaults.standard.bool(forKey: "HLPicker"))
                Button(l.t("add.submit"), action: submit).buttonStyle(.pixelPrimary)
            }
            VStack(alignment: .leading, spacing: 10) {
                PixelField(placeholder: l.t("add.ph"), text: $text, onSubmit: submit)
                HStack(spacing: 10) {
                    PixelPicker(options: PixelPicker.categories(l), value: $category, minWidth: 168, startOpen: UserDefaults.standard.bool(forKey: "HLPicker"))
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

/// `.task` row from style.css: 6px category bar, faint top highlight, hover lightens the row.
struct TaskRow: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState
    let task: TaskItem
    let today: String
    @State private var hover = false
    @State private var delHover = false

    var body: some View {
        let l = store.l
        let c = Rules.category(task.category)
        let color = Color(hex: c.color)
        let done = task.doneDate != nil
        let late = done ? 0 : Day.between(task.createdDate, today)
        HStack(alignment: .center, spacing: 14) {
            CheckBox(done: done) { store.toggle(task.id) }
                .accessibilityLabel(done ? l.t("task.undo") : l.t("task.complete"))

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(Theme.font(Theme.m))
                    .foregroundStyle(done ? Theme.muted : Theme.ink)
                    .strikethrough(done, pattern: .solid, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                FlowRow(spacing: 8) {
                    PixelPicker(options: PixelPicker.categories(l),
                                value: Binding(get: { Rules.validCategory(task.category) }, set: { store.setCategory(task.id, $0) }),
                                kind: .tag, tagColor: color)
                    if late > 0 {
                        Text(l.t("task.late", ["n": late])).font(Theme.font(Theme.s)).foregroundStyle(Color(hex: "#ffd6dc"))
                            .padding(.horizontal, 8).padding(.vertical, 1)
                            .background(Color(hex: "#7a2e3e"))
                            .padding(2).background(Theme.edge)
                    }
                    let r = l.rewardText(c.reward)
                    Text(r.isEmpty ? l.t("task.noReward") : r)
                        .font(Theme.font(Theme.s))
                        .foregroundStyle(r.isEmpty ? Theme.muted : Theme.gold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                ui.dialog = DialogRequest(title: l.t("task.delTitle"), body: l.t("task.delConfirm", ["t": task.title]),
                                          note: done ? l.t("task.delConfirmDone") : "", ok: l.t("task.del"),
                                          cancel: l.t("dlg.cancel"), danger: true) { store.deleteTask(task.id) }
            } label: {
                Text("✕").font(Theme.font(Theme.m)).foregroundStyle(delHover ? Theme.red : Theme.placeholder)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { delHover = $0 }
            .accessibilityLabel(l.t("task.del"))
        }
        .padding(.top, 10).padding(.bottom, 10).padding(.trailing, 10).padding(.leading, 20)
        .background(done ? Color(hex: "#1d2152") : hover ? Theme.rowHi : Theme.row)
        .overlay(alignment: .top) { Color.white.opacity(0.07).frame(height: 3).padding(.leading, 6) }
        .overlay(alignment: .leading) { color.frame(width: 6) }
        .padding(3)
        .background(Theme.edge)
        .onHover { hover = $0 }
    }
}

/// `.chk`: 32px square, sunken when open, raised green with a white ✔ when done; lighter on hover.
struct CheckBox: View {
    let done: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            ZStack {
                done ? Theme.greenDk : hover ? Color(hex: "#20255a") : Theme.deep
                InsetShade(width: 3, opacity: done ? 0.3 : 0.45, bottomRight: done)
                if done { Text("✔").font(Theme.font(Theme.m)).foregroundStyle(.white) }
            }
            .frame(width: 26, height: 26)
            .padding(3)
            .background(Theme.edge)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressOffset())
        .onHover { hover = $0 }
    }
}

/// `button:active { transform: translate(2px, 2px) }`.
struct PressOffset: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
    }
}

/// Wrapping row (`flex-wrap: wrap`).
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }
    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }
    private func arrange(_ maxW: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let add = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + add > maxW { rows.append(Row()) }
            let w = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            rows[rows.count - 1].items.append(i)
            rows[rows.count - 1].width += w
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, s.height)
        }
        return rows
    }
}
