import SwiftUI

/// Sign in / sign up / forgot password, plus the conflict picker and the welcome (name your hero) box.
struct AuthView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var cloud: CloudSync
    enum Mode { case login, signup, forgot }
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var ok = false
    @State private var busy = false

    var body: some View {
        let l = store.l
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        PanelTitle(text: mode == .forgot ? l.t("cloud.forgot.title") : l.t("cloud.title"))
                        Spacer()
                        PixelSegment(options: [("zh", "中文"), ("en", "EN")], value: $store.lang)
                        Button { cloud.showAuth = false } label: {
                            Text("✕").font(Theme.font(Theme.m)).foregroundStyle(Theme.muted).padding(.leading, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l.t("settings.close"))
                    }
                    if mode != .forgot {
                        PixelSegment(options: [("login", l.t("cloud.login")), ("signup", l.t("cloud.signup"))],
                                     value: Binding(get: { mode == .login ? "login" : "signup" },
                                                    set: { mode = $0 == "login" ? .login : .signup; message = "" }))
                    } else {
                        Text(l.t("cloud.forgot.body")).pixelText(Theme.s, Theme.muted, shadow: false)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.t("cloud.email")).pixelText(Theme.s, Theme.muted, shadow: false)
                        PixelField(placeholder: "you@example.com", text: $email, maxLength: 254, onSubmit: submit)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                            .textContentType(.username)
                    }
                    if mode != .forgot {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l.t("cloud.password")).pixelText(Theme.s, Theme.muted, shadow: false)
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                                .font(Theme.font(Theme.m)).foregroundStyle(Theme.ink)
                                .textContentType(mode == .signup ? .newPassword : .password)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Theme.deep).padding(3).background(Theme.edge)
                                .onSubmit(submit)
                        }
                    }
                    if !message.isEmpty {
                        Text(message).pixelText(Theme.s, ok ? Theme.green : Theme.red, shadow: false).fixedSize(horizontal: false, vertical: true)
                    }
                    Button(action: submit) {
                        Text(l.t(mode == .login ? "cloud.login.submit" : mode == .signup ? "cloud.signup.submit" : "cloud.forgot.submit"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pixelPrimary)
                    .disabled(busy)
                    if mode == .login {
                        Button(l.t("cloud.forgot")) { mode = .forgot; message = "" }.buttonStyle(.plain).pixelText(Theme.s, Theme.muted, shadow: false)
                    } else if mode == .forgot {
                        Button(l.t("cloud.back")) { mode = .login; message = "" }.buttonStyle(.plain).pixelText(Theme.s, Theme.muted, shadow: false)
                    }
                    if !cloud.signedIn {
                        VStack(alignment: .leading, spacing: 6) {
                            Button(l.t("cloud.guest")) { cloud.playAsGuest() }.buttonStyle(.pixel)
                            Text(l.t("cloud.guestHint")).pixelText(Theme.s, Theme.muted, shadow: false).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 6)
                    }
                }
                .pixelWindow(padding: 24)
                .frame(maxWidth: 460)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func submit() {
        let l = store.l
        let e = email.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty else { return }
        if mode != .forgot && password.count < 6 { message = l.t("cloud.err.weak"); ok = false; return }
        busy = true; message = l.t("cloud.wait"); ok = true
        Task {
            defer { busy = false }
            do {
                switch mode {
                case .login:
                    try await cloud.signIn(email: e, password: password)
                    message = ""
                case .signup:
                    if try await cloud.signUp(email: e, password: password) { message = "" }
                    else { message = l.t("cloud.signup.check", ["e": e]); ok = true }
                case .forgot:
                    try await cloud.recover(email: e)
                    message = l.t("cloud.forgot.sent", ["e": e]) + "\n" + l.t("native.recoverWeb"); ok = true
                }
            } catch {
                message = Self.errText(error, l); ok = false
            }
        }
    }

    static func errText(_ err: Error, _ l: L10n) -> String {
        guard let e = err as? SupabaseError else { return err.localizedDescription }
        let code = e.code ?? "", msg = e.message.lowercased()
        if e.isNetwork { return l.t("cloud.err.network") }
        if code == "invalid_credentials" || msg.contains("invalid login credentials") { return l.t("cloud.err.cred") }
        if code == "email_not_confirmed" || msg.contains("email not confirmed") { return l.t("cloud.err.unconfirmed") }
        if code == "user_already_exists" || msg.contains("already registered") { return l.t("cloud.err.exists") }
        if code == "weak_password" || msg.contains("password should") { return l.t("cloud.err.weak") }
        if msg.contains("rate limit") || msg.contains("too many") || code.contains("rate_limit") { return l.t("cloud.err.rate") }
        return e.message
    }
}

struct ConflictView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var cloud: CloudSync
    let conflict: CloudSync.Conflict

    var body: some View {
        let l = store.l
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(text: l.t("cloud.conflict.title"))
                Text(l.t("cloud.conflict.body")).pixelText(Theme.m).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    option("cloud", l.t("cloud.conflict.cloud"), conflict.row.data, l) { cloud.resolveConflict(useCloud: true) }
                    option("chest", l.t("cloud.conflict.local"), store.state, l) { cloud.resolveConflict(useCloud: false) }
                }
                Text(l.t("cloud.conflict.hint")).pixelText(Theme.s, Theme.muted, shadow: false).fixedSize(horizontal: false, vertical: true)
            }
            .pixelWindow(padding: 24)
            .frame(maxWidth: 520)
            .padding(20)
        }
    }

    private func option(_ icon: String, _ title: String, _ s: SaveState, _ l: L10n, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PixelIcon(name: icon, px: 3)
                Text(title).font(Theme.font(Theme.m))
                Text(l.t("cloud.conflict.count", ["t": s.tasks.count, "b": s.interviews.count])).font(Theme.font(Theme.s)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pixel)
    }
}

struct WelcomeView: View {
    @EnvironmentObject var store: GameStore
    let close: () -> Void
    @State private var name = ""

    var body: some View {
        let l = store.l
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(text: l.t("cloud.welcome.title"))
                Text(l.t("cloud.welcome.body")).pixelText(Theme.m).fixedSize(horizontal: false, vertical: true)
                Text(l.t("cloud.welcome.name")).pixelText(Theme.s, Theme.muted, shadow: false)
                PixelField(placeholder: l.t("hero.namePh"), text: $name, maxLength: GameStore.nameMax) { store.setName(name); close() }
                Button { store.setName(name); close() } label: { Text(l.t("cloud.welcome.go")).frame(maxWidth: .infinity) }
                    .buttonStyle(.pixelPrimary)
                Button(l.t("cloud.welcome.later"), action: close).buttonStyle(.plain).pixelText(Theme.s, Theme.muted, shadow: false)
            }
            .pixelWindow(padding: 24)
            .frame(maxWidth: 460)
            .padding(20)
        }
        .onAppear { name = store.state.heroName }
    }
}

struct WelcomeBackToast: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).pixelText(Theme.m, Theme.gold)
            Text(sub).pixelText(Theme.s, Theme.muted, shadow: false)
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
        .background(Theme.win)
        .overlay(Rectangle().inset(by: 3).strokeBorder(Theme.frame, lineWidth: 2))
        .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 3))
    }
}
