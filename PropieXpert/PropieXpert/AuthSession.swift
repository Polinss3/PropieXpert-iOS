import Foundation
import Security

@MainActor
final class AuthSession: ObservableObject {
    private static let tokenKey = "auth_token"

    @Published private(set) var token: String

    var isAuthenticated: Bool {
        !token.isEmpty
    }

    init() {
        let legacyToken = UserDefaults.standard.string(forKey: Self.tokenKey) ?? ""
        if !legacyToken.isEmpty {
            KeychainStore.set(legacyToken, forKey: Self.tokenKey)
            UserDefaults.standard.removeObject(forKey: Self.tokenKey)
        }

        token = KeychainStore.string(forKey: Self.tokenKey) ?? legacyToken
    }

    func login(token newToken: String) {
        token = newToken
        KeychainStore.set(newToken, forKey: Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
    }

    func logout() {
        token = ""
        KeychainStore.remove(forKey: Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
    }
}

enum KeychainStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.propiexpert.app"

    static func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func remove(forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
