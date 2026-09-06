import Foundation

struct SupabaseSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct SupabaseUser: Codable, Sendable {
    let id: String
    let email: String?
}

struct SupabaseSignUpResponse: Codable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }

    var session: SupabaseSession? {
        guard
            let accessToken,
            let refreshToken,
            let tokenType,
            let expiresIn,
            let user
        else {
            return nil
        }

        return SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            user: user
        )
    }
}

enum SupabaseRESTError: Error, LocalizedError {
    case invalidResponse
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "网络响应无效"
        case let .http(code, message):
            if let message, !message.isEmpty {
                let pretty = SupabaseRESTError.humanReadableMessage(from: message)
                return "请求失败(\(code)): \(pretty)"
            }
            return "请求失败(\(code))"
        }
    }

    private static func humanReadableMessage(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return trimmed }

        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            let errorCode = (json["error_code"] as? String) ?? (json["code"] as? String)
            let msg = (json["msg"] as? String)
                ?? (json["message"] as? String)
                ?? (json["error_description"] as? String)
                ?? (json["error"] as? String)

            if errorCode == "email_not_confirmed" || msg == "Email not confirmed" {
                return "邮箱未验证：去邮箱里点确认链接后再登录（或在 Supabase Auth 设置里关闭邮箱验证）。"
            }

            if errorCode == "over_email_send_rate_limit" || msg?.localizedCaseInsensitiveContains("rate limit") == true {
                return "确认邮件发送太频繁了：Supabase 暂时限流，请稍等几分钟再试，或先在 Auth 设置里关闭邮箱确认。"
            }

            if
                errorCode == "bad_oauth_callback"
                    || errorCode == "validation_failed"
                    || msg?.localizedCaseInsensitiveContains("redirect") == true
                    || msg?.localizedCaseInsensitiveContains("not allowed") == true
                    || msg?.localizedCaseInsensitiveContains("not supported") == true
            {
                return "回调地址未允许：去 Supabase 的 Authentication → URL Configuration → Redirect URLs 添加 voicesale://auth-callback。"
            }

            if msg?.localizedCaseInsensitiveContains("already registered") == true {
                return "这个邮箱已经注册过了，请直接登录或使用找回密码。"
            }

            if msg?.localizedCaseInsensitiveContains("password") == true {
                return "密码不符合要求，请换一个至少 6 位的密码。"
            }

            if let msg, let errorCode, !errorCode.isEmpty {
                return "\(errorCode): \(msg)"
            }
            if let msg, !msg.isEmpty { return msg }
        }

        return trimmed
    }
}

final class SupabaseREST: @unchecked Sendable {
    private let baseURL: URL
    private let anonKey: String
    private let urlSession: URLSession

    init(baseURL: URL = SupabaseConfig.url, anonKey: String = SupabaseConfig.anonKey, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.urlSession = urlSession
    }

    func signUp(email: String, password: String, redirectTo: String = SupabaseConfig.authCallbackURL) async throws -> SupabaseSignUpResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/signup"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "redirect_to", value: redirectTo)]
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        let payload = ["email": email, "password": password]
        return try await jsonRequest(url: url, method: "POST", bearerToken: nil, body: payload)
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        let payload = ["email": email, "password": password]
        return try await jsonRequest(url: url, method: "POST", bearerToken: nil, body: payload)
    }

    func sendPasswordReset(email: String, redirectTo: String = SupabaseConfig.authCallbackURL) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/recover"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "redirect_to", value: redirectTo)]
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        let payload = ["email": email]
        _ = try await rawRequest(url: url, method: "POST", bearerToken: nil, body: payload, extraHeaders: [
            "Content-Type": "application/json",
        ])
    }

    func refreshSession(refreshToken: String) async throws -> SupabaseSession {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        let payload = ["refresh_token": refreshToken]
        return try await jsonRequest(url: url, method: "POST", bearerToken: nil, body: payload)
    }

    func signOut(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/v1/logout")
        _ = try await rawRequest(url: url, method: "POST", bearerToken: accessToken, body: Optional<Int>.none as Int?)
    }

    func user(accessToken: String) async throws -> SupabaseUser {
        let url = baseURL.appendingPathComponent("auth/v1/user")
        return try await jsonRequest(url: url, method: "GET", bearerToken: accessToken, body: Optional<Int>.none as Int?)
    }

    func updatePassword(_ password: String, accessToken: String) async throws -> SupabaseUser {
        let url = baseURL.appendingPathComponent("auth/v1/user")
        let payload = ["password": password]
        return try await jsonRequest(url: url, method: "PUT", bearerToken: accessToken, body: payload)
    }

    func insertRow<T: Codable>(_ table: String, row: T, accessToken: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("rest/v1/\(table)")
        return try await rawRequest(url: url, method: "POST", bearerToken: accessToken, body: row, extraHeaders: [
            "Prefer": "return=representation",
        ])
    }

    func updateRow<T: Codable>(_ table: String, match: [String: String], patch: T, accessToken: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        _ = try await rawRequest(url: url, method: "PATCH", bearerToken: accessToken, body: patch, extraHeaders: [
            "Prefer": "return=minimal",
        ])
    }

    /// Invokes an authenticated Edge Function. The caller's JWT is forwarded so
    /// the function can enforce ownership before touching private audio.
    func invokeFunction<Body: Encodable>(_ name: String, body: Body, accessToken: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("functions/v1/\(name)")
        return try await rawRequest(url: url, method: "POST", bearerToken: accessToken, body: body, extraHeaders: [
            "Content-Type": "application/json",
        ])
    }

    /// Reads rows through PostgREST using the current user's RLS policies.
    func selectRows(_ table: String, match: [String: String], accessToken: String) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        guard let url = components?.url else { throw SupabaseRESTError.invalidResponse }
        return try await rawRequest(url: url, method: "GET", bearerToken: accessToken)
    }

    func uploadObject(bucket: String, path: String, data: Data, contentType: String, accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("storage/v1/object/\(bucket)/\(path)")
        _ = try await rawRequest(url: url, method: "POST", bearerToken: accessToken, bodyData: data, extraHeaders: [
            "Content-Type": contentType,
            "x-upsert": "true",
        ])
    }

    func uploadObject(bucket: String, path: String, fileURL: URL, contentType: String, accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("storage/v1/object/\(bucket)/\(path)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await urlSession.upload(for: request, fromFile: fileURL)
        guard let http = response as? HTTPURLResponse else { throw SupabaseRESTError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseRESTError.http(http.statusCode, nil)
        }
    }

    private func jsonRequest<Response: Decodable, Body: Encodable>(
        url: URL,
        method: String,
        bearerToken: String?,
        body: Body
    ) async throws -> Response {
        let data = try await rawRequest(url: url, method: method, bearerToken: bearerToken, body: body, extraHeaders: [
            "Content-Type": "application/json",
        ])
        let decoder = JSONDecoder()
        return try decoder.decode(Response.self, from: data)
    }

    private func rawRequest<Body: Encodable>(
        url: URL,
        method: String,
        bearerToken: String?,
        body: Body,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(body)
        return try await rawRequest(url: url, method: method, bearerToken: bearerToken, bodyData: data, extraHeaders: extraHeaders)
    }

    private func rawRequest(
        url: URL,
        method: String,
        bearerToken: String?,
        bodyData: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseRESTError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw SupabaseRESTError.http(http.statusCode, message)
        }
        return data
    }
}
