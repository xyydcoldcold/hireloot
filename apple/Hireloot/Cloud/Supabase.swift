import Foundation

/// Minimal Supabase client (Auth + one PostgREST table) over URLSession, so the app needs no packages.
/// Same project and public key as the web version's config.js.
enum SupabaseConfig {
    static let url = URL(string: "https://jlxulkyekuharwokjlsu.supabase.co")!
    /// Publishable (public) key: safe to ship in the app. Never put a secret/service_role key here.
    static let key = "sb_publishable_Ft8UYGT_O-IhC3_HbwoJug_y2OvxG6n"
    /// Where confirmation / password-reset emails send the player back to.
    static let site = "https://hireloot.com/"
}

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var userId: String
    var email: String
}

struct SupabaseError: Error, LocalizedError {
    var status: Int
    var code: String?
    var message: String
    var errorDescription: String? { message }
    var isNetwork: Bool { status == -1 }
}

struct CloudRow { let data: SaveState; let rev: Int }

final class SupabaseClient {
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()

    // MARK: Auth
    func signIn(email: String, password: String) async throws -> AuthSession {
        let json = try await request("auth/v1/token", query: [("grant_type", "password")], method: "POST",
                                     body: ["email": email, "password": password], token: nil)
        return try parseSession(json)
    }

    /// Returns a session when email confirmation is off, nil when a confirmation email was sent.
    func signUp(email: String, password: String) async throws -> AuthSession? {
        let json = try await request("auth/v1/signup", query: [("redirect_to", SupabaseConfig.site)], method: "POST",
                                     body: ["email": email, "password": password], token: nil)
        guard let obj = json as? [String: Any] else { return nil }
        if obj["access_token"] != nil { return try parseSession(obj) }
        // With confirmation on, an already-registered email comes back as a user with no identities
        let user = (obj["user"] as? [String: Any]) ?? obj
        if let ids = user["identities"] as? [Any], ids.isEmpty {
            throw SupabaseError(status: 400, code: "user_already_exists", message: "User already registered")
        }
        return nil
    }

    func recover(email: String) async throws {
        _ = try await request("auth/v1/recover", query: [("redirect_to", SupabaseConfig.site)], method: "POST",
                              body: ["email": email], token: nil)
    }

    func refresh(_ s: AuthSession) async throws -> AuthSession {
        let json = try await request("auth/v1/token", query: [("grant_type", "refresh_token")], method: "POST",
                                     body: ["refresh_token": s.refreshToken], token: nil)
        return try parseSession(json)
    }

    /// Deletes the signed-in user and (by cascade) their save. Needs `delete_account()` from supabase/schema.sql.
    func deleteAccount(_ s: AuthSession) async throws {
        _ = try await request("rest/v1/rpc/delete_account", query: [], method: "POST", body: [String: Any](), token: s.accessToken)
    }

    func signOut(_ s: AuthSession) async {
        _ = try? await request("auth/v1/logout", query: [("scope", "local")], method: "POST", body: [:], token: s.accessToken)
    }

    private func parseSession(_ json: Any) throws -> AuthSession {
        guard let o = json as? [String: Any], let at = o["access_token"] as? String, let rt = o["refresh_token"] as? String,
              let user = o["user"] as? [String: Any], let uid = user["id"] as? String else {
            throw SupabaseError(status: 500, code: nil, message: "Unexpected auth response")
        }
        let expIn = (o["expires_in"] as? Double) ?? 3600
        let expAt = (o["expires_at"] as? Double) ?? (Date().timeIntervalSince1970 + expIn)
        return AuthSession(accessToken: at, refreshToken: rt, expiresAt: expAt, userId: uid, email: user["email"] as? String ?? "")
    }

    // MARK: saves table
    func fetchSave(_ s: AuthSession) async throws -> CloudRow? {
        let json = try await request("rest/v1/saves", query: [("select", "data,rev"), ("user_id", "eq.\(s.userId)")],
                                     method: "GET", body: nil, token: s.accessToken)
        guard let rows = json as? [[String: Any]], let row = rows.first else { return nil }
        let rev = (row["rev"] as? Int) ?? Int((row["rev"] as? Double) ?? 0)
        let dataJSON = try JSONSerialization.data(withJSONObject: row["data"] ?? [:])
        return CloudRow(data: SaveState.decodeStrict(dataJSON) ?? SaveState(), rev: rev)
    }

    /// First upload. Returns the new rev, or nil when a row already exists (treat as conflict).
    func insertSave(_ s: AuthSession, data: SaveState) async throws -> Int? {
        do {
            let json = try await request("rest/v1/saves", query: [("select", "rev")], method: "POST",
                                         body: ["user_id": s.userId, "data": data.jsonObject(), "rev": 1],
                                         token: s.accessToken, prefer: "return=representation")
            return ((json as? [[String: Any]])?.first?["rev"] as? Int)
        } catch let e as SupabaseError where e.code == "23505" || e.status == 409 {
            return nil
        }
    }

    /// Optimistic update: only succeeds if the cloud is still at `rev`. Returns the new rev, or nil if
    /// another device saved first.
    func updateSave(_ s: AuthSession, data: SaveState, rev: Int) async throws -> Int? {
        let json = try await request("rest/v1/saves", query: [("user_id", "eq.\(s.userId)"), ("rev", "eq.\(rev)"), ("select", "rev")],
                                     method: "PATCH", body: ["data": data.jsonObject(), "rev": rev + 1],
                                     token: s.accessToken, prefer: "return=representation")
        return ((json as? [[String: Any]])?.first?["rev"] as? Int)
    }

    // MARK: HTTP
    private func request(_ path: String, query: [(String, String)], method: String, body: Any?, token: String?,
                         prefer: String? = nil) async throws -> Any {
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token ?? SupabaseConfig.key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: req) }
        catch { throw SupabaseError(status: -1, code: nil, message: error.localizedDescription) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        var json: Any = [String: Any]()
        if !data.isEmpty, let parsed = try? JSONSerialization.jsonObject(with: data) { json = parsed }
        guard (200..<300).contains(status) else {
            let o = json as? [String: Any] ?? [:]
            let code = (o["error_code"] as? String) ?? (o["code"] as? String) ?? (o["code"] as? Int).map { String($0) } ?? (o["error"] as? String)
            let msg = (o["msg"] as? String) ?? (o["message"] as? String) ?? (o["error_description"] as? String) ?? "HTTP \(status)"
            throw SupabaseError(status: status, code: code, message: msg)
        }
        return json
    }
}
