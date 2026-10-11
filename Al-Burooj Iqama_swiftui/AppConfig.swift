import Foundation

enum AppConfig {
    /// Returns the API key from Secrets.plist under the key "API_KEY".
    /// - Note: In Debug, asserts if missing. In Release, returns an empty string to avoid crashing.
    static var apiKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let key = plist["API_KEY"] as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            assertionFailure("Missing API_KEY in Secrets.plist")
            return ""
        }
        return key
    }
}
