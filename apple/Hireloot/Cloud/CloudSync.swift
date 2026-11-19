import SwiftUI
import Security

/// Email login + one JSON save per player, same rules as the web version's cloud.js:
///  - the local save is always the "current" one, so the app works offline
///  - every change is uploaded after a 1.5 s debounce; failures retry every 30 s
///  - each upload carries the last synced `rev`; a mismatch means another device saved,
///    and the player picks which save to keep (never overwritten silently)
///  - a guest save moves into the account on first sign-in
@MainActor
final class CloudSync: ObservableObject {
    enum Status: String { case idle, syncing, synced, offline, error }
    enum Greeting: Equatable { case welcome, back(String) }
    struct Conflict: Identifiable { let id = UUID(); let row: CloudRow }

    struct Meta: Codable { var uid: String?; var rev: Int; var dirty: Bool }

    @Published private(set) var session: AuthSession?
    @Published private(set) var status: Status = .idle
    @Published var conflict: Conflict?
    @Published var greeting: Greeting?
    @Published var showAuth = false

    private let store: GameStore
    private let api = SupabaseClient()
    private var pushTask: Task<Void, Never>?
    private var pushing = false
    private var pulling = false
    private var saveSeq = 0
    private var lastPull = Date.distantPast
    private var pendingGreet: Greeting?

    private static let metaKey = "hireloot.cloud"
    private static let guestKey = "hireloot.guest"
    private let disabled = UserDefaults.standard.bool(forKey: "HLDemo")

    var signedIn: Bool { session != nil }

    init(store: GameStore) {
        self.store = store
        session = disabled ? nil : Keychain.load()
        store.onSave = { [weak self] in self?.onSave() }
    }

    func start() {
        guard !disabled else { return }
        if session != nil { Task { await pull() } }
        else if !UserDefaults.standard.bool(forKey: Self.guestKey) { showAuth = true }
    }

