import SwiftUI

struct HeroPanel: View {
    @EnvironmentObject var store: GameStore
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var nameFocus: Bool

    var body: some View {
        let st = store.stats
        let l = store.l
        VStack(alignment: .leading, spacing: 0) {
            nameRow(l)
                .padding(.bottom, 12)
            HStack(alignment: .center, spacing: 16) {
                HeroPortrait(stats: st)
                // `.lv-box`: fills the space beside the portrait, centered
                VStack(alignment: .center, spacing: 6) {
                    Text("LEVEL").font(Theme.font(Theme.s)).tracking(3).foregroundStyle(Theme.muted)
                    // shadows hang to the right without taking space, like CSS text-shadow
                    LayeredText(text: "\(st.lv)", layers: [(Theme.edge, 5), (Theme.goldDk, 3)])
                        .padding(.leading, 5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 14)
            TitleRibbon(text: l.titleName(st.lv))
                .padding(.bottom, 18)
            HStack {
                Text("EXP"); Spacer(); Text("\(st.cur) / \(st.need)")
            }
            .pixelText(Theme.s, Theme.muted, shadow: false)
            .padding(.bottom, 4)
            ExpBar(fraction: Double(st.cur) / Double(max(1, st.need)))
            statsGrid(st, l)
                .padding(.top, 16)
            equip(st, l)
            if st.packs > 0 {
                Button { store.packStageOpen = true } label: {
                    HStack(spacing: 10) { PixelIcon(name: "pack", px: 3); Text(l.t("pack.btn", ["n": st.packs])) }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixel(Color(hex: "#6a3aa8")))
                .padding(.top, 12)
            }
        }
        .pixelWindow(padding: 22)
    }

    @ViewBuilder private func nameRow(_ l: L10n) -> some View {
        let name = store.state.heroName
        if editing {
            PixelField(placeholder: l.t("hero.namePh"), text: $draft, maxLength: GameStore.nameMax) {
                store.setName(draft); editing = false
            }
            .focused($nameFocus)
            .onChange(of: nameFocus) { f in if !f && editing { store.setName(draft); editing = false } }
        } else {
            Button {
                draft = name
                editing = true
                DispatchQueue.main.async { nameFocus = true }
            } label: {
                HStack(spacing: 8) {
                    Text(name.isEmpty ? l.t("hero.noName") : name)
                        .pixelText(Theme.l, name.isEmpty ? Theme.muted : Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    PixelIcon(name: "pencil").opacity(0.55)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l.t("hero.rename"))
        }
    }

    private func statsGrid(_ st: Stats, _ l: L10n) -> some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            statCell("sword", l.t("stat.atk"), Color(hex: Rules.category("project").color), "\(st.atk)", bonus: st.wAtk)
            statCell("shield", l.t("stat.def"), Color(hex: Rules.category("resume").color), "\(st.def)")
            statCell("book", l.t("stat.int"), Color(hex: Rules.category("prep").color), "\(st.int)")
            statCell("heart", l.t("stat.cha"), Color(hex: Rules.category("network").color), "\(st.cha)")
            statCell("ally", l.t("stat.ally"), Theme.ink, "\(st.ally)")
            statCell("coin", l.t("stat.gold"), Theme.gold, "\(st.gold)")
        }
    }

    private func statCell(_ icon: String, _ label: String, _ color: Color, _ value: String, bonus: Int = 0) -> some View {
        HStack(spacing: 4) {
            PixelIcon(name: icon)
            Text(label).font(Theme.font(Theme.s)).foregroundStyle(color).lineLimit(1)
            Spacer(minLength: 2)
            Text(value).font(Theme.font(Theme.m)).foregroundStyle(Theme.ink)
            if bonus > 0 { Text("+\(bonus)").font(Theme.font(Theme.s)).foregroundStyle(Theme.green) }
        }
        .insetBox()
    }

    private func equip(_ st: Stats, _ l: L10n) -> some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            if let w = st.weapon {
                let rc = Color(hex: Weapons.rarity(w.rarity).color)
                info(l.t("hero.weapon"), w.name(store.lang), color: rc,
                     extra: String(repeating: "★", count: min(store.count(w), Weapons.maxStars)))
            } else {
                info(l.t("hero.weapon"), l.t("hero.noWeapon"))
            }
            info(l.t("hero.armor"), l.armorName(st.def))
            info(l.t("hero.boss"), l.t("hero.bossVal", ["w": st.wins, "n": st.bosses]))
            info(l.t("hero.bonus"), "+\(Rules.intBonus(st.int)) EXP")
        }
        .padding(.top, 8)
    }

