import Foundation
import Security

/// Hardware-backed secure credential storage using iOS Keychain Services (Secure Enclave).
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    public static let defaultService = "com.carplaytv.credentials"

    private init() {}

    // MARK: - Save Operations

    /// Saves raw Data securely to Keychain.
    @discardableResult
    public func save(key: String, data: Data, service: String = KeychainHelper.defaultService) -> Bool {
        // Delete any existing item first to avoid duplicate item errors (errSecDuplicateItem)
        delete(key: key, service: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Accessible only when device is unlocked, and never migrates to other devices or iCloud backups
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Saves a String securely to Keychain.
    @discardableResult
    public func saveString(key: String, value: String, service: String = KeychainHelper.defaultService) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data, service: service)
    }

    // MARK: - Read Operations

    /// Reads raw Data from Keychain.
    public func read(key: String, service: String = KeychainHelper.defaultService) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    /// Reads a UTF-8 String from Keychain.
    public func readString(key: String, service: String = KeychainHelper.defaultService) -> String? {
        guard let data = read(key: key, service: service) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete Operations

    /// Deletes an item from Keychain.
    @discardableResult
    public func delete(key: String, service: String = KeychainHelper.defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Clears all credentials associated with the specified service.
    @discardableResult
    public func clearAll(service: String = KeychainHelper.defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
