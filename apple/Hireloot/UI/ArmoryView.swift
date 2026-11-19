import SwiftUI

struct ArmoryView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState

    var body: some View {
        let l = store.l
        let st = store.stats
        let a = store.state.armory
        let owned = Weapons.all.filter { (a.owned[$0.id] ?? 0) > 0 }.count
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    PanelTitle(text: l.t("armory.title"))
                    Spacer()
                    Pill(text: l.t("armory.count", ["n": owned, "total": Weapons.all.count]))
                }
                HStack(spacing: 16) {
                    HStack(spacing: -14) {
                        if st.packs > 0 {
                            ForEach(0..<min(st.packs, 6), id: \.self) { _ in PixelIcon(name: "pack", px: 4) }
                        } else {
                            PixelIcon(name: "pack", px: 4).saturation(0).opacity(0.4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(st.packs > 0 ? l.t("armory.packs", ["n": st.packs]) : l.t("armory.noPacks", ["n": st.need - st.cur]))
                            .pixelText(Theme.m).fixedSize(horizontal: false, vertical: true)
                        if st.packs > 0 {
                            Button(l.t("pack.btn", ["n": min(3, st.packs)])) { store.packStageOpen = true }.buttonStyle(.pixelPrimary)
                        }
                    }
                }
                Text(l.t("armory.pity", ["n": Weapons.pity - a.pity])).pixelText(Theme.s, Theme.muted, shadow: false)
            }
            .pixelWindow()

            ForEach(Weapons.rarityOrder, id: \.self) { r in
                let list = Weapons.all.filter { $0.rarity == r }
                let got = list.filter { (a.owned[$0.id] ?? 0) > 0 }.count
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        PanelTitle(text: l.t("rarity." + r))
                        Text(r).font(Theme.font(Theme.s)).foregroundStyle(Theme.edge).padding(.horizontal, 6)
                            .background(Color(hex: Weapons.rarity(r).color))
                        Spacer()
                        Pill(text: "\(got) / \(list.count)")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132, maximum: 150), spacing: 12)], spacing: 12) {
                        ForEach(list) { w in
                            let n = a.owned[w.id] ?? 0
                            Button { ui.viewing = w } label: {
                                WeaponCard(weapon: w, count: n, locked: n == 0, mini: true, equipped: a.equipped == w.id, lang: store.lang)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(n > 0 ? w.name(store.lang) : l.t("armory.locked"))
                        }
                    }
                }
                .pixelWindow()
            }
        }
    }
}

// MARK: - Pack opening

/// Charge → tear → flip → celebrate, like the web version. Drag across the top of a pack to tear it, or tap.
struct PackStage: View {
    @EnvironmentObject var store: GameStore
    let fromLevelUp: Bool
    let close: () -> Void

    enum SlotState { case sealed, tearing, busy, open }
    struct Slot: Identifiable {
        let id = UUID()
        var state: SlotState = .sealed
        var pull: PullResult?
        var progress: Double = 0
        var charging = false
        var faceUp = false
        var squash: CGFloat = 1
        var burst = 0
        var badge: String?
    }

    @State private var slots: [Slot] = []
    @State private var flash: Color?
    @State private var banner: (String, String)?
    @State private var quake = false
    @State private var dragBase: [Int: Double] = [:]

