import Foundation

enum SupabaseConfig {
    static let authCallbackURL = "voicesale://auth-callback"

    static var url: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            raw != "__REPLACE_ME__",
            let url = URL(string: raw)
        else {
            preconditionFailure("Missing SUPABASE_URL in Info.plist")
        }
        return url
    }

    static var anonKey: String {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            key != "__REPLACE_ME__",
            !key.isEmpty
        else {
            preconditionFailure("Missing SUPABASE_ANON_KEY in Info.plist")
        }
        return key
    }
}
