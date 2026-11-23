import Foundation

/// Zero-permission, zero-network local Google account detector.
enum AccountDetector {
    private static let legacyTokenMap: [Int: String] = [
        2: "second-standalone-oauth-token",
        3: "thirdx-standalone-oauth-token",
        4: "fourth-standalone-oauth-token",
        5: "fifthx-standalone-oauth-token",
        6: "sixthx-standalone-oauth-token",
        7: "sevent-standalone-oauth-token",
    ]

    static func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return email }
        let local = email[..<atIndex]
        let domain = email[email.index(after: atIndex)...]
        return "\(local.prefix(min(2, local.count)))***@\(domain)"
    }

    static func hasActiveCredential(for item: ManagedInstance, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let geminiDir = homeDirectory.appendingPathComponent(".gemini")
        var candidates: [String] = []
        if item.isOriginal || item.index == 1 {
            candidates.append("jetski-standalone-oauth-token")
        } else {
            if let legacy = legacyTokenMap[item.index] { candidates.append(legacy) }
            candidates.append(String(format: "ag%04d-standalone-oauth-token", item.index))
        }
        let fm = FileManager.default
        return candidates.contains { file in
            let path = geminiDir.appendingPathComponent(file).path
            guard fm.fileExists(atPath: path),
                  let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = (attrs[.size] as? NSNumber)?.int64Value else { return false }
            return size > 0
        }
    }

    static func detect(for item: ManagedInstance, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> InstanceAccountInfo {
        guard hasActiveCredential(for: item, homeDirectory: homeDirectory) else { return .unauthenticated }

        var foundEmail = ""
        if let data = try? Data(contentsOf: item.userDataURL.appendingPathComponent("app_storage.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["agy.onboarding.lastLoginUsername", "jetski.onboarding.lastLoginUsername"] {
                if let raw = (json[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                    foundEmail = raw
                    break
                }
            }
        }
        if foundEmail.isEmpty && item.isOriginal,
           let data = try? Data(contentsOf: homeDirectory.appendingPathComponent(".gemini/google_accounts.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = (json["active"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !active.isEmpty {
            foundEmail = active
        }
        return InstanceAccountInfo(email: foundEmail.isEmpty ? "已授权独立账号" : foundEmail, isLoggedIn: true)
    }

    static func detectAll(for instances: [ManagedInstance], homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String: InstanceAccountInfo] {
        Dictionary(uniqueKeysWithValues: instances.map { ($0.id, detect(for: $0, homeDirectory: homeDirectory)) })
    }
}