    var body: some View {
        let l = store.l
        let sealed = slots.filter { $0.state == .sealed || $0.state == .tearing }.count
        let busy = slots.contains { $0.state == .busy }
        let untouched = slots.allSatisfy { $0.state == .sealed }
        let done = !slots.isEmpty && sealed == 0 && !busy
        let left = store.stats.packs

        ZStack {
            Color(hex: "#05040f").opacity(0.92).ignoresSafeArea()
            if let flash { flash.opacity(0.35).ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    if fromLevelUp { Text(l.t("pack.titleLv")).pixelText(Theme.m, Theme.gold) }
                    Text(l.t("pack.title", ["n": slots.count])).pixelText(Theme.l)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(slots.indices, id: \.self) { i in slotView(i).frame(width: 236, height: 360) }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .frame(minWidth: 0)
                }
                .frame(height: 384)
                .modifier(Shake(amount: quake ? 8 : 0))
                Text(l.t("pack.hint")).pixelText(Theme.s, Theme.muted, shadow: false).opacity(done ? 0 : 1)
                HStack(spacing: 12) {
                    if done {
                        if left > 0 { Button(l.t("pack.more", ["n": min(3, left)])) { setup() }.buttonStyle(.pixel) }
                        Button(l.t("pack.done"), action: close).buttonStyle(.pixelPrimary)
                    } else {
                        if untouched { Button(l.t("pack.later"), action: close).buttonStyle(.pixel) }
                        Button(l.t("pack.all")) { tearAll() }.buttonStyle(.pixelPrimary).disabled(busy && sealed == 0)
                    }
                }
            }
            if let banner {
                Text(banner.0)
                    .font(Theme.font(Theme.xl))
                    .foregroundStyle(Color(hex: Weapons.rarity(banner.1).color))
                    .shadow(color: Theme.edge, radius: 0, x: 4, y: 4)
                    .padding(.horizontal, 30).padding(.vertical, 12)
                    .background(Theme.edge.opacity(0.85))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            setup()
            if UserDefaults.standard.bool(forKey: "HLAutoTear") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { tearAll() }
            }
        }
    }

    private func setup() {
        let n = min(3, store.stats.packs)
        if n == 0 { close(); return }
        slots = (0..<n).map { _ in Slot() }
        Sfx.shared.click()
    }

    @ViewBuilder private func slotView(_ i: Int) -> some View {
        let s = slots[i]
        let rc = s.pull.map { Color(hex: Weapons.rarity($0.weapon.rarity).color) } ?? Color(hex: "#c77dff")
        ZStack {
            if s.state == .sealed || s.state == .tearing {
                PackView(progress: s.progress, glow: s.pull == nil ? nil : rc)
                    .contentShape(Rectangle())
                    .onTapGesture { autoTear(i) }
                    .gesture(DragGesture(minimumDistance: 6)
                        .onChanged { v in drag(i, dx: v.translation.width) }
                        .onEnded { _ in endDrag(i) })
            }
            if let p = s.pull, s.state == .busy || s.state == .open {
                if s.charging { Rectangle().fill(rc.opacity(0.35)).blur(radius: 30).frame(width: 200, height: 300) }
                WeaponCard(weapon: p.weapon, count: p.count, faceUp: s.faceUp, lang: store.lang)
                    .scaleEffect(x: s.squash, y: 1)
                    .modifier(Shake(amount: s.charging ? (Weapons.isHigh(p.weapon.rarity) ? 4 : 2) : 0))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                BurstView(key: s.burst, rarity: p.weapon.rarity)
                if let b = s.badge {
                    Text(b).font(Theme.font(Theme.m)).foregroundStyle(Theme.edge)
                        .padding(.horizontal, 10).padding(.vertical, 2)
                        .background(b == store.l.t("pack.new") ? Theme.gold : b == store.l.t("pack.maxed") ? Theme.muted : Theme.green)
                        .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
                        .rotationEffect(.degrees(-8))
                        .offset(x: 80, y: -160)
                        .transition(.scale)
                }
            }
        }
    }

    // MARK: Tearing
    private func arm(_ i: Int) -> Bool {
        guard i < slots.count, slots[i].state == .sealed || slots[i].state == .tearing else { return false }
        if slots[i].pull == nil { slots[i].pull = store.pull() }
        slots[i].state = .tearing
        return true
    }

    private func setProgress(_ i: Int, _ p: Double) {
        let p = (min(1, p) * 25).rounded() / 25   // pixel steps
        if Int(p * 10) > Int(slots[i].progress * 10) { Sfx.shared.rip(p) }
        slots[i].progress = p
    }

    private func drag(_ i: Int, dx: CGFloat) {
        guard arm(i) else { return }
        if dragBase[i] == nil { dragBase[i] = slots[i].progress }
        let p = max(dragBase[i]!, min(1, dragBase[i]! + Double(dx) / (236 * 0.9)))
        setProgress(i, p)
        if p >= 0.82 { dragBase[i] = nil; finish(i) }
    }
    private func endDrag(_ i: Int) {
        dragBase[i] = nil
        guard i < slots.count, slots[i].state == .tearing, slots[i].progress < 0.82 else { return }
        withAnimation(.easeOut(duration: 0.2)) { slots[i].progress = min(slots[i].progress, 0.15) }
    }

    private func autoTear(_ i: Int) {
        guard arm(i) else { return }
        Task { @MainActor in
            while i < slots.count, slots[i].state == .tearing, slots[i].progress < 1 {
                setProgress(i, slots[i].progress + 0.1)
                try? await Task.sleep(nanoseconds: 32_000_000)
            }
            finish(i)
        }
    }

    private func tearAll() {
        Task { @MainActor in
            for i in slots.indices where slots[i].state == .sealed || slots[i].state == .tearing {
                autoTear(i)
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }
    }

    private func finish(_ i: Int) {
        guard i < slots.count, slots[i].state == .tearing, let p = slots[i].pull else { return }
        let r = p.weapon.rarity
        Task { @MainActor in
            // 1. tear: the top flies off
            Sfx.shared.tear()
            withAnimation(.easeOut(duration: 0.25)) { slots[i].state = .busy; slots[i].charging = true }
            try? await Task.sleep(nanoseconds: 240_000_000)
            // 2. the card rises face down and charges up (longer for rarer cards)
            let charge = ["N": 0.38, "R": 0.6, "SR": 1.0, "SSR": 1.5][r] ?? 0.4
            let ticks = Int((charge / 0.11).rounded())
            for k in 0..<ticks {
                Sfx.shared.tick(Weapons.isHigh(r) ? Double(k) * 1.4 : Double(k))
                if r == "SSR" { quake = k % 2 == 0 }
                try? await Task.sleep(nanoseconds: 110_000_000)
            }
            quake = false
            // 3. flip
            withAnimation(.easeIn(duration: 0.12)) { slots[i].squash = 0.02 }
            try? await Task.sleep(nanoseconds: 120_000_000)
            slots[i].faceUp = true
            slots[i].charging = false
            withAnimation(.easeOut(duration: 0.16)) { slots[i].squash = 1 }
            // 4. celebrate
            Sfx.shared.reveal(r)
            slots[i].burst += 1
            if r != "N" {
                withAnimation(.easeOut(duration: 0.1)) { flash = Color(hex: Weapons.rarity(r).color) }
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) { flash = nil }
            }
            if Weapons.isHigh(r) {
                for k in 0..<4 { quake = k % 2 == 0; try? await Task.sleep(nanoseconds: 60_000_000) }
                quake = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    banner = (store.l.t(r == "SSR" ? "pack.ssr" : "pack.sr"), r)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    withAnimation { banner = nil }
                }
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                slots[i].badge = p.isNew ? store.l.t("pack.new") : p.starUp ? store.l.t("pack.starUp") : store.l.t("pack.maxed")
            }
            if p.starUp { Sfx.shared.star() }
            slots[i].state = .open
        }
    }
}

