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

/// Custom pixel dropdown (not the native menu, which clashed with the style).
struct PixelPicker: View {
    struct Option: Identifiable { let id: String; let label: String; let icon: String? }
    let options: [Option]
    @Binding var value: String
    var small = false
    var tint: Color? = nil
    @State private var open = false

    var body: some View {
        let cur = options.first { $0.id == value } ?? options[0]
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                if let i = cur.icon { PixelIcon(name: i) }
                Text(cur.label).lineLimit(1)
                Text("▼").font(Theme.font(Theme.s)).foregroundStyle(Theme.muted)
            }
        }
        .buttonStyle(.pixel(tint ?? Theme.button, size: small ? Theme.s : Theme.m, compact: small))
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options) { o in
                    Button {
                        value = o.id
                        open = false
                    } label: {
                        HStack(spacing: 8) {
                            if let i = o.icon { PixelIcon(name: i) }
                            Text(o.label).pixelText(Theme.m, o.id == value ? Theme.edge : Theme.ink, shadow: o.id != value)
                            Spacer(minLength: 12)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(o.id == value ? Theme.gold : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Theme.win)
            .overlay(Rectangle().inset(by: 2).strokeBorder(Theme.frame, lineWidth: 2))
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
            .frame(minWidth: 200)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.win)
        }
    }

    static func categories(_ l: L10n) -> [Option] {
        Rules.categoryKeys.map { Option(id: $0, label: l.catLabel($0), icon: Rules.category($0).icon ?? "none") }
    }
    static func rounds(_ l: L10n) -> [Option] {
        Rules.bossRounds.map { Option(id: $0, label: l.t("round." + $0), icon: nil) }
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
            Text("LEVEL UP!").font(Theme.font(Theme.xl)).foregroundStyle(Theme.gold)
                .shadow(color: Theme.goldDk, radius: 0, x: 3, y: 3).shadow(color: Theme.edge, radius: 0, x: 6, y: 6)
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
