import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, boss, armory, log
    var id: String { rawValue }
    var icon: String { ["today": "scroll", "boss": "demon", "armory": "chest", "log": "castle"][rawValue]! }
    var titleKey: String { "tab." + rawValue }
}

/// A confirm / alert box in the pixel style (dialog.js).
struct DialogRequest: Identifiable {
    let id = UUID()
    var title: String
    var body: String = ""
    var note: String = ""
    var ok: String
    var cancel: String?
    var danger = false
    var action: () -> Void = {}
}

@MainActor
final class UIState: ObservableObject {
    @Published var tab: AppTab = {
        let saved = UserDefaults.standard.string(forKey: "HLTab") ?? UserDefaults.standard.string(forKey: "hireloot.tab")
        return AppTab(rawValue: saved ?? "") ?? .today
    }() { didSet { UserDefaults.standard.set(tab.rawValue, forKey: "hireloot.tab") } }
    @Published var dialog: DialogRequest?
    @Published var showSettings = UserDefaults.standard.bool(forKey: "HLSettings")
    @Published var viewing: Weapon?
}

struct PixelDialog: View {
    let req: DialogRequest
    let close: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { if req.cancel != nil { close() } }
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(text: req.title)
                if !req.body.isEmpty { Text(req.body).pixelText(Theme.m).fixedSize(horizontal: false, vertical: true) }
                if !req.note.isEmpty { Text(req.note).pixelText(Theme.s, Theme.muted, shadow: false).fixedSize(horizontal: false, vertical: true) }
                HStack(spacing: 10) {
                    Spacer()
                    if let c = req.cancel { Button(c) { close() }.buttonStyle(.pixel) }
                    Button(req.ok) { close(); req.action() }
                        .buttonStyle(.pixel(req.danger ? Color(hex: "#a8343f") : Theme.greenDk))
                }
            }
            .pixelWindow(padding: 22)
            .frame(maxWidth: 420)
            .padding(24)
        }
    }
}

/// Custom pixel dropdown, a port of `.picker` in style.css: a square menu that appears instantly
/// right under the button (no popover, no rounded corners). The menu is drawn by `PixelMenuHost`
/// at the root so it floats above the rows that follow.
struct PixelPicker: View {
    struct Option: Identifiable { let id: String; let label: String; let icon: String? }
    enum Kind { case field, tag }
    let options: [Option]
    @Binding var value: String
    var kind: Kind = .field
    var tagColor: Color = Theme.button
    var minWidth: CGFloat = 0
    var fill = false
    /// Screenshot hook: `-HLPicker YES` opens the add-task picker on launch.
    var startOpen = false
    @State private var open = false
    @State private var hover = false
    @State private var token = UUID()

    var body: some View {
        let cur = options.first { $0.id == value } ?? options[0]
        let tag = kind == .tag
        Button { open.toggle() } label: {
            HStack(spacing: 0) {
                if let i = cur.icon { PixelIcon(name: i).padding(.trailing, tag ? 6 : 8) }
                Text(cur.label).lineLimit(1).fixedSize()
                if fill { Spacer(minLength: 0) }
                Text("▼").font(Theme.font(Theme.s))
                    .foregroundStyle(tag ? Color.black.opacity(0.55) : Theme.gold)
                    .padding(.leading, tag ? 8 : 12)
            }
            .font(Theme.font(tag ? Theme.s : Theme.m))
            .foregroundStyle(tag ? Theme.edge : Theme.ink)
            .padding(.horizontal, tag ? 8 : 12).padding(.vertical, tag ? 2 : 8)
            .frame(minWidth: max(0, minWidth - 6), maxWidth: fill ? .infinity : nil, alignment: .leading)
            .background(tag ? tagColor : Theme.deep)
            .overlay { tag ? AnyView(Bevel(width: 2, light: 0.3, dark: 0.25)) : AnyView(InsetShade(width: 3, opacity: 0.45)) }
            .brightness(hover && !open ? 0.06 : 0)
            .padding(tag ? 2 : 3)
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
            open ? PixelMenuRequest(id: token, anchor: a, options: options, selected: value, small: tag,
                                    select: { value = $0; open = false }, close: { open = false }) : nil
        }
    }

    static func categories(_ l: L10n) -> [Option] {
        Rules.categoryKeys.map { Option(id: $0, label: l.catLabel($0), icon: Rules.category($0).icon ?? "none") }
    }
    static func rounds(_ l: L10n) -> [Option] {
        Rules.bossRounds.map { Option(id: $0, label: l.t("round." + $0), icon: nil) }
    }
}

struct PixelMenuRequest {
    let id: UUID
    let anchor: Anchor<CGRect>
    let options: [PixelPicker.Option]
    let selected: String
    let small: Bool
    let select: (String) -> Void
    let close: () -> Void
}

struct PixelMenuKey: PreferenceKey {
    static var defaultValue: PixelMenuRequest? = nil
    static func reduce(value: inout PixelMenuRequest?, nextValue: () -> PixelMenuRequest?) { value = value ?? nextValue() }
}

