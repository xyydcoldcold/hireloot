import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var cloud: CloudSync
    @EnvironmentObject var ui: UIState
    let close: () -> Void

    var body: some View {
        let l = store.l
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PanelTitle(text: l.t("settings"))
                    Spacer()
                    Button(action: close) { Text("✕").font(Theme.font(Theme.m)).foregroundStyle(Theme.muted) }
                        .buttonStyle(.plain).accessibilityLabel(l.t("settings.close"))
                }
                row(l.t("settings.lang")) {
                    PixelSegment(options: [("zh", "中文"), ("en", "English")], value: $store.lang)
                }
                account(l)
                row(l.t("settings.sfx")) {
                    PixelSegment(options: [("on", l.t("settings.on")), ("off", l.t("settings.off"))],
                                 value: Binding(get: { store.sfxOn ? "on" : "off" }, set: { store.sfxOn = $0 == "on"; if store.sfxOn { Sfx.shared.click() } }))
                }
                HStack {
                    Link(destination: URL(string: "https://hireloot.com/privacy.html?lang=\(store.lang)")!) {
                        Text(l.t("settings.privacy")).font(Theme.font(Theme.s)).foregroundStyle(Theme.muted).underline()
                    }
                    Spacer()
                    if let s = cloud.session {
                        Button(l.t("cloud.delete")) { confirmDelete(l, email: s.email) }
                            .buttonStyle(.pixel(Color(hex: "#b8324a"), size: Theme.s, compact: true))
                    }
                }
            }
            .pixelWindow(padding: 24)
            .frame(maxWidth: 520)
            .padding(20)
        }
    }

    private func confirmDelete(_ l: L10n, email: String) {
        ui.dialog = DialogRequest(title: l.t("cloud.deleteTitle"), body: l.t("cloud.deleteBody", ["email": email]),
                                  ok: l.t("cloud.deleteOk"), cancel: l.t("dlg.cancel"), danger: true) {
            Task {
                do { try await cloud.deleteAccount(); close() }
                catch { ui.dialog = DialogRequest(title: l.t("cloud.deleteTitle"), body: l.t("cloud.deleteFail"), ok: l.t("dlg.ok")) }
            }
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { Text(label).pixelText(Theme.m); Spacer(); content() }
            VStack(alignment: .leading, spacing: 8) { Text(label).pixelText(Theme.m); content() }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Color(hex: "#33396f").frame(height: 2).offset(y: 8) }
    }

    @ViewBuilder private func account(_ l: L10n) -> some View {
        if let s = cloud.session {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) { accountLabel(l, email: s.email); Spacer(); logoutButton(l) }
                VStack(alignment: .leading, spacing: 8) { accountLabel(l, email: s.email); logoutButton(l) }
            }
        } else {
            row(l.t("cloud.account")) {
                Button(l.t("cloud.loginSignup")) { close(); cloud.showAuth = true }.buttonStyle(.pixelPrimary)
            }
            Text(l.t("cloud.guestNow")).pixelText(Theme.s, Theme.muted, shadow: false).padding(.top, -8)
        }
    }

    private func accountLabel(_ l: L10n, email: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.t("cloud.account")).pixelText(Theme.m)
            Text(email).pixelText(Theme.s, Theme.muted, shadow: false).lineLimit(1)
            HStack(spacing: 6) {
                PixelIcon(name: "cloud")
                Text(l.t("cloud.status." + cloud.status.rawValue)).font(Theme.font(Theme.s))
                    .foregroundStyle(cloud.status == .synced ? Theme.green : cloud.status == .error ? Theme.red : Theme.muted)
            }
        }
    }

    private func logoutButton(_ l: L10n) -> some View {
        HStack(spacing: 8) {
            Button(l.t("cloud.syncNow")) { cloud.pullIfStale(minInterval: 0) }.buttonStyle(.pixel(size: Theme.s, compact: true))
            Button(l.t("cloud.logout")) {
                Task {
                    if !(await cloud.signOut(force: false)) {
                        ui.dialog = DialogRequest(title: l.t("cloud.logoutTitle"), body: l.t("cloud.logoutUnsynced"), ok: l.t("cloud.logout"),
                                                  cancel: l.t("dlg.cancel"), danger: true) { Task { _ = await cloud.signOut(force: true) } }
                    } else { close() }
                }
            }
            .buttonStyle(.pixel(size: Theme.s, compact: true))
        }
    }
}
