import SwiftUI

/// A pixel grid: rows of characters, each mapped to a color by a palette. Port of `sprite()` in app.js,
/// including the automatic 1-pixel outline.
struct SpriteGrid {
    let width: Int
    let height: Int
    let cells: [(x: Int, y: Int, color: Color)]

    init(map: [String], palette: [Character: Color], outline: Color? = nil) {
        var rows = map.map { Array($0) }
        var pal = palette
        if let outline {
            let w = rows.map(\.count).max() ?? 0
            let blank = Array(repeating: Character("."), count: w + 2)
            var grid = [blank]
            for r in rows { grid.append(["."] + r + Array(repeating: ".", count: w - r.count) + ["."]) }
            grid.append(blank)
            func filled(_ x: Int, _ y: Int) -> Bool {
                y >= 0 && y < grid.count && x >= 0 && x < grid[y].count && pal[grid[y][x]] != nil
            }
            rows = grid.enumerated().map { y, row in
                row.enumerated().map { x, ch in
                    pal[ch] == nil && (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1)) ? "§" : ch
                }
            }
            pal["§"] = outline
        }
        var cells: [(x: Int, y: Int, color: Color)] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() { if let c = pal[ch] { cells.append((x: x, y: y, color: c)) } }
        }
        self.cells = cells
        self.width = rows.map(\.count).max() ?? 0
        self.height = rows.count
    }

    static func palette(_ hex: [String: String]) -> [Character: Color] {
        var p: [Character: Color] = [:]
        for (k, v) in hex { if let ch = k.first { p[ch] = Color(hex: v) } }
        return p
    }
}

struct PixelSprite: View {
    let grid: SpriteGrid
    let px: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            for c in grid.cells {
                ctx.fill(Path(CGRect(x: CGFloat(c.x) * px, y: CGFloat(c.y) * px, width: px + 0.02, height: px + 0.02)),
                         with: .color(c.color))
            }
        }
        .frame(width: CGFloat(grid.width) * px, height: CGFloat(grid.height) * px)
        .accessibilityHidden(true)
    }
}

/// Pixel icons from app.js (no emoji, no system glyphs).
struct PixelIcon: View {
    let name: String
    var px: CGFloat = 2
    private static var cache: [String: SpriteGrid] = [:]

    var body: some View {
        PixelSprite(grid: Self.grid(name), px: px)
    }
    static func grid(_ name: String) -> SpriteGrid {
        if let g = cache[name] { return g }
        let icons = GameData.shared.art.icons
        let ic = icons[name] ?? icons["none"]!
        let g = SpriteGrid(map: ic.map, palette: SpriteGrid.palette(ic.pal))
        cache[name] = g
        return g
    }
}

// MARK: - Hero

enum HeroArt {
    static let art = GameData.shared.art
    static let outline = Color(hex: "#0c0b16")
    /// Sparkles around SR / SSR weapons (outline adds 1 to coordinates).
    static let sparks: [String: [(Int, Int)]] = ["SR": [(10, 0), (15, 11)], "SSR": [(10, 0), (15, 11), (0, 4), (1, 10)]]

    /// Lays the weapon over the hero's right hand: only into empty cells, so hand and body stay in front.
    static func holdWeapon(_ map: [String], shape: String) -> [String] {
        let held = art.held[shape] ?? art.held["sword"]!
        return map.enumerated().map { y, row in
            let r = y - held.top
            guard r >= 0, r < held.rows.count else { return row }
            let wr = Array(held.rows[r])
            return String(Array(row).enumerated().map { x, ch -> Character in
                let i = x - 12
                guard ch == ".", i >= 0, i < wr.count, wr[i] != "." else { return ch }
                return Character(art.heldKeys[String(wr[i])] ?? ".")
            })
        }
    }