/// Draws the open picker's menu over everything below it, and closes it on an outside tap.
struct PixelMenuHost: ViewModifier {
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(PixelMenuKey.self) { req in
            GeometryReader { geo in
                if let req {
                    let r = geo[req.anchor]
                    let rowH: CGFloat = req.small ? 26 : 35
                    let menuH = CGFloat(req.options.count) * rowH + CGFloat(max(0, req.options.count - 1)) * 2 + 28
                    let up = r.maxY + 6 + menuH > geo.size.height && r.minY - 6 - menuH > 0
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001).contentShape(Rectangle()).onTapGesture { req.close() }
                        PixelMenu(req: req, minWidth: r.width)
                            .fixedSize()
                            .alignmentGuide(.leading) { _ in -min(r.minX, max(8, geo.size.width - 8 - max(r.width, 200))) }
                            .alignmentGuide(.top) { d in up ? -(r.minY - 6 - d.height) : -(r.maxY + 6) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            }
        }
    }
}

extension View {
    func pixelMenuHost() -> some View { modifier(PixelMenuHost()) }
}

/// `.picker-menu`: 4px edge border, cream frame, hard drop shadow; rows get a gold ▶ on hover, a ✔ when selected.
struct PixelMenu: View {
    let req: PixelMenuRequest
    let minWidth: CGFloat
    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(req.options) { o in
                let sel = o.id == req.selected
                let hi = hovered == o.id
                Button { req.select(o.id) } label: {
                    HStack(spacing: 0) {
                        if let i = o.icon { PixelIcon(name: i).padding(.trailing, 8) }
                        Text(o.label).lineLimit(1).fixedSize()
                        Spacer(minLength: 0)
                        if sel { Text("\u{2714}\u{FE0E}").font(Theme.font(Theme.s)).padding(.leading, 16) }
                    }
                    .font(Theme.font(req.small ? Theme.s : Theme.m))
                    .foregroundStyle(sel ? Theme.gold : Theme.ink)
                    .padding(.leading, 28).padding(.trailing, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(hi ? Theme.rowHi : .clear)
                    .overlay(alignment: .leading) {
                        if hi { Text("▶").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold).padding(.leading, 8) }
                    }
                    .padding(2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { h in if h { hovered = o.id } else if hovered == o.id { hovered = nil } }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .frame(minWidth: max(0, minWidth - 8))
        .background(Theme.win)
        .overlay(Rectangle().strokeBorder(Theme.frame, lineWidth: 3))
        .overlay(Rectangle().inset(by: 3).strokeBorder(Theme.edge, lineWidth: 2))
        .padding(4)
        .background(Theme.edge)
        .background(Rectangle().fill(Color.black.opacity(0.5)).offset(x: 6, y: 6))
    }
}

/// CSS `box-shadow: inset 3px 3px 0 rgba(0,0,0,.45)`: a dark band along the top and left edges.
struct InsetShade: View {
    var width: CGFloat = 3
    var opacity: Double = 0.45
    var bottomRight = false
    var body: some View {
        ZStack(alignment: bottomRight ? .bottomTrailing : .topLeading) {
            Color.clear
            VStack(spacing: 0) {
                if bottomRight { Spacer(minLength: 0) }
                Color.black.opacity(opacity).frame(height: width)
                if !bottomRight { Spacer(minLength: 0) }
            }
            HStack(spacing: 0) {
                if bottomRight { Spacer(minLength: 0) }
                Color.black.opacity(opacity).frame(width: width).padding(bottomRight ? .bottom : .top, width)
                if !bottomRight { Spacer(minLength: 0) }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Raised bevel: light top/left, dark bottom/right (`inset -2px -2px dark, inset 2px 2px light`).
struct Bevel: View {
    var width: CGFloat = 3
    var light: Double = 0.18
    var dark: Double = 0.35
    var body: some View {
        ZStack {
            InsetShade(width: width, opacity: dark, bottomRight: true)
            ZStack(alignment: .topLeading) {
                Color.clear
                VStack(spacing: 0) { Color.white.opacity(light).frame(height: width); Spacer(minLength: 0) }
                HStack(spacing: 0) { Color.white.opacity(light).frame(width: width); Spacer(minLength: 0) }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Floating reward text ("+3 ATK +20 EXP") that rises and fades.
struct FloatTextView: View {
    let event: FloatEvent
    @State private var up = false
    var body: some View {
        Text(event.text)
            .pixelText(Theme.l, event.color)
            .shadow(color: Theme.edge, radius: 0, x: 3, y: 3)
            .offset(y: up ? -70 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { up = true } }
            .allowsHitTesting(false)
    }
}

/// "LEVEL UP!" banner.
struct LevelUpBanner: View {
    let event: LevelUpEvent
    let l: L10n
    @State private var shown = false
    var body: some View {
        VStack(spacing: 6) {
            LayeredText(text: "LEVEL UP!")
            Text("Lv.\(event.lv) · \(l.titleName(event.lv))").pixelText(Theme.m)
            if event.packs > 0 {
                HStack(spacing: 6) { PixelIcon(name: "pack"); Text(l.t("pack.gain", ["n": event.packs])).pixelText(Theme.m, Theme.gold) }
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 18)
        .background(Theme.edge.opacity(0.85))
        .overlay(Rectangle().strokeBorder(Theme.gold, lineWidth: 3))
        .scaleEffect(shown ? 1 : 0.4)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { shown = true } }
        .allowsHitTesting(false)
    }
}

/// Full-width segmented pixel control.
struct PixelSegment: View {
    let options: [(id: String, label: String)]
    @Binding var value: String
    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { i in
                let o = options[i]
                Button(o.label) { value = o.id }
                    .buttonStyle(.pixel(o.id == value ? Theme.gold : Theme.button, fg: o.id == value ? Theme.edge : Theme.ink, size: Theme.m, compact: true))
            }
        }
    }
}
