import SwiftUI

struct BossView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState
    @State private var company = ""
    @State private var round = "r1"
    @State private var date = Date()
    @State private var result = "pending"
    @State private var note = ""

    var body: some View {
        let l = store.l
        let list = store.state.interviews.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(text: l.t("boss.formTitle"))
                form(l)
                Text(l.t("boss.rule")).pixelText(Theme.s, Theme.muted, shadow: false).fixedSize(horizontal: false, vertical: true)
            }
            .pixelWindow()

            if list.isEmpty {
                EmptyLine(text: l.t("boss.empty")).pixelWindow()
            } else {
                ForEach(list) { BossCard(iv: $0) }
            }
        }
    }

    @ViewBuilder private func form(_ l: L10n) -> some View {
        let label = { (s: String) in Text(s).pixelText(Theme.s, Theme.muted, shadow: false) }
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) { label(l.t("boss.company")); PixelField(placeholder: l.t("boss.companyPh"), text: $company, maxLength: 80) }
                        .frame(minWidth: 200)
                    VStack(alignment: .leading, spacing: 4) { label(l.t("boss.round")); PixelPicker(options: PixelPicker.rounds(l), value: $round, startOpen: UserDefaults.standard.bool(forKey: "HLPicker")) }
                    VStack(alignment: .leading, spacing: 4) { label(l.t("boss.date")); dateField }
                }
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) { label(l.t("boss.company")); PixelField(placeholder: l.t("boss.companyPh"), text: $company, maxLength: 80) }
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) { label(l.t("boss.round")); PixelPicker(options: PixelPicker.rounds(l), value: $round, startOpen: UserDefaults.standard.bool(forKey: "HLPicker")) }
                        VStack(alignment: .leading, spacing: 4) { label(l.t("boss.date")); dateField }
                        Spacer(minLength: 0)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                label(l.t("boss.result"))
                HStack(spacing: 8) {
                    resultButton("pass", "trophy", l.t("boss.pass"))
                    resultButton("fail", "skull", l.t("boss.fail"))
                    resultButton("pending", "hourglass", l.t("boss.pending"))
                }
            }
            VStack(alignment: .leading, spacing: 4) { label(l.t("boss.note")); PixelField(placeholder: l.t("boss.notePh"), text: $note, maxLength: 300) }
            Button {
                store.addInterview(company: company, round: round, date: date, result: result, note: note)
                company = ""; note = ""; result = "pending"
            } label: { Text(l.t("boss.submit")).frame(maxWidth: .infinity) }
            .buttonStyle(.pixelPrimary)
            .disabled(company.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var dateField: some View {
        PixelDateField(date: $date, lang: store.lang, startOpen: UserDefaults.standard.bool(forKey: "HLCalendar"))
    }

    private func resultButton(_ value: String, _ icon: String, _ label: String) -> some View {
        Button { result = value } label: {
            HStack(spacing: 6) { PixelIcon(name: icon); Text(label).lineLimit(1) }
        }
        .buttonStyle(.pixel(result == value ? Theme.gold : Theme.button, fg: result == value ? Theme.edge : Theme.ink, size: Theme.m, compact: true))
    }
}

struct BossCard: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ui: UIState
    let iv: Interview

    var body: some View {
        let l = store.l
        let r = Rules.bossReward(iv)
        let pass = Rules.bossBase("pass"), fail = Rules.bossBase("fail")
        HStack(alignment: .top, spacing: 16) {
            PixelSprite(grid: HeroArt.boss(iv.result), px: 4)
                .saturation(iv.result == "pass" ? 0.2 : 1)
                .opacity(iv.result == "pass" ? 0.75 : 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(iv.company).pixelText(Theme.l)
                    Text("· " + l.roundLabel(iv.round)).pixelText(Theme.s, Theme.muted, shadow: false)
                }
                HStack(spacing: 6) {
                    Text(l.prettyDate(iv.date) + " ·").foregroundStyle(Theme.muted)
                    switch iv.result {
                    case "pass": Text(l.t("boss.won")).foregroundStyle(Theme.gold)
                    case "fail": Text(l.t("boss.lost")).foregroundStyle(Color(hex: "#ff8a80"))
                    default: Text(l.t("boss.wait")).foregroundStyle(Color(hex: "#c77dff"))
                    }
                }
                .font(Theme.font(Theme.s))
                if !iv.note.isEmpty {
                    Text(iv.note).pixelText(Theme.s, Theme.ink, shadow: false)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.deep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(iv.result == "pending"
                     ? l.t("boss.settle", ["p": pass.exp + iv.bonus, "g": pass.gold, "f": fail.exp + iv.bonus])
                     : l.t("boss.reward", ["r": l.rewardText(exp: r.exp, gold: r.gold)]) + (iv.bonus > 0 ? l.t("boss.bonus", ["n": iv.bonus]) : ""))
                    .pixelText(Theme.s, Theme.muted, shadow: false)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if iv.result == "pending" {
                        Button(l.t("boss.pass")) { store.settle(iv.id, pass: true) }.buttonStyle(.pixel(Theme.greenDk, size: Theme.s, compact: true))
                        Button(l.t("boss.fail")) { store.settle(iv.id, pass: false) }.buttonStyle(.pixel(size: Theme.s, compact: true))
                    }
                    Button(l.t("task.del")) {
                        ui.dialog = DialogRequest(title: l.t("boss.delTitle"),
                                                  body: l.t("boss.delConfirm", ["c": iv.company, "r": l.roundLabel(iv.round)]),
                                                  ok: l.t("task.del"), cancel: l.t("dlg.cancel"), danger: true) { store.deleteInterview(iv.id) }
                    }
                    .buttonStyle(.pixel(Color(hex: "#3a2a4a"), fg: Theme.muted, size: Theme.s, compact: true))
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .pixelWindow(padding: 18, tint: iv.result == "fail" ? Color(hex: "#3a2550") : iv.result == "pass" ? Color(hex: "#2a3a60") : nil)
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static func pixel(size: CGFloat, compact: Bool) -> PixelButtonStyle { PixelButtonStyle(size: size, compact: compact) }
}
