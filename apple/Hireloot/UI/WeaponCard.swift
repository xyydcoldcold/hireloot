import SwiftUI

/// A weapon card, ported 1:1 from `.card` in style.css and `cardHtml()` in armory.js:
/// 5:7 frame, rarity ring, radial art box with stepped rays, holo foil (rainbow for SR/SSR,
/// a white sheen for R), pointer glare, and SSR sparkles. All motion uses hard steps.
struct WeaponCard: View {
    let weapon: Weapon
    var count = 0
    var locked = false
    var mini = false
    var faceUp = true
    var equipped = false
    /// Pointer position over the card, 0...1 (`--mx` / `--my`); nil when the pointer is not on it.
    var pointer: CGPoint? = nil
    /// Fixed width; nil fills the width offered (armory grid).
    var width: CGFloat? = nil
    /// Glow around SR / SSR in the pack stage (`.slot.r-SR .card.flipped`).
    var glow = false
    let lang: String

    var body: some View {
        Color.clear
            .aspectRatio(5.0 / 7.0, contentMode: .fit)
            .frame(width: width)
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        if faceUp {
                            CardFront(weapon: weapon, count: count, locked: locked, mini: mini, equipped: equipped,
                                      pointer: pointer, size: size, lang: lang)
                        } else {
                            CardBack()
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .shadow(color: glowColor.opacity(0.6), radius: 9)
            .shadow(color: glowColor, radius: 4)
    }

    private var glowColor: Color {
        glow && faceUp && !locked && Weapons.isHigh(weapon.rarity) ? Color(hex: Weapons.rarity(weapon.rarity).color) : .clear
    }
}

// MARK: - Back

/// `.card-back`: 45° stripes over a blue gradient, cream / edge / blue inner rings.
struct CardBack: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#2a3070"), Color(hex: "#12153a")], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // repeating-linear-gradient(45deg, white .06 0 6px, transparent 6px 12px)
                let diag = size.width + size.height
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.rotate(by: .degrees(-45))
                var s = -diag
                while s < diag {
                    ctx.fill(Path(CGRect(x: s, y: -diag, width: 6, height: diag * 2)), with: .color(.white.opacity(0.06)))
                    s += 12
                }
            }
            Rings(rings: [(Theme.frame, 3), (Theme.edge, 4), (Color(hex: "#3a4190"), 3)])
            VStack(spacing: 10) {
                PixelIcon(name: "pack", px: 4)
                Text("HIRELOOT").font(Theme.font(Theme.s)).tracking(2).foregroundStyle(Theme.gold)
                    .shadow(color: Theme.edge, radius: 0, x: 2, y: 2)
            }
        }
        .padding(4)
        .background(Theme.edge)
    }
}

