import SwiftUI
import CoreText

/// Colors and type from style.css (JRPG blue windows, cream frame, gold accents).
enum Theme {
    static let bg = Color(hex: "#100f26")
    static let bg2 = Color(hex: "#1a1840")
    static let win = Color(hex: "#1f2358")
    static let winHi = Color(hex: "#2a3070")
    static let row = Color(hex: "#272c68")
    static let rowHi = Color(hex: "#31377d")
    static let deep = Color(hex: "#12153a")
    static let frame = Color(hex: "#d9d2b8")
    static let edge = Color(hex: "#07061a")
    static let ink = Color(hex: "#f6f2e0")
    static let muted = Color(hex: "#9ea4d8")
    static let gold = Color(hex: "#ffcf4a")
    static let goldDk = Color(hex: "#b07a12")
    static let green = Color(hex: "#5fd35f")
    static let greenDk = Color(hex: "#2d8a3a")
    static let red = Color(hex: "#ff6b6b")
    static let button = Color(hex: "#48508f")
    static let tab = Color(hex: "#2b3070")
    static let placeholder = Color(hex: "#6a70a8")

    // Pixel font sizes: crisp at 12 / 18 / 24 / 36
    static let s: CGFloat = 12
    static let m: CGFloat = 18
    static let l: CGFloat = 24
    static let xl: CGFloat = 36

    static let fontName = "Fusion-Pixel-12px-Proportional-zh_hans-Regular"
    static func font(_ size: CGFloat) -> Font { .custom(fontName, fixedSize: size) }

    /// The pixel font ships inside the app (SIL OFL); register it once at launch.
    static func registerFont() {
        guard let url = Bundle.main.url(forResource: "FusionPixel12", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255,
                  blue: Double(v & 255) / 255, opacity: 1)
    }
}

/// Hex helpers for sprite shading (`shade()` in app.js).
enum HexColor {
    static func shade(_ hex: String, _ f: Double) -> String {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = Int(s, radix: 16) ?? 0
        let ch = { (v: Int) in max(0, min(255, Int((Double(v) * f).rounded()))) }
        return String(format: "#%02x%02x%02x", ch(n >> 16), ch((n >> 8) & 255), ch(n & 255))
    }
}

// MARK: - Pixel window (`.px` in style.css)

struct PixelWindow: ViewModifier {
    var padding: CGFloat = 18
    var tint: Color? = nil
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [tint ?? Theme.winHi, Theme.win], startPoint: .top, endPoint: .init(x: 0.5, y: 0.4))
            )
            .overlay(Rectangle().inset(by: 4).strokeBorder(Theme.frame, lineWidth: 3))
            .overlay(Rectangle().inset(by: 7).strokeBorder(Theme.edge, lineWidth: 3))
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 4))
            .background(Rectangle().fill(Color.black.opacity(0.45)).offset(x: 6, y: 6))
    }
}

/// Small dark inset box (stats cells, pills).
struct InsetBox: ViewModifier {
    var color: Color = Theme.deep
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
    }
}

extension View {
    func pixelWindow(padding: CGFloat = 18, tint: Color? = nil) -> some View { modifier(PixelWindow(padding: padding, tint: tint)) }
    func insetBox(_ color: Color = Theme.deep) -> some View { modifier(InsetBox(color: color)) }
    func pixelText(_ size: CGFloat = Theme.m, _ color: Color = Theme.ink, shadow: Bool = true) -> some View {
        font(Theme.font(size)).foregroundStyle(color)
            .shadow(color: shadow ? Theme.edge.opacity(0.9) : .clear, radius: 0, x: size >= Theme.l ? 2 : 1, y: size >= Theme.l ? 2 : 1)
    }
}

// MARK: - Buttons

struct PixelButtonStyle: ButtonStyle {
    var color: Color = Theme.button
    var fg: Color = Theme.ink
    var size: CGFloat = Theme.m
    var compact = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.font(size))
            .foregroundStyle(fg)
            .shadow(color: fg == Theme.ink ? .black.opacity(0.35) : .clear, radius: 0, x: 2, y: 2)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 7)
            .background(color)
            .overlay(alignment: .topLeading) {
                if !pressed {
                    VStack(spacing: 0) { Color.white.opacity(0.18).frame(height: 3); Spacer(minLength: 0) }
                    HStack(spacing: 0) { Color.white.opacity(0.18).frame(width: 3); Spacer(minLength: 0) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 0) { Spacer(minLength: 0); Color.black.opacity(0.35).frame(height: 3) }
                HStack(spacing: 0) { Spacer(minLength: 0); Color.black.opacity(0.35).frame(width: 3) }
            }
            .padding(3)
            .background(Theme.edge)
            .offset(x: pressed ? 2 : 0, y: pressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.5)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static var pixel: PixelButtonStyle { PixelButtonStyle() }
    static var pixelPrimary: PixelButtonStyle { PixelButtonStyle(color: Theme.greenDk) }
    static func pixel(_ color: Color, fg: Color = Theme.ink, size: CGFloat = Theme.m, compact: Bool = false) -> PixelButtonStyle {
        PixelButtonStyle(color: color, fg: fg, size: size, compact: compact)
    }
}

/// Text field with the dark inset look.
struct PixelField: View {
    let placeholder: String
    @Binding var text: String
    var maxLength = 200
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.placeholder))
            .textFieldStyle(.plain)
            .font(Theme.font(Theme.m))
            .foregroundStyle(Theme.ink)
            .autocorrectionDisabled()
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.deep)
            .overlay(alignment: .topLeading) {
                VStack(spacing: 0) { Color.black.opacity(0.45).frame(height: 3); Spacer(minLength: 0) }
            }
            .padding(3)
            .background(Theme.edge)
            .onSubmit(onSubmit)
            .onChange(of: text) { v in if v.count > maxLength { text = String(v.prefix(maxLength)) } }
    }
}

/// `h2` with the gold ▶ marker.
struct PanelTitle: View {
    let text: String
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("▶").font(Theme.font(Theme.s)).foregroundStyle(Theme.gold)
            Text(text).pixelText(Theme.l)
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = Theme.green
    var body: some View {
        Text(text).font(Theme.font(Theme.s)).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Theme.edge)
            .overlay(Rectangle().strokeBorder(Color(hex: "#33396f"), lineWidth: 2))
    }
}

/// The page background (dot grid over a dark gradient).
struct PixelBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bg2, Theme.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.6))
            RadialGradient(colors: [Color(hex: "#2a2470"), .clear], center: .init(x: 0.5, y: -0.1), startRadius: 0, endRadius: 600)
            Canvas { ctx, size in
                let step: CGFloat = 24
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.07)))
                        x += step
                    }
                    y += step
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Text with stacked hard shadows (CSS `text-shadow: 3px 3px a, 6px 6px b`), drawn as separate layers
/// so the second shadow does not also shadow the first.
struct LayeredText: View {
    let text: String
    var size: CGFloat = Theme.xl
    var color: Color = Theme.gold
    var layers: [(Color, CGFloat)] = [(Theme.edge, 6), (Theme.goldDk, 3)]
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layers.indices, id: \.self) { i in
                Text(text).font(Theme.font(size)).foregroundStyle(layers[i].0)
                    .offset(x: layers[i].1, y: layers[i].1)
            }
            Text(text).font(Theme.font(size)).foregroundStyle(color)
        }
        .fixedSize()
        .padding(.trailing, layers.map(\.1).max() ?? 0)
        .padding(.bottom, layers.map(\.1).max() ?? 0)
    }
}
