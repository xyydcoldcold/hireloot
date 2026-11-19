import SwiftUI

/// A weapon card. SR / SSR cards get a holographic foil that follows the tilt.
struct WeaponCard: View {
    let weapon: Weapon
    var count = 0
    var locked = false
    var mini = false
    var faceUp = true
    var equipped = false
    var tilt: CGPoint = .zero   // -0.5...0.5
    let lang: String

    private var l: L10n { L10n(lang: lang) }
    private var rc: Color { Color(hex: Weapons.rarity(weapon.rarity).color) }
    var size: CGSize { mini ? CGSize(width: 132, height: 188) : CGSize(width: 236, height: 336) }

    var body: some View {
        ZStack {
            if faceUp { front } else { back }
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.edge)
        .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
        .overlay(Rectangle().inset(by: 3).strokeBorder(locked ? Color(hex: "#3a3f6e") : rc, lineWidth: mini ? 3 : 4))
        .shadow(color: !locked && Weapons.isHigh(weapon.rarity) && faceUp ? rc.opacity(0.6) : .clear, radius: mini ? 6 : 14)
    }

    private var back: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#4a2a9a"), Color(hex: "#20124a")], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                PixelIcon(name: "pack", px: mini ? 4 : 6)
                Text("HIRELOOT").pixelText(mini ? Theme.s : Theme.m, Theme.gold)
            }
        }
        .padding(7)
    }

    private var front: some View {
        let count = max(1, self.count)
        return VStack(spacing: mini ? 4 : 8) {
            HStack {
                Text(weapon.rarity).font(Theme.font(Theme.s)).foregroundStyle(locked ? Theme.muted : Theme.edge)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(locked ? Color(hex: "#2a2f5e") : rc)
                Spacer()
                Text(locked ? "???" : l.t("card.atk", ["n": Weapons.atk(of: weapon.id, count: count)]))
                    .font(Theme.font(Theme.s)).foregroundStyle(locked ? Theme.muted : Theme.gold)
            }
            ZStack {
                LinearGradient(colors: [Color(hex: "#14183e"), Color(hex: "#262c6a")], startPoint: .top, endPoint: .bottom)
                if !locked {
                    RadialGradient(colors: [rc.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: mini ? 60 : 110)
                }
                PixelSprite(grid: HeroArt.weapon(weapon, locked: locked), px: mini ? 3 : 5)
                    .scaleEffect(mini ? 0.85 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: mini ? 92 : 150)
            .clipped()
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
            Text(locked ? l.t("armory.locked") : weapon.name(lang))
                .pixelText(mini ? Theme.s : Theme.m, locked ? Theme.muted : Theme.ink)
                .lineLimit(mini ? 2 : 1).minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if locked {
                Text(l.t("rarity." + weapon.rarity)).font(Theme.font(Theme.s)).foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 1) {
                    ForEach(0..<Weapons.maxStars, id: \.self) { i in
                        Text("★").font(Theme.font(Theme.s)).foregroundStyle(i < count ? Theme.gold : Color(hex: "#3a3f6e"))
                    }
                }
            }
            if !mini {
                Text(locked ? l.t("armory.lockedDesc") : weapon.desc(lang))
                    .pixelText(Theme.s, Theme.muted, shadow: false)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(mini ? 9 : 14)
        .background(LinearGradient(colors: [Color(hex: "#2a3070"), Color(hex: "#1a1d4e")], startPoint: .top, endPoint: .bottom))
        .overlay { if !locked && Weapons.isHigh(weapon.rarity) { holo } }
        .overlay(alignment: .bottom) {
            if equipped && mini {
                Text(l.t("armory.equipped")).font(Theme.font(Theme.s)).foregroundStyle(Theme.edge)
                    .padding(.horizontal, 6).background(Theme.green).padding(.bottom, 6)
            }
        }
        .padding(7)
    }

    /// Rainbow foil + glare, shifted by the tilt (pokemon-cards-css style, with hard color stops).
    private var holo: some View {
        let ssr = weapon.rarity == "SSR"
        let colors: [Color] = ssr
            ? [Color(hex: "#ff6b9a"), Color(hex: "#ffcf4a"), Color(hex: "#5fd35f"), Color(hex: "#7fdbff"), Color(hex: "#c77dff"), Color(hex: "#ff6b9a")]
            : [Color(hex: "#c77dff"), Color(hex: "#7fdbff"), Color(hex: "#f3d9ff"), Color(hex: "#c77dff")]
        return ZStack {
            LinearGradient(colors: colors, startPoint: UnitPoint(x: 0 + tilt.x, y: 0 + tilt.y), endPoint: UnitPoint(x: 1 + tilt.x, y: 1 + tilt.y))
                .opacity(ssr ? 0.32 : 0.24)
                .blendMode(.colorDodge)
            // scanlines keep it pixel-y
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.18))); y += 3 }
            }
            RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.5 + tilt.x * 1.4, y: 0.5 + tilt.y * 1.4),
                           startRadius: 0, endRadius: mini ? 80 : 150)
                .blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }
}

/// Big card + equip button, opened from the armory grid.
struct CardViewer: View {
    @EnvironmentObject var store: GameStore
    let weapon: Weapon
    let close: () -> Void
    @State private var tilt: CGPoint = .zero

    var body: some View {
        let l = store.l
        let count = store.count(weapon)
        let equipped = store.state.armory.equipped == weapon.id
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 20) {
                WeaponCard(weapon: weapon, count: count, locked: count == 0, tilt: tilt, lang: store.lang)
                    .rotation3DEffect(.degrees(Double(-tilt.y) * 18), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(Double(tilt.x) * 22), axis: (x: 0, y: 1, z: 0))
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            tilt = CGPoint(x: max(-0.5, min(0.5, v.location.x / 236 - 0.5)), y: max(-0.5, min(0.5, v.location.y / 336 - 0.5)))
                        }
                        .onEnded { _ in withAnimation(.spring()) { tilt = .zero } })
                HStack(spacing: 12) {
                    if count > 0 {
                        Button(l.t(equipped ? "armory.unequip" : "armory.equip")) { store.equip(equipped ? nil : weapon.id) }
                            .buttonStyle(equipped ? PixelButtonStyle.pixel : PixelButtonStyle.pixelPrimary)
                    }
                    Button(l.t("settings.close"), action: close).buttonStyle(.pixel)
                }
            }
        }
    }
}
