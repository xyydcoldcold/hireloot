import SwiftUI
import UniformTypeIdentifiers

struct SaveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var cloud: CloudSync
    @EnvironmentObject var ui: UIState
    let close: () -> Void
    @State private var exporting = false
    @State private var importing = false

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
                row(l.t("settings.data")) {
                    HStack(spacing: 8) {
                        Button(l.t("settings.export")) { exporting = true }.buttonStyle(.pixel(size: Theme.m, compact: true))
                        Button(l.t("settings.import")) { importing = true }.buttonStyle(.pixel(size: Theme.m, compact: true))
                    }
                }
                row(l.t("settings.sfx")) {
                    PixelSegment(options: [("on", l.t("settings.on")), ("off", l.t("settings.off"))],
                                 value: Binding(get: { store.sfxOn ? "on" : "off" }, set: { store.sfxOn = $0 == "on"; if store.sfxOn { Sfx.shared.click() } }))
                }
            }
            .pixelWindow(padding: 24)
            .frame(maxWidth: 520)
            .padding(20)
        }
        .fileExporter(isPresented: $exporting, document: SaveDocument(data: store.exportData()), contentType: .json,
                      defaultFilename: "\(l.t("export.name"))-\(Day.today()).json") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let s = SaveState.decodeStrict(data) else {
                ui.dialog = DialogRequest(title: l.t("import.failTitle"), body: l.t("import.bad"), ok: l.t("dlg.ok"))
                return
            }
            ui.dialog = DialogRequest(title: l.t("import.title"), body: l.t("import.confirm", ["t": s.tasks.count, "b": s.interviews.count]),
                                      ok: l.t("import.ok"), cancel: l.t("dlg.cancel"), danger: true) {
                store.importSave(s)
                close()
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
            Button(l.t("native.syncNow")) { cloud.pullIfStale(minInterval: 0) }.buttonStyle(.pixel(size: Theme.s, compact: true))
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
