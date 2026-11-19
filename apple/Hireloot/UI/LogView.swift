import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: GameStore
    @State private var collapsed: Set<String> = []
    @State private var expanded: Set<String> = []

    var body: some View {
        let l = store.l
        let done = store.state.tasks.filter { $0.doneDate != nil }
        let byDate = Dictionary(grouping: done, by: { $0.doneDate ?? "" })
        let dates = byDate.keys.sorted(by: >)
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(text: l.t("log.title"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(Rules.categoryKeys, id: \.self) { k in
                        let c = Rules.category(k)
                        VStack(spacing: 4) {
                            Text("\(done.filter { $0.category == k || (k == "none" && Rules.categories[$0.category] == nil) }.count)")
                                .font(Theme.font(Theme.l)).foregroundStyle(Color(hex: c.color))
                            HStack(spacing: 4) {
                                PixelIcon(name: c.icon ?? "none")
                                Text(l.catLabel(k)).font(Theme.font(Theme.s)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.deep)
                        .overlay(alignment: .top) { Color(hex: c.color).frame(height: 3) }
                        .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
                    }
                }
            }
            .pixelWindow()

            if dates.isEmpty {
                EmptyLine(text: l.t("log.empty")).pixelWindow()
            }
            ForEach(Array(dates.enumerated()), id: \.element) { i, d in
                let list = (byDate[d] ?? []).sorted { ($0.doneAt ?? 0) > ($1.doneAt ?? 0) }
                let exp = list.reduce(0) { $0 + Rules.catExp($1) }
                let open = i == 0 ? !collapsed.contains(d) : expanded.contains(d)
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if i == 0 { if collapsed.contains(d) { collapsed.remove(d) } else { collapsed.insert(d) } }
                            else if expanded.contains(d) { expanded.remove(d) } else { expanded.insert(d) }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(open ? "▼" : "▶").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold)
                            Text(l.t("log.day", ["date": l.prettyDate(d), "today": d == store.today ? l.t("log.today") : "", "n": list.count, "exp": exp]))
                                .pixelText(Theme.m).lineLimit(2)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if open {
                        VStack(spacing: 8) { ForEach(list) { TaskRow(task: $0, today: store.today) } }
                    }
                }
                .pixelWindow(padding: 16)
            }
        }
    }
}