/// Stacked inset rings (`box-shadow: inset 0 0 0 Npx color, …`), outermost first.
struct Rings: View {
    let rings: [(Color, CGFloat)]
    var body: some View {
        ZStack {
            ForEach(rings.indices, id: \.self) { i in
                let inset = rings[..<i].reduce(0) { $0 + $1.1 }
                Rectangle().inset(by: inset).strokeBorder(rings[i].0, lineWidth: rings[i].1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Front

struct CardFront: View {
    let weapon: Weapon
    let count: Int
    let locked: Bool
    let mini: Bool
    let equipped: Bool
    let pointer: CGPoint?
    let size: CGSize
    let lang: String

    private var l: L10n { L10n(lang: lang) }
    private var rc: Color { Color(hex: Weapons.rarity(weapon.rarity).color) }
    private var r: String { weapon.rarity }
    /// `@container (max-width: 170px)`
    private var narrow: Bool { mini || size.width <= 170 }

    var body: some View {
        let inner = CGSize(width: size.width - 8, height: size.height - 8)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: "#2a3070"), Color(hex: "#171b48")], startPoint: .top, endPoint: .bottom)
            Rings(rings: ringColors)
            content
                .padding(.top, narrow ? 8 : 10).padding(.horizontal, narrow ? 8 : 10).padding(.bottom, narrow ? 6 : 8)
                .frame(width: inner.width, height: inner.height)
            if equipped && mini && !locked {
                Text(l.t("armory.equipped")).font(Theme.font(Theme.s)).foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .background(Theme.greenDk)
                    .padding(2).background(Theme.edge)
                    .offset(x: -2, y: 30)
            }
            if !locked {
                Holo(rarity: r, mini: mini, pointer: pointer)
                if pointer != nil { Glare(at: pointer!) }
                if r == "SSR" { Sparkles() }
            }
        }
        .frame(width: inner.width, height: inner.height)
        .compositingGroup()
        .clipped()
        .padding(4)
        .background(Theme.edge)
    }

    private var ringColors: [(Color, CGFloat)] {
        if locked { return [(rc.mix(Color(hex: "#12153a"), 0.45), 3), (Theme.edge, 3)] }
        if r == "SSR" { return [(Theme.gold, 3), (Theme.goldDk, 2), (Theme.edge, 3)] }
        return [(rc, 3), (Theme.edge, 3)]
    }

    private var content: some View {
        let n = max(1, count)
        return VStack(spacing: 0) {
            // .card-top
            HStack(alignment: .center) {
                Text(r).font(Theme.font(Theme.s)).foregroundStyle(Theme.edge)
                    .padding(.horizontal, 6).frame(height: 18)
                    .background(rc)
                    .padding(2).background(Theme.edge)
                    .fixedSize()
                Spacer(minLength: 0)
                Text(locked ? "???" : l.t("card.atk", ["n": Weapons.atk(of: weapon.id, count: n)]))
                    .font(Theme.font(Theme.s)).foregroundStyle(Theme.ink)
                    .shadow(color: Theme.edge, radius: 0, x: 2, y: 2)
                    .fixedSize()
            }
            .padding(.horizontal, 2).padding(.top, 2).padding(.bottom, 4)

            CardArt(weapon: weapon, locked: locked, mini: mini)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            name.padding(.top, 6).padding(.horizontal, -2)

            Group {
                if locked {
                    Text(l.t("rarity." + r)).foregroundStyle(rc)
                } else {
                    HStack(spacing: 1) {
                        ForEach(0..<Weapons.maxStars, id: \.self) { i in
                            Text("★").foregroundStyle(i < n ? Theme.gold : Color(hex: "#3a3f7a"))
                                .shadow(color: i < n ? Theme.edge : .clear, radius: 0, x: 1, y: 1)
                        }
                    }
                }
            }
            .font(Theme.font(Theme.s))
            .frame(height: 18)
            .padding(.top, 4)

            if !narrow {
                Text(locked ? l.t("armory.lockedDesc") : weapon.desc(lang))
                    .font(Theme.font(Theme.s)).foregroundStyle(Theme.muted)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder private var name: some View {
        let text = locked ? l.t("armory.locked") : weapon.name(lang)
        let long = !locked && text.reduce(0) { $0 + (($1.unicodeScalars.first?.value ?? 0) > 255 ? 2 : 1) } > 16
        let ssr = r == "SSR" && !locked
        let fg = locked ? Theme.muted : ssr ? Theme.edge : Theme.ink
        Group {
            if mini {
                Text(text).font(Theme.font(Theme.s)).lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 36)
            } else {
                Text(text).font(Theme.font(narrow || long ? Theme.s : Theme.m))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 23)
            }
        }
        .tracking(locked ? 3 : 0)
        .foregroundStyle(fg)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(ssr ? Theme.gold : Theme.edge)
        .overlay {
            if ssr {
                VStack(spacing: 0) {
                    Color(hex: "#ffe79a").frame(height: 3)
                    Spacer(minLength: 0)
                    Theme.goldDk.frame(height: 3)
                }
            }
        }
    }
}

// MARK: - Art box

/// `.card-art`: radial bands, stepped rays behind, the weapon sprite at 86% (80% mini) height with a hard drop shadow.
struct CardArt: View {
    let weapon: Weapon
    let locked: Bool
    let mini: Bool

    var body: some View {
        let rc = Color(hex: Weapons.rarity(weapon.rarity).color)
        let grid = HeroArt.weapon(weapon, locked: locked)
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let radius = (w * w + h * h).squareRoot() / 2
            ZStack {
                RadialGradient(stops: locked
                               ? [.init(color: Color(hex: "#232858"), location: 0), .init(color: Color(hex: "#232858"), location: 0.4),
                                  .init(color: Color(hex: "#161a42"), location: 0.4), .init(color: Color(hex: "#161a42"), location: 1)]
                               : [.init(color: Color(hex: "#3a4190"), location: 0), .init(color: Color(hex: "#3a4190"), location: 0.3),
                                  .init(color: Color(hex: "#1f2358"), location: 0.3), .init(color: Color(hex: "#1f2358"), location: 0.55),
                                  .init(color: Color(hex: "#12153a"), location: 0.55), .init(color: Color(hex: "#12153a"), location: 1)],
                               center: .center, startRadius: 0, endRadius: radius)
                if !locked { Rays(color: rc, spin: weapon.rarity != "N").opacity(weapon.rarity == "N" ? 0.25 : 0.7) }
                Canvas { ctx, size in
                    let px = size.height * (mini ? 0.8 : 0.86) / CGFloat(max(1, grid.height))
                    let sw = CGFloat(grid.width) * px, sh = CGFloat(grid.height) * px
                    let ox = (size.width - sw) / 2, oy = (size.height - sh) / 2
                    for c in grid.cells {
                        ctx.fill(Path(CGRect(x: ox + CGFloat(c.x) * px + 3, y: oy + CGFloat(c.y) * px + 3, width: px + 0.02, height: px + 0.02)),
                                 with: .color(.black.opacity(0.45)))
                    }
                    for c in grid.cells {
                        ctx.fill(Path(CGRect(x: ox + CGFloat(c.x) * px, y: oy + CGFloat(c.y) * px, width: px + 0.02, height: px + 0.02)),
                                 with: .color(c.color))
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .clipped()
        .padding(3)
        .background(Theme.edge)
    }
}

/// `repeating-conic-gradient(rc 35% 0 10deg, transparent 10deg 20deg)` turning in 24 steps per 8s.
struct Rays: View {
    let color: Color
    let spin: Bool
    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 1.0 / 3)) { tl in
            let step = spin ? floor(tl.date.timeIntervalSinceReferenceDate * 3).truncatingRemainder(dividingBy: 24) : 0
            Canvas { ctx, size in
                // inset: -40% → a box 1.8x the art box, centred
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = max(size.width, size.height) * 1.8
                let base = step * 15
                for k in 0..<18 {
                    let a0 = Angle.degrees(base + Double(k) * 20 - 90), a1 = Angle.degrees(base + Double(k) * 20 + 10 - 90)
                    var p = Path()
                    p.move(to: c)
                    p.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color.opacity(0.35)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Foil

/// `.holo`. SR / SSR: scanlined rainbow bands (115°, 6% each, 300% size) in color-dodge, panning in 16 steps
/// over 3.2s back and forth, or following the pointer. R: a white sheen sweeping in 20 steps over 3s (overlay).
struct Holo: View {
    let rarity: String
    let mini: Bool
    let pointer: CGPoint?

    private static let rainbow = ["#ff5f6d", "#ffc371", "#f9f871", "#5ef38c", "#47c6ff", "#8a7dff", "#ff6bd6"].map { Color(hex: $0) }

    var body: some View {
        switch rarity {
        case "SR", "SSR":
            TimelineView(.periodic(from: .distantPast, by: 0.2)) { tl in
                let pos = pointer ?? idle(tl.date)
                Canvas { ctx, size in rainbow(ctx, size, pos) }
            }
            .opacity(rarity == "SR" ? 0.32 : mini ? 0.35 : 0.45)
            .blendMode(.colorDodge)
            .allowsHitTesting(false)
        case "R":
            if pointer == nil {
                TimelineView(.periodic(from: .distantPast, by: 0.15)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3
                    let p = 1 - floor(t * 20) / 20
                    Canvas { ctx, size in sheen(ctx, size, p) }
                }
                .opacity(0.9)
                .blendMode(.overlay)
                .allowsHitTesting(false)
            }
        default:
            EmptyView()
        }
    }

    /// `holoIdle 3.2s steps(16) infinite alternate`: 0% 0% → 100% 100%.
    private func idle(_ d: Date) -> CGPoint {
        let t = d.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.4) / 3.2
        let f = t <= 1 ? t : 2 - t
        let s = min(1, floor(f * 16) / 16)
        return CGPoint(x: s, y: s)
    }

    /// One layer of a `repeating-linear-gradient(angle, …)` with hard stops, sized `bw x bh` and placed at (ox, oy).
    private func bands(_ ctx: GraphicsContext, angle: Double, box: CGRect, period: Double, stops: [(Double, Double, Color)]) {
        var g = ctx
        let a = angle * .pi / 180
        let len: CGFloat = abs(box.width * CGFloat(Foundation.sin(a))) + abs(box.height * CGFloat(Foundation.cos(a)))
        g.translateBy(x: box.midX, y: box.midY)
        g.rotate(by: .radians(a - .pi / 2))
        let big = box.width + box.height
        // gradient line runs from -len/2 to +len/2; repeat the pattern over the whole box
        let p = CGFloat(period) * len
        var start: CGFloat = -len / 2 - (big / p).rounded(.up) * p
        while start < big {
            for (from, to, color) in stops {
                let f = CGFloat(from), t = CGFloat(to)
                g.fill(Path(CGRect(x: start + f * len, y: -big, width: (t - f) * len, height: big * 2)), with: .color(color))
            }
            start += p
        }
    }

    private func rainbow(_ ctx: GraphicsContext, _ size: CGSize, _ pos: CGPoint) {
        let box = CGRect(x: -2 * size.width * pos.x, y: -2 * size.height * pos.y, width: size.width * 3, height: size.height * 3)
        let stops = Self.rainbow.enumerated().map { (Double($0.offset) * 0.06, Double($0.offset + 1) * 0.06, $0.element) }
        bands(ctx, angle: 115, box: box, period: 0.42, stops: stops)
        // scanlines: rgba(0,0,0,.35) 0 2px, transparent 2px 4px
        var y = size.height
        while y > 0 {
            ctx.fill(Path(CGRect(x: 0, y: y - 2, width: size.width, height: 2)), with: .color(.black.opacity(0.35)))
            y -= 4
        }
    }

    private func sheen(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double) {
        let box = CGRect(x: -2 * size.width * p, y: 0, width: size.width * 3, height: size.height)
        let w = Color.white
        // not repeating: one pass of the pattern
        var g = ctx
        let a = 110 * Double.pi / 180
        let len: CGFloat = abs(box.width * CGFloat(Foundation.sin(a))) + abs(box.height * CGFloat(Foundation.cos(a)))
        g.translateBy(x: box.midX, y: box.midY)
        g.rotate(by: .radians(a - .pi / 2))
        let big = box.width + box.height
        let bandsR: [(CGFloat, CGFloat, Double)] = [(0.40, 0.46, 0.55), (0.52, 0.55, 0.35)]
        for (from, to, o) in bandsR {
            g.fill(Path(CGRect(x: -len / 2 + from * len, y: -big, width: (to - from) * len, height: big * 2)), with: .color(w.opacity(o)))
        }
    }
}

/// `.glare`: hard-edged radial highlight at the pointer (overlay blend).
struct Glare: View {
    let at: CGPoint
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: at.x * size.width, y: at.y * size.height)
            let far = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                .map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 1
            let inner = Path(ellipseIn: CGRect(x: c.x - far * 0.12, y: c.y - far * 0.12, width: far * 0.24, height: far * 0.24))
            var ring = Path(ellipseIn: CGRect(x: c.x - far * 0.3, y: c.y - far * 0.3, width: far * 0.6, height: far * 0.6))
            ring.addPath(inner)
            ctx.fill(ring, with: .color(.white.opacity(0.25)), style: FillStyle(eoFill: true))
            ctx.fill(inner, with: .color(.white.opacity(0.75)))
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

/// `.sparkles`: five pixel plus-signs twinkling (`twinkle 1.6s steps(2)`, staggered).
struct Sparkles: View {
    private static let spots: [(CGFloat, CGFloat, Double)] = [(0.18, 0.22, 0), (0.78, 0.30, 0.4), (0.30, 0.58, 0.8), (0.70, 0.66, 1.2), (0.50, 0.12, 0.6)]
    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 0.2)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for (x, y, delay) in Self.spots {
                    // keyframes 0 → 1 → 0, each half in 2 steps: 0, .5, 1, .5
                    let ph = (now - delay).truncatingRemainder(dividingBy: 1.6)
                    let o = [0, 0.5, 1, 0.5][min(3, Int(ph / 0.4))]
                    guard o > 0 else { continue }
                    let px = (x * size.width).rounded(), py = (y * size.height).rounded()
                    for (dx, dy) in [(0, 0), (4, 0), (-4, 0), (0, 4), (0, -4)] as [(CGFloat, CGFloat)] {
                        ctx.fill(Path(CGRect(x: px + dx, y: py + dy, width: 4, height: 4)), with: .color(.white.opacity(o)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension Color {
    /// `color-mix(in srgb, self p, other)`.
    func mix(_ other: Color, _ p: Double) -> Color {
        #if os(macOS)
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black, b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        let ca = (a.redComponent, a.greenComponent, a.blueComponent), cb = (b.redComponent, b.greenComponent, b.blueComponent)
        #else
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0, br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(self).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(other).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let ca = (ar, ag, ab), cb = (br, bg, bb)
        #endif
        return Color(.sRGB, red: Double(ca.0) * p + Double(cb.0) * (1 - p), green: Double(ca.1) * p + Double(cb.1) * (1 - p),
                     blue: Double(ca.2) * p + Double(cb.2) * (1 - p), opacity: 1)
    }
}

// MARK: - Tilt

/// Tracks the pointer over a card: hover on Mac (and iPad pointer), drag when `drag` is set (the viewer).
/// Rotates like `bindTilt()`: rx = (0.5 - y) * 18°, ry = (x - 0.5) * 22°.
struct TiltCard: View {
    let weapon: Weapon
    var count = 0
    var locked = false
    var mini = false
    var equipped = false
    var width: CGFloat? = nil
    var drag = false
    let lang: String
    @State private var pointer: CGPoint?
    @State private var size: CGSize = .zero

    var body: some View {
        let p = locked ? nil : pointer
        WeaponCard(weapon: weapon, count: count, locked: locked, mini: mini, equipped: equipped, pointer: p, width: width, lang: lang)
            .background(GeometryReader { g in Color.clear.onAppear { size = g.size }.onChange(of: g.size) { size = $0 } })
            .rotation3DEffect(.degrees(Double(0.5 - (p?.y ?? 0.5)) * 18), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double((p?.x ?? 0.5) - 0.5) * 22), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc): pointer = norm(loc)
                case .ended: pointer = nil
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { pointer = norm($0.location) }
                .onEnded { _ in pointer = nil }, including: drag ? .all : .subviews)
    }

    private func norm(_ loc: CGPoint) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: min(1, max(0, loc.x / size.width)), y: min(1, max(0, loc.y / size.height)))
    }
}

/// Big card + equip button, opened from the armory grid.
struct CardViewer: View {
    @EnvironmentObject var store: GameStore
    let weapon: Weapon
    let close: () -> Void

    var body: some View {
        let l = store.l
        let count = store.count(weapon)
        let equipped = store.state.armory.equipped == weapon.id
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 18) {
                TiltCard(weapon: weapon, count: count, locked: count == 0, width: 280, drag: true, lang: store.lang)
                HStack(spacing: 12) {
                    if count > 0 {
                        Button(l.t(equipped ? "armory.unequip" : "armory.equip")) { store.equip(equipped ? nil : weapon.id) }
                            .buttonStyle(equipped ? PixelButtonStyle.pixel : PixelButtonStyle.pixelPrimary)
                            .frame(minWidth: 120)
                    }
                    Button(l.t("settings.close"), action: close).buttonStyle(.pixel).frame(minWidth: 120)
                }
            }
        }
    }
}
