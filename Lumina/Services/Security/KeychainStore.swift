import Foundation
import Security

/// Minimal Keychain wrapper for LLM API keys — one slot per provider. Keys
/// never touch the SwiftData store, UserDefaults, iCloud, or the repo.
///
/// Production note: for an App Store build you'd typically proxy LLM calls
/// through your own backend rather than shipping a user-entered key — but for a
/// personal vault, Keychain-stored keys called directly are appropriate.
struct KeychainStore {
    static let shared = KeychainStore()
    private let service = "com.cscottgraham.lumina.secrets"

    /// One Keychain account per provider.
    enum KeyAccount: String {
        case claude = "anthropic_api_key"
        case grok = "xai_api_key"
    }

    func saveAPIKey(_ key: String, account: KeyAccount = .claude) {
        let data = Data(key.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    func apiKey(account: KeyAccount = .claude) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    func deleteAPIKey(account: KeyAccount = .claude) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasKey(account: KeyAccount) -> Bool { apiKey(account: account) != nil }

    /// Legacy convenience (Claude slot) — existing call sites.
    var hasAPIKey: Bool { apiKey(account: .claude) != nil }
}