    private func info(_ label: String, _ value: String, color: Color = Theme.ink, extra: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label).foregroundStyle(Theme.muted)
                if !extra.isEmpty { Text(extra).foregroundStyle(Theme.gold) }
            }
            Text(value).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(Theme.font(Theme.s))
        .insetBox()
    }
}

// Mirrors `.title` in style.css: a gold banner with notched ends
// (clip-path polygon, 14px notches), light/dark inset bands top and bottom,
// and a ✦ on each side of the text. Long titles drop to the small size
// (`.title.tight`) instead of wrapping.
struct TitleRibbon: View {
    let text: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            label(tight: false)
            label(tight: true)
        }
        .frame(maxWidth: .infinity)
        .background {
            VStack(spacing: 0) {
                Color(hex: "#ffe79a").frame(height: 3)
                Theme.gold
                Theme.goldDk.frame(height: 4)
            }
        }
        .clipShape(RibbonShape(notch: 14))
    }

    private func label(tight: Bool) -> some View {
        let gap: CGFloat = tight ? 5 : 8
        return HStack(spacing: 0) {
            Text("✦").pixelText(Theme.s, Theme.goldDk, shadow: false).padding(.horizontal, gap)
            Text(text).pixelText(tight ? Theme.s : Theme.m, Theme.edge, shadow: false)
            Text("✦").pixelText(Theme.s, Theme.goldDk, shadow: false).padding(.horizontal, gap)
        }
        .lineLimit(1).fixedSize()
        .padding(.horizontal, 22)
        .padding(.top, tight ? 9 : 6).padding(.bottom, tight ? 11 : 8)
    }
}

/// polygon(0 0, 100% 0, 100%-n 50%, 100% 100%, 0 100%, n 50%)
struct RibbonShape: Shape {
    var notch: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - notch, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + notch, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct ExpBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            let w = (geo.size.width - 6) * min(1, max(0, fraction))
            // step the fill to 1/8ths like the CSS `steps(8)` transition
            ZStack(alignment: .leading) {
                Color(hex: "#0a0a20")
                HStack(spacing: 0) {
                    Canvas { ctx, size in
                        var x: CGFloat = 0
                        while x < size.width {
                            ctx.fill(Path(CGRect(x: x, y: 0, width: 9, height: size.height)), with: .color(Theme.green))
                            ctx.fill(Path(CGRect(x: x + 9, y: 0, width: 3, height: size.height)), with: .color(Color(hex: "#3fae3f")))
                            x += 12
                        }
                        ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 3)), with: .color(.white.opacity(0.35)))
                    }
                    .frame(width: w)
                    Spacer(minLength: 0)
                }
            }
            .padding(3)
            .background(Theme.edge)
        }
        .frame(height: 20)
        // Pixel style: the bar jumps straight to the new value (no smooth fill), even inside withAnimation.
        .transaction { $0.animation = nil }
    }
}

/// One-line hero strip for the other tabs on iPhone.
struct HeroStrip: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        let st = store.stats
        HStack(spacing: 12) {
            HeroPortrait(stats: st, px: 3, width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lv.\(st.lv)").pixelText(Theme.m, Theme.gold)
                    Text(store.l.titleName(st.lv)).pixelText(Theme.s, Theme.muted, shadow: false).lineLimit(1)
                    Spacer()
                    Text("\(st.cur)/\(st.need)").pixelText(Theme.s, Theme.muted, shadow: false)
                }
                ExpBar(fraction: Double(st.cur) / Double(max(1, st.need)))
            }
        }
        .pixelWindow(padding: 14)
    }
}