    static func grid(def: Int, weapon: Weapon?) -> SpriteGrid {
        let armor = Rules.armorTier(def).color
        var pal: [String: String] = [
            "h": "#3b2a1a", "s": "#f1c27d", "e": "#1b1a2b", "m": "#c0392b",
            "a": armor, "A": HexColor.shade(armor, 0.72), "y": "#f2c14e", "p": "#2c3e70", "b": "#3b2a1a", "H": "#6b4a2b"
        ]
        var map = art.hero
        if let w = weapon, let wp = GameData.shared.weapons.palettes[w.pal] {
            for (k, digit) in art.heldKeys { pal[digit] = wp[k] }
            map = holdWeapon(map, shape: w.shape)
        }
        return SpriteGrid(map: map, palette: SpriteGrid.palette(pal), outline: outline)
    }

    static func boss(_ result: String) -> SpriteGrid {
        let body = result == "pass" ? "#6b6b7b" : result == "fail" ? "#b23a48" : "#8e44ad"
        return SpriteGrid(map: art.boss, palette: SpriteGrid.palette(["r": body, "w": "#fff", "k": "#111", "y": "#f2c14e"]), outline: outline)
    }

    static func weapon(_ w: Weapon, locked: Bool) -> SpriteGrid {
        let shape = GameData.shared.weapons.shapes[w.shape] ?? []
        if locked {
            var pal: [Character: Color] = [:]
            for row in shape { for ch in row where ch != "." { pal[ch] = Color(hex: "#07061a") } }
            return SpriteGrid(map: shape, palette: pal, outline: Color(hex: "#4a5094"))
        }
        return SpriteGrid(map: shape, palette: SpriteGrid.palette(GameData.shared.weapons.palettes[w.pal] ?? [:]), outline: outline)
    }
}

/// The hero standing on a level-themed backdrop (sky → forest → starry night → amethyst → sunset → embers → gold).
struct HeroPortrait: View {
    let stats: Stats
    var px: CGFloat = 8
    var width: CGFloat = 160
    var height: CGFloat = 172

    struct Backdrop { let sky1, sky2, gnd1, gnd2: String; let glow: Color; let deco: Color; let deco2: Color; let stars: Bool; let embers: Bool }
    static let backdrops: [Backdrop] = [
        .init(sky1: "#3a4a9c", sky2: "#5a74c8", gnd1: "#3e8a46", gnd2: "#2f6e38", glow: .white.opacity(0.12), deco: .white.opacity(0.55), deco2: .white.opacity(0.35), stars: false, embers: false),
        .init(sky1: "#1f5a5a", sky2: "#4fae8a", gnd1: "#2d6e38", gnd2: "#1f4a26", glow: .white.opacity(0.12), deco: .white.opacity(0.55), deco2: .white.opacity(0.35), stars: false, embers: false),
        .init(sky1: "#0c1440", sky2: "#2c4aa8", gnd1: "#2a3a6e", gnd2: "#1a264a", glow: Color(hex: "#7fdbff").opacity(0.35), deco: .white.opacity(0.55), deco2: .white.opacity(0.35), stars: true, embers: false),
        .init(sky1: "#2a0e5a", sky2: "#8a4ac8", gnd1: "#5a2a8a", gnd2: "#3a1a5e", glow: Color(hex: "#c77dff").opacity(0.6), deco: Color(hex: "#f3d9ff"), deco2: Color(hex: "#f3d9ff").opacity(0.6), stars: true, embers: false),
        .init(sky1: "#8a2a3a", sky2: "#ff9a3c", gnd1: "#a8541c", gnd2: "#6e3010", glow: Color(hex: "#ff9a3c").opacity(0.7), deco: Color(hex: "#fff0c8").opacity(0.75), deco2: Color(hex: "#ffe0a0").opacity(0.5), stars: false, embers: false),
        .init(sky1: "#2a0610", sky2: "#b0203a", gnd1: "#3a1014", gnd2: "#1a0608", glow: Color(hex: "#ff4a3a").opacity(0.75), deco: Color(hex: "#ffcf4a"), deco2: Color(hex: "#ff7a3c"), stars: false, embers: true),
        .init(sky1: "#6e4a08", sky2: "#ffd86a", gnd1: "#c58b3a", gnd2: "#8a5a1e", glow: Color(hex: "#ffe27a").opacity(0.9), deco: .white, deco2: Color(hex: "#fff4c2"), stars: true, embers: false)
    ]

