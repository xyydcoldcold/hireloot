import SwiftUI

/// Date field in the `.picker-btn` look; opens a pixel calendar right under it (no system date picker).
struct PixelDateField: View {
    @Binding var date: Date
    let lang: String
    /// Screenshot hook: `-HLCalendar YES` opens the calendar on launch.
    var startOpen = false
    @State private var open = false
    @State private var hover = false
    @State private var token = UUID()

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 0) {
                PixelCalIcon().padding(.trailing, 8)
                Text(Self.label(date, lang)).lineLimit(1).fixedSize()
                Text("▼").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold).padding(.leading, 12)
            }
            .font(Theme.font(Theme.m))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.deep)
            .overlay(InsetShade(width: 3, opacity: 0.45))
            .brightness(hover && !open ? 0.06 : 0)
            .padding(3)
            .background(Theme.edge)
            .padding(open ? 1 : 0)
            .overlay { if open { Rectangle().strokeBorder(Theme.gold, lineWidth: 3).padding(-3) } }
            .padding(open ? -1 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .onAppear { if startOpen { open = true } }
        .anchorPreference(key: PixelMenuKey.self, value: .bounds) { a in
            guard open else { return nil }
            let d = date, l = lang
            return PixelMenuRequest(id: token, anchor: a, height: 330, width: 260, close: { open = false }) { _ in
                AnyView(PixelCalendar(selected: d, lang: l) { date = $0; open = false })
            }
        }
    }

    static func label(_ d: Date, _ lang: String) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d)
        let y = c.year ?? 0, m = c.month ?? 1, day = c.day ?? 1
        return lang == "en" ? String(format: "%02d/%02d/%04d", m, day, y) : String(format: "%04d/%02d/%02d", y, m, day)
    }
}

/// Month grid in the picker-menu frame: ◀ month ▶, weekday row, square day cells, a Today button.
struct PixelCalendar: View {
    let selected: Date
    let lang: String
    let pick: (Date) -> Void
    @State private var month: Date
    @State private var hovered: Int?

    private static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.firstWeekday = 1; return c }()

    init(selected: Date, lang: String, pick: @escaping (Date) -> Void) {
        self.selected = selected
        self.lang = lang
        self.pick = pick
        let c = Self.cal.dateComponents([.year, .month], from: selected)
        _month = State(initialValue: Self.cal.date(from: c) ?? selected)
    }

    var body: some View {
        let cal = Self.cal
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - 1 + 7) % 7
        let ym = cal.dateComponents([.year, .month], from: month)
        let today = cal.dateComponents([.year, .month, .day], from: Date())
        let sel = cal.dateComponents([.year, .month, .day], from: selected)
        let weekdays = lang == "en" ? ["S", "M", "T", "W", "T", "F", "S"] : ["日", "一", "二", "三", "四", "五", "六"]
        let cell: CGFloat = 32

        VStack(spacing: 8) {
            HStack {
                arrow("◀") { shift(-1) }
                Spacer(minLength: 0)
                Text(lang == "en" ? "\(Self.monthName(ym.month ?? 1)) \(ym.year ?? 0)" : "\(ym.year ?? 0)年\(ym.month ?? 1)月")
                    .font(Theme.font(Theme.m)).foregroundStyle(Theme.gold)
                    .shadow(color: Theme.edge, radius: 0, x: 2, y: 2)
                Spacer(minLength: 0)
                arrow("▶") { shift(1) }
            }
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[i]).font(Theme.font(Theme.s)).foregroundStyle(i == 0 || i == 6 ? Theme.gold.opacity(0.8) : Theme.muted)
                        .frame(width: cell)
                }
            }
            VStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            let d = row * 7 + col - lead + 1
                            if d >= 1 && d <= days {
                                let isSel = sel.year == ym.year && sel.month == ym.month && sel.day == d
                                let isToday = today.year == ym.year && today.month == ym.month && today.day == d
                                Button { choose(d) } label: {
                                    Text("\(d)").font(Theme.font(Theme.m))
                                        .foregroundStyle(isSel ? Theme.edge : Theme.ink)
                                        .frame(width: cell, height: 30)
                                        .background(isSel ? Theme.gold : hovered == d ? Theme.rowHi : Color.clear)
                                        .overlay { if isToday && !isSel { Rectangle().strokeBorder(Theme.gold, lineWidth: 2) } }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { h in if h { hovered = d } else if hovered == d { hovered = nil } }
                            } else {
                                Color.clear.frame(width: cell, height: 30)
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button(lang == "en" ? "Today" : "今天") { pick(Date()) }
                    .buttonStyle(.pixel(Theme.button, size: Theme.s, compact: true))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .pixelMenuFrame()
    }

    private func arrow(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s).font(Theme.font(Theme.s)).foregroundStyle(Theme.gold)
                .frame(width: 30, height: 26)
                .background(Theme.deep)
                .padding(2).background(Theme.edge)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressOffset())
    }

    private func shift(_ n: Int) {
        if let m = Self.cal.date(byAdding: .month, value: n, to: month) { month = m }
    }

    private func choose(_ day: Int) {
        var c = Self.cal.dateComponents([.year, .month], from: month)
        c.day = day
        c.hour = 12
        if let d = Self.cal.date(from: c) { pick(d) }
    }

    private static func monthName(_ m: Int) -> String {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][max(0, min(11, m - 1))]
    }
}

/// Small pixel calendar glyph (red binding strip, page with dots).
struct PixelCalIcon: View {
    var body: some View {
        Canvas { ctx, _ in
            let px: CGFloat = 2
            func r(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: Color) {
                ctx.fill(Path(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: CGFloat(w) * px, height: CGFloat(h) * px)), with: .color(c))
            }
            r(0, 1, 9, 8, Theme.edge)
            r(1, 2, 7, 6, Color(hex: "#f6f2e0"))
            r(1, 2, 7, 2, Color(hex: "#ff6b6b"))
            r(2, 0, 1, 3, Theme.edge); r(6, 0, 1, 3, Theme.edge)
            for (x, y) in [(2, 5), (4, 5), (6, 5), (2, 6), (4, 6)] { r(x, y, 1, 1, Color(hex: "#48508f")) }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