/// The sealed foil pack. `progress` 0...1 is how far the top strip has been torn.
struct PackView: View {
    let progress: Double
    let glow: Color?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                // body
                VStack(spacing: 12) {
                    Text("HIRELOOT").pixelText(Theme.l, Theme.gold)
                    PixelIcon(name: "chest", px: 6)
                    Text("WEAPON PACK").pixelText(Theme.s, Color(hex: "#f3d9ff"))
                }
                .frame(width: w, height: h - 40)
                .background(
                    LinearGradient(colors: [Color(hex: "#9a4fd8"), Color(hex: "#4a2a9a"), Color(hex: "#2a1660")], startPoint: .top, endPoint: .bottom)
                )
                .overlay(alignment: .bottom) { Crimp().frame(height: 10) }
                .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 4))
                .offset(y: 40)
                // light leaking through the tear
                if let glow, progress > 0 {
                    Rectangle().fill(glow).frame(width: w * progress, height: 6).blur(radius: 6)
                        .frame(maxWidth: .infinity, alignment: .leading).offset(y: 37)
                }
                // top strip: the torn part lifts away, the rest stays attached
                ZStack(alignment: .leading) {
                    stripe.frame(width: w * (1 - progress)).frame(maxWidth: .infinity, alignment: .trailing)
                    stripe.frame(width: w * progress)
                        .rotationEffect(.degrees(-progress * 22), anchor: .bottomTrailing)
                        .offset(y: -progress * 14)
                        .opacity(1 - progress * 0.6)
                }
                .frame(height: 40)
                if progress == 0 {
                    Text("✂ - - - - - - - -").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold.opacity(0.8)).offset(y: 44)
                }
            }
        }
        .frame(width: 210, height: 320)
        .shadow(color: (glow ?? .clear).opacity(0.6), radius: 18)
    }

    private var stripe: some View {
        Rectangle().fill(Color(hex: "#c77dff"))
            .overlay(alignment: .top) { Crimp().frame(height: 10) }
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 4))
    }
}

private struct Crimp: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 4, height: size.height)), with: .color(.white.opacity(0.25)))
                x += 8
            }
        }
    }
}

/// Pixel confetti flying out of the card.
struct BurstView: View {
    let key: Int
    let rarity: String
    var body: some View {
        if key > 0 { Burst(rarity: rarity).id(key) }
    }
    private struct Burst: View {
        let rarity: String
        @State private var go = false
        var body: some View {
            let n = ["N": 10, "R": 16, "SR": 26, "SSR": 40][rarity] ?? 10
            let rc = Color(hex: Weapons.rarity(rarity).color)
            let colors: [Color] = rarity == "SSR"
                ? ["#ffcf4a", "#ff6b9a", "#7fdbff", "#5fd35f", "#fff4c2"].map { Color(hex: $0) }
                : [rc, .white, Color(hex: "#fff4c2")]
            ZStack {
                ForEach(0..<n, id: \.self) { k in
                    let a = Double(k) / Double(n) * .pi * 2
                    let d = 90.0 + Double((k * 37) % 90) * (Weapons.isHigh(rarity) ? 1.8 : 1)
                    Rectangle().fill(colors[k % colors.count]).frame(width: 8, height: 8)
                        .offset(x: go ? cos(a) * d : 0, y: go ? sin(a) * d : 0)
                        .opacity(go ? 0 : 1)
                }
            }
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
        }
    }
}

struct Shake: ViewModifier {
    var amount: CGFloat
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: amount == 0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 40
            content.offset(x: amount == 0 ? 0 : CGFloat(sin(t)) * amount,
                           y: amount == 0 ? 0 : CGFloat(cos(t * 1.3)) * amount * 0.5)
        }
    }
}