    var body: some View {
        let bd = Self.backdrops[min(Rules.titleIndex(stats.lv), Self.backdrops.count - 1)]
        let scale = width / 160
        TimelineView(.periodic(from: .now, by: 0.6)) { tl in
            let tick = Int(tl.date.timeIntervalSinceReferenceDate / 0.6)
            ZStack(alignment: .bottom) {
                // sky + ground
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color(hex: bd.sky1), Color(hex: bd.sky2)], startPoint: .top, endPoint: .bottom)
                        .frame(height: height * 0.58)
                    LinearGradient(colors: [Color(hex: bd.gnd1), Color(hex: bd.gnd2)], startPoint: .top, endPoint: .bottom)
                }
                decorations(bd, tick: tick, scale: scale)
                // shadow under the feet
                Rectangle().fill(Color.black.opacity(0.3)).frame(width: 80 * scale, height: 8 * scale).padding(.bottom, 12 * scale)
                ZStack(alignment: .topLeading) {
                    PixelSprite(grid: HeroArt.grid(def: stats.def, weapon: stats.weapon), px: px)
                    if let w = stats.weapon, let sp = HeroArt.sparks[w.rarity] {
                        let c = Color(hex: Weapons.rarity(w.rarity).color)
                        ForEach(Array(sp.enumerated()), id: \.offset) { i, p in
                            Spark(color: c, px: px)
                                .offset(x: CGFloat(p.0) * px, y: CGFloat(p.1) * px)
                                .opacity((tick + i) % 2 == 0 ? 1 : 0.35)
                        }
                    }
                }
                .offset(y: tick % 2 == 0 ? 0 : -4 * scale)
                .padding(.bottom, 14 * scale)
            }
            .frame(width: width, height: height)
            .clipped()
            .overlay(Rectangle().inset(by: 3).strokeBorder(bd.glow, lineWidth: 2))
            .overlay(Rectangle().strokeBorder(Rules.titleIndex(stats.lv) >= 6 ? Theme.goldDk : Theme.edge, lineWidth: 3))
        }
    }

    @ViewBuilder
    private func decorations(_ bd: Backdrop, tick: Int, scale: CGFloat) -> some View {
        Canvas { ctx, size in
            let s = scale
            func dot(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
                ctx.fill(Path(CGRect(x: x * s, y: y * s, width: w * s, height: h * s)), with: .color(c))
            }
            if bd.embers {
                let rise = CGFloat(tick % 6) * 10
                let pts: [(CGFloat, CGFloat, Bool)] = [(14, 0, true), (36, 12, false), (54, 2, true), (84, 22, false), (110, 6, true), (132, 26, false), (142, 0, true), (22, 40, false), (126, 50, false), (70, 44, false)]
                for p in pts { dot(p.0, 132 - p.1 - rise, 3, 3, (p.2 ? bd.deco : bd.deco2).opacity(1 - Double(rise) / 80)) }
            } else if bd.stars {
                let on = tick % 2 == 0
                let pts: [(CGFloat, CGFloat, Bool)] = [(14, 14, true), (36, 26, false), (54, 16, true), (84, 36, false), (110, 20, true), (132, 40, false), (142, 14, true), (22, 54, false), (126, 64, false), (70, 58, false)]
                for p in pts { dot(p.0, p.1, 3, 3, (p.2 ? bd.deco : bd.deco2).opacity(on ? 1 : 0.45)) }
            } else {
                // two pixel clouds
                for (x, y, c) in [(16.0, 18.0, bd.deco), (112.0, 36.0, bd.deco2)] {
                    dot(x, y, 24, 6, c); dot(x + 6, y - 6, 12, 6, c)
                }
            }
            _ = size
        }
    }
}

private struct Spark: View {
    let color: Color
    let px: CGFloat
    var body: some View {
        Canvas { ctx, _ in
            func r(_ x: CGFloat, _ y: CGFloat, _ c: Color) { ctx.fill(Path(CGRect(x: x * px, y: y * px, width: px, height: px)), with: .color(c)) }
            r(1, 1, .white); r(0, 1, color); r(2, 1, color); r(1, 0, color); r(1, 2, color)
        }
        .frame(width: px * 3, height: px * 3)
    }
}
