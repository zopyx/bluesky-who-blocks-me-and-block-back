import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidStatus(OSStatus)
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .invalidStatus(let status):
            return "Keychain error: \(SecCopyErrorMessageString(status, nil) as? String ?? "Unknown error (\(status))")"
        case .conversionFailed:
            return "Failed to convert data"
        }
    }
}

protocol KeychainProtocol: Sendable {
    func saveAppPassword(_ password: String, for accountId: UUID) async throws
    func getAppPassword(for accountId: UUID) async throws -> String
    func deleteAppPassword(for accountId: UUID) async throws
    func saveAccessToken(_ token: String, for accountId: UUID) async throws
    func getAccessToken(for accountId: UUID) async throws -> String
    func deleteAccessToken(for accountId: UUID) async throws
    func deleteAllCredentials(for accountId: UUID) async throws
}

actor KeychainService: KeychainProtocol {
    static let shared = KeychainService()

    private init() {}

    // MARK: - App Password

    func saveAppPassword(_ password: String, for accountId: UUID) throws {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "app-password-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.passwords",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "app-password-\(accountId.uuidString)",
                kSecAttrService as String: "com.blueskymoderation.passwords"
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.invalidStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.invalidStatus(status)
        }
    }

    func getAppPassword(for accountId: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "app-password-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.passwords",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.invalidStatus(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionFailed
        }

        return password
    }

    func deleteAppPassword(for accountId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "app-password-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.passwords"
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }
    }

    // MARK: - Access Token

    func saveAccessToken(_ token: String, for accountId: UUID) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access-token-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.tokens",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "access-token-\(accountId.uuidString)",
                kSecAttrService as String: "com.blueskymoderation.tokens"
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.invalidStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.invalidStatus(status)
        }
    }

    func getAccessToken(for accountId: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access-token-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.tokens",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.invalidStatus(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionFailed
        }

        return token
    }

    func deleteAccessToken(for accountId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access-token-\(accountId.uuidString)",
            kSecAttrService as String: "com.blueskymoderation.tokens"
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }
    }

    // MARK: - Delete All for Account

    func deleteAllCredentials(for accountId: UUID) throws {
        try? deleteAppPassword(for: accountId)
        try? deleteAccessToken(for: accountId)
    }
}
