import SwiftUI

enum Theme {
    static let paper = Color(hex: 0xF6F5F0)
    static let surface = Color(hex: 0xFFFefa)
    static let ink = Color(hex: 0x1D2922)
    static let muted = Color(hex: 0x53645B)
    static let divider = Color(hex: 0xDFE3DA)
    static let moss = Color(hex: 0x2F5745)
    static let mint = Color(hex: 0xE9EFE5)

    static let night = Color(hex: 0x151A28)
    static let panel = Color(hex: 0x1E2637)
    static let nightLine = Color(hex: 0x354055)
    static let moon = Color(hex: 0xF1F2EC)
    static let fog = Color(hex: 0xB4C0CD)
    static let glow = Color(hex: 0xC6E5AF)

    static let locale = Locale(identifier: "zh_CN")

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month().day().weekday(.wide))
    }

    static func historyDay(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).year().month().day().weekday(.wide))
    }

    static func interviewDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).year().month().day().hour().minute())
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}

extension Effort {
    var icon: String {
        switch self {
        case .project: "hammer.fill"
        case .resume: "shield.lefthalf.filled"
        case .application: "paperplane.fill"
        case .networking: "person.2.fill"
        case .interviewPrep: "scope"
        }
    }

    var foreground: Color {
        switch self {
        case .project: Color(hex: 0x704D20)
        case .resume: Color(hex: 0x55427E)
        case .application: Color(hex: 0x2C5B51)
        case .networking: Color(hex: 0x7B3C50)
        case .interviewPrep: Color(hex: 0x315778)
        }
    }

    var background: Color {
        switch self {
        case .project: Color(hex: 0xF5EBD8)
        case .resume: Color(hex: 0xEDE5F6)
        case .application: Color(hex: 0xE3EFE9)
        case .networking: Color(hex: 0xF5E6EC)
        case .interviewPrep: Color(hex: 0xE4EEF8)
        }
    }

    var gameColor: Color {
        switch self {
        case .project: Color(hex: 0xEABD79)
        case .resume: Color(hex: 0xC4B2F1)
        case .application: Color(hex: 0x9BD7BD)
        case .networking: Color(hex: 0xEDAFC6)
        case .interviewPrep: Color(hex: 0xA5CAF3)
        }
    }
}

struct ActionButton: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .foregroundStyle(primary ? .white : Theme.ink)
            .background(primary ? Theme.moss : Theme.mint, in: RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.44)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TapButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}
