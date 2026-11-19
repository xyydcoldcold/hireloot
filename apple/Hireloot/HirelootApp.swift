import SwiftUI

@main
struct HirelootApp: App {
    @StateObject private var store: GameStore
    @StateObject private var cloud: CloudSync
    @StateObject private var ui = UIState()

    init() {
        Theme.registerFont()
        let s = GameStore()
        _store = StateObject(wrappedValue: s)
        _cloud = StateObject(wrappedValue: CloudSync(store: s))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(cloud)
                .environmentObject(ui)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Button(store.l.t("settings")) { ui.showSettings = true }.keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var cloud: CloudSync
    @EnvironmentObject var ui: UIState
    @Environment(\.scenePhase) private var phase
    @State private var levelUpShown: LevelUpEvent?
    @State private var floatShown: FloatEvent?
    @State private var packFromLevelUp = false
    @State private var backToast: String?
    @State private var showWelcome = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 820
            ZStack {
                PixelBackground()
                if wide { wideLayout } else { compactLayout }
                overlays
            }
        }
        .onAppear {
            cloud.start()
            if UserDefaults.standard.bool(forKey: "HLOpenPacks") { store.packStageOpen = true }
        }
        .onChange(of: phase) { p in
            if p == .active { store.refreshDay(); cloud.pullIfStale() }
            else if p == .background { Task { await cloud.push() } }
        }
        .onReceive(timer) { _ in
            store.refreshDay()
            if phase == .active { cloud.pullIfStale(minInterval: 25) }
        }
        .onChange(of: store.float) { f in
            guard let f else { return }
            floatShown = f
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { if floatShown == f { floatShown = nil } }
        }
        .onChange(of: store.levelUp) { e in
            guard let e else { return }
            levelUpShown = e
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                levelUpShown = nil
                if store.stats.packs > 0 { packFromLevelUp = true; store.packStageOpen = true }
            }
        }
        .onChange(of: cloud.greeting) { g in
            guard let g else { return }
            cloud.greeting = nil
            switch g {
            case .welcome: showWelcome = true
            case .back:
                let name = store.state.heroName.isEmpty ? store.l.t("hero.noName") : store.state.heroName
                backToast = store.l.t("cloud.back.title", ["n": name])
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { backToast = nil }
            }
        }
    }

    // MARK: Layouts

    private var header: some View {
        HStack(spacing: 16) {
            LayeredText(text: "HIRELOOT")
            Spacer(minLength: 8)
            gear
        }
    }

    private var gear: some View {
        Button { ui.showSettings = true } label: { PixelIcon(name: "gear", px: 3) }
            .buttonStyle(.pixel(Theme.tab, compact: true))
            .accessibilityLabel(store.l.t("settings"))
    }

    private var wideLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                LayeredText(text: "HIRELOOT")
                Spacer()
                HStack(spacing: 8) { ForEach(AppTab.allCases) { tabButton($0) } }
                gear
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 18)
            .frame(maxWidth: 1200)
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    HeroPanel().frame(width: 320)
                    content.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24).padding(.bottom, 30).padding(.top, 4)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 18) {
                    if ui.tab == .today { HeroPanel() } else { HeroStrip() }
                    content
                }
                .padding(.horizontal, 16).padding(.bottom, 24).padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            HStack(spacing: 6) { ForEach(AppTab.allCases) { tabButton($0, stacked: true) } }
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)
                .background(Theme.edge.opacity(0.9).ignoresSafeArea(edges: .bottom))
        }
    }

    @ViewBuilder private var content: some View {
        switch ui.tab {
        case .today: TodayView()
        case .boss: BossView()
        case .armory: ArmoryView()
        case .log: LogView()
        }
    }

    private func tabButton(_ t: AppTab, stacked: Bool = false) -> some View {
        let active = ui.tab == t
        return Button { ui.tab = t; Sfx.shared.click() } label: {
            Group {
                if stacked {
                    VStack(spacing: 4) { PixelIcon(name: t.icon); Text(store.l.t(t.titleKey)).lineLimit(1).minimumScaleFactor(0.6) }
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 6) { PixelIcon(name: t.icon); Text(store.l.t(t.titleKey)) }
                }
            }
        }
        .buttonStyle(.pixel(active ? Theme.gold : Theme.tab, fg: active ? Theme.edge : Theme.muted, size: stacked ? Theme.s : Theme.m, compact: stacked))
    }

    // MARK: Overlays

    @ViewBuilder private var overlays: some View {
        if let f = floatShown {
            FloatTextView(event: f).id(f.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        if let e = levelUpShown { LevelUpBanner(event: e, l: store.l).id(e.id) }
        if let t = backToast {
            VStack {
                WelcomeBackToast(title: t, sub: "Lv.\(store.stats.lv) · \(store.l.titleName(store.stats.lv))")
                    .padding(.top, 60)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
        }
        if let w = ui.viewing { CardViewer(weapon: w) { ui.viewing = nil } }
        if store.packStageOpen {
            PackStage(fromLevelUp: packFromLevelUp) { store.packStageOpen = false; packFromLevelUp = false }
        }
        if ui.showSettings { SettingsView { ui.showSettings = false } }
        if cloud.showAuth && cloud.conflict == nil { AuthView() }
        if let c = cloud.conflict { ConflictView(conflict: c) }
        if showWelcome { WelcomeView { showWelcome = false } }
        if let d = ui.dialog { PixelDialog(req: d) { ui.dialog = nil } }
    }
}
