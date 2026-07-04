import Foundation
import Security

/// Minimal Keychain wrapper for the Claude API key. The key never touches the
/// SwiftData store, UserDefaults, or the repo.
///
/// Production note: for an App Store build you'd typically proxy Claude calls
/// through your own backend rather than shipping a user-entered key — but for a
/// personal vault, a Keychain-stored key called directly is appropriate.
struct KeychainStore {
    static let shared = KeychainStore()
    private let service = "com.lumina.app.secrets"
    private let account = "anthropic_api_key"

    func saveAPIKey(_ key: String) {
        let data = Data(key.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    func apiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    var hasAPIKey: Bool { apiKey() != nil }
}
