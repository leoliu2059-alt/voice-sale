import Foundation

enum AuthActionResult {
    case signedIn
    case confirmationSent
    case failed
}

@MainActor
final class SupabaseAuthStore: ObservableObject {
    @Published private(set) var session: SupabaseSession?
    @Published var lastErrorMessage: String?
    @Published var lastInfoMessage: String?
    @Published var isPasswordResetPresented = false

    private let api: SupabaseREST
    private let storage = StoredSession()

    init(api: SupabaseREST = SupabaseREST()) {
        self.api = api
        self.session = storage.load()
    }

    var isSignedIn: Bool { session != nil }
    var userId: String? { session?.user.id }
    var userEmail: String? { session?.user.email }
    var accessToken: String? { session?.accessToken }

    func signUp(email: String, password: String) async -> AuthActionResult {
        do {
            let response = try await api.signUp(email: email, password: password)
            if let session = response.session {
                storage.save(session)
                self.session = session
                lastErrorMessage = nil
                lastInfoMessage = nil
                return .signedIn
            }

            lastErrorMessage = nil
            lastInfoMessage = "注册成功。请打开邮箱确认邮件，点确认后会回到语销镜。"
            return .confirmationSent
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastInfoMessage = nil
            return .failed
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        do {
            let session = try await api.signIn(email: email, password: password)
            storage.save(session)
            self.session = session
            lastErrorMessage = nil
            lastInfoMessage = nil
            return true
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastInfoMessage = nil
            return false
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        do {
            try await api.sendPasswordReset(email: email)
            lastErrorMessage = nil
            lastInfoMessage = "找回密码邮件已发送。请去邮箱点击链接，然后会回到语销镜设置新密码。"
            return true
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastInfoMessage = nil
            return false
        }
    }

    func updatePassword(_ password: String) async -> Bool {
        guard let token = session?.accessToken else {
            lastErrorMessage = "密码重置链接已失效，请重新发送找回密码邮件。"
            lastInfoMessage = nil
            return false
        }

        do {
            let user = try await api.updatePassword(password, accessToken: token)
            if let current = session {
                let updated = SupabaseSession(
                    accessToken: current.accessToken,
                    refreshToken: current.refreshToken,
                    tokenType: current.tokenType,
                    expiresIn: current.expiresIn,
                    user: user
                )
                storage.save(updated)
                session = updated
            }
            lastErrorMessage = nil
            lastInfoMessage = "密码已更新。"
            isPasswordResetPresented = false
            return true
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastInfoMessage = nil
            return false
        }
    }

    @discardableResult
    func handleAuthCallback(_ url: URL) async -> Bool {
        guard url.scheme == "voicesale", url.host == "auth-callback" else {
            return false
        }

        let params = callbackParameters(from: url)
        if let error = params["error_description"] ?? params["error"] {
            lastErrorMessage = error.removingPercentEncoding ?? error
            lastInfoMessage = nil
            return false
        }

        guard
            let accessToken = params["access_token"],
            let refreshToken = params["refresh_token"]
        else {
            lastErrorMessage = "邮箱已确认。请回到 App 后用邮箱和密码登录。"
            lastInfoMessage = nil
            return false
        }

        do {
            let user = try await api.user(accessToken: accessToken)
            let session = SupabaseSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: params["token_type"] ?? "bearer",
                expiresIn: Int(params["expires_in"] ?? "") ?? 3600,
                user: user
            )
            storage.save(session)
            self.session = session
            lastErrorMessage = nil
            if params["type"] == "recovery" {
                lastInfoMessage = "请设置新密码。"
                isPasswordResetPresented = true
            } else {
                lastInfoMessage = "邮箱已确认，已登录。"
            }
            return true
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastInfoMessage = nil
            return false
        }
    }

    func restoreOrRefreshIfNeeded() async {
        guard let current = session else { return }
        // Minimal: refresh on app launch if possible; if refresh fails, clear session.
        do {
            let refreshed = try await api.refreshSession(refreshToken: current.refreshToken)
            storage.save(refreshed)
            session = refreshed
        } catch {
            storage.clear()
            session = nil
        }
    }

    func signOut() async {
        guard let token = session?.accessToken else {
            storage.clear()
            session = nil
            return
        }
        do {
            try await api.signOut(accessToken: token)
        } catch {
            // ignore network error on logout; still clear local session
        }
        storage.clear()
        session = nil
    }
}

private func callbackParameters(from url: URL) -> [String: String] {
    var params: [String: String] = [:]

    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        for item in components.queryItems ?? [] {
            params[item.name] = item.value
        }
    }

    if let fragment = url.fragment {
        var components = URLComponents()
        components.query = fragment
        for item in components.queryItems ?? [] {
            params[item.name] = item.value
        }
    }

    return params
}

private struct StoredSession {
    private let service = "VoiceSaleSupabaseSession"
    private let account = "default"

    func load() -> SupabaseSession? {
        do {
            guard let data = try KeychainStore.get(service: service, account: account) else { return nil }
            return try JSONDecoder().decode(SupabaseSession.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ session: SupabaseSession) {
        do {
            let data = try JSONEncoder().encode(session)
            try KeychainStore.set(data, service: service, account: account)
        } catch {
            // ignore
        }
    }

    func clear() {
        KeychainStore.delete(service: service, account: account)
    }
}