    // MARK: Meta
    private var meta: Meta {
        get {
            guard let d = UserDefaults.standard.data(forKey: Self.metaKey), let m = try? JSONDecoder().decode(Meta.self, from: d)
            else { return Meta(uid: nil, rev: 0, dirty: false) }
            return m
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.metaKey) }
    }

    // MARK: Session
    private func validSession() async throws -> AuthSession {
        guard var s = session else { throw SupabaseError(status: 401, code: nil, message: "signed out") }
        if s.expiresAt - Date().timeIntervalSince1970 < 60 {
            s = try await api.refresh(s)
            session = s
            Keychain.save(s)
        }
        return s
    }

    private func adoptSession(_ s: AuthSession, greet: Greeting?) {
        let changed = session?.userId != s.userId
        session = s
        Keychain.save(s)
        UserDefaults.standard.removeObject(forKey: Self.guestKey)
        showAuth = false
        pendingGreet = greet
        if changed { Task { await pull() } }
    }

    // MARK: Auth actions (used by AuthView)
    func signIn(email: String, password: String) async throws {
        let s = try await api.signIn(email: email, password: password)
        adoptSession(s, greet: .back(""))
    }
    /// true = signed in right away, false = confirmation email sent
    func signUp(email: String, password: String) async throws -> Bool {
        guard let s = try await api.signUp(email: email, password: password) else { return false }
        adoptSession(s, greet: nil)
        return true
    }
    func recover(email: String) async throws { try await api.recover(email: email) }
    func playAsGuest() {
        UserDefaults.standard.set(true, forKey: Self.guestKey)
        showAuth = false
    }

    /// Returns false if there are unsynced changes and `force` is false (the UI asks first).
    func signOut(force: Bool) async -> Bool {
        guard let s = session else { return true }
        pushTask?.cancel()
        if meta.dirty { await push() }
        if meta.dirty && !force { return false }
        await api.signOut(s)
        session = nil
        Keychain.clear()
        UserDefaults.standard.removeObject(forKey: Self.metaKey)
        store.replaceState(SaveState())
        status = .idle
        showAuth = true
        return true
    }

    // MARK: Sync
    func onSave() {
        guard let s = session else { return }
        saveSeq += 1
        var m = meta
        if m.uid == s.userId && !m.dirty { m.dirty = true; meta = m }
        schedulePush(after: 1.5)
    }

    private func schedulePush(after seconds: Double) {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    func push() async {
        guard session != nil, !pushing else { return }
        let m = meta
        guard m.uid == session?.userId, m.dirty else { return }
        pushing = true
        status = .syncing
        let seq = saveSeq
        let data = store.state
        do {
            let s = try await validSession()
            let newRev: Int?
            if m.rev == 0 { newRev = try await api.insertSave(s, data: data) }
            else { newRev = try await api.updateSave(s, data: data, rev: m.rev) }
            pushing = false
            guard let rev = newRev else { await pull(); return }  // another device saved first
            guard meta.uid == s.userId else { return }             // signed out meanwhile
            meta = Meta(uid: s.userId, rev: rev, dirty: saveSeq != seq)
            if saveSeq != seq { await push() } else { status = .synced }
        } catch {
            pushing = false
            status = (error as? SupabaseError)?.isNetwork == true ? .offline : .error
            schedulePush(after: 30)
        }
    }

    /// Looks for changes from other devices: on launch, when the app becomes active, and every 30 s.
    func pullIfStale(minInterval: TimeInterval = 5) {
        guard session != nil, !pushing, conflict == nil, Date().timeIntervalSince(lastPull) > minInterval else { return }
        if meta.dirty { Task { await push() }; return }
        Task { await pull() }
    }

    func pull() async {
        guard !pulling else { return }
        pulling = true
        defer { pulling = false; maybeGreet() }
        lastPull = Date()
        guard session != nil else { return }
        status = .syncing
        do {
            let s = try await validSession()
            let row = try await api.fetchSave(s)
            guard session?.userId == s.userId else { return }
            let m = meta
            let local = store.state
            if let other = m.uid, other != s.userId {
                // The cache belongs to another account: never mix it in
                if let row { adopt(row) } else {
                    store.replaceState(SaveState())
                    meta = Meta(uid: s.userId, rev: 0, dirty: true)
                    pulling = false; await push()
                }
                return
            }
            guard let row else {
                // New account: the local save (guest or empty) becomes the first cloud save
                pendingGreet = .welcome
                meta = Meta(uid: s.userId, rev: 0, dirty: true)
                pulling = false; await push()
                return
            }
            if m.uid == s.userId {
                if row.rev == m.rev {
                    if m.dirty { pulling = false; await push() } else { status = .synced }
                    return
                }
                if !m.dirty || local == row.data { adopt(row) } else { askConflict(row) }
                return
            }
            // A guest save meets an account that already has a save
            if local.isEmpty || local == row.data { adopt(row) } else { askConflict(row) }
        } catch {
            if let e = error as? SupabaseError,
               e.status == 401 || (e.status == 400 && (e.code ?? "").contains("refresh_token")) {
                // Session is gone for good; keep the local save and ask to sign in again
                session = nil; Keychain.clear(); showAuth = true; status = .idle; return
            }
            status = (error as? SupabaseError)?.isNetwork == true ? .offline : .error
        }
    }

    private func adopt(_ row: CloudRow) {
        store.replaceState(row.data)
        meta = Meta(uid: session?.userId, rev: row.rev, dirty: false)
        status = .synced
    }

    private func askConflict(_ row: CloudRow) {
        status = .idle
        conflict = Conflict(row: row)
    }

    func resolveConflict(useCloud: Bool) {
        guard let c = conflict, let s = session else { return }
        conflict = nil
        if useCloud { adopt(c.row) } else {
            meta = Meta(uid: s.userId, rev: c.row.rev, dirty: true)
            Task { await push() }
        }
        maybeGreet()
    }

    private func maybeGreet() {
        guard conflict == nil, let g = pendingGreet else { return }
        pendingGreet = nil
        switch g {
        case .welcome: greeting = .welcome
        case .back: greeting = .back(store.state.heroName)
        }
    }
}

/// The login session lives in the Keychain, not in the save.
enum Keychain {
    private static let service = "com.hireloot.session"
    private static let account = "supabase"
    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    static func save(_ s: AuthSession) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        SecItemDelete(base as CFDictionary)
        var q = base
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
    static func load() -> AuthSession? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: d)
    }
    static func clear() { SecItemDelete(base as CFDictionary) }
}
