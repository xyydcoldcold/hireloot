import SwiftUI

/// Vertical ScrollView with a pixel-art scrollbar instead of the system indicator
/// (same look as the web's `::-webkit-scrollbar` in style.css): a dark inset track
/// with a cream thumb and hard black edges. The thumb moves in whole 2pt steps.
struct PixelScrollView<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var space = UUID()
    @State private var offset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { outer in
            ScrollView {
                content.background(
                    GeometryReader { g in
                        Color.clear.preference(key: PixelScrollMetrics.self,
                                               value: [-g.frame(in: .named(space)).minY, g.size.height])
                    }
                )
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: space)
            .onPreferenceChange(PixelScrollMetrics.self) { v in
                guard v.count == 2 else { return }
                offset = v[0]; contentHeight = v[1]
            }
            .overlay(alignment: .topTrailing) {
                PixelScrollbar(offset: offset, content: contentHeight, viewport: outer.size.height)
                    .padding(.trailing, 2)
            }
        }
    }
}

private struct PixelScrollMetrics: PreferenceKey {
    static var defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        let n = nextValue(); if !n.isEmpty { value = n }
    }
}

struct PixelScrollbar: View {
    var offset: CGFloat
    var content: CGFloat
    var viewport: CGFloat
    static let width: CGFloat = 8
    private let inset: CGFloat = 6   // keeps the track clear of rounded screen corners

    var body: some View {
        let track = max(0, viewport - inset * 2)
        if content > viewport + 1, track > 24 {
            let thumb = max(28, (track * viewport / content).rounded())
            let progress = min(1, max(0, offset / (content - viewport)))
            let y = ((track - thumb) * progress / 2).rounded() * 2
            ZStack(alignment: .top) {
                Rectangle().fill(Theme.deep.opacity(0.85))
                    .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
                thumbView.frame(height: thumb).offset(y: y)
            }
            .frame(width: Self.width, height: track)
            .padding(.vertical, inset)
            .allowsHitTesting(false)
            .transaction { $0.animation = nil }
        }
    }

    private var thumbView: some View {
        Rectangle().fill(Theme.frame)
            .overlay(alignment: .leading) { Color.white.opacity(0.45).frame(width: 2).padding(.vertical, 2) }
            .overlay(alignment: .trailing) { Color.black.opacity(0.25).frame(width: 2).padding(.vertical, 2) }
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
    }
}
