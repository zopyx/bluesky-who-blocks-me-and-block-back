import SwiftUI

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            loadCurrentBundle()
        }
    }

    private var bundle: [String: String] = [:]
    private var allBundles: [String: [String: String]] = [:]

    let supportedLanguages: [(code: String, displayName: String)] = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("it", "Italiano"),
        ("ja", "日本語"),
        ("zh", "中文"),
    ]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedLanguage")
        let preferred = Locale.current.language.languageCode?.identifier
        self.currentLanguage = saved ?? (preferred != nil && ["en","de","fr","it","ja","zh"].contains(preferred!) ? preferred! : "en")
        loadAll()
        loadCurrentBundle()
    }

    func localized(_ key: String) -> String {
        bundle[key] ?? allBundles["en"]?[key] ?? key
    }

    func localizedPlural(_ key: String, count: Int) -> String {
        let language = currentLanguage
        let pluralKey: String
        if language == "en" || language == "de" || language == "fr" || language == "it" {
            pluralKey = count == 1 ? "\(key)_one" : "\(key)_other"
        } else {
            // Default to English-style plural rules
            pluralKey = count == 1 ? "\(key)_one" : "\(key)_other"
        }
        let format = bundle[pluralKey] ?? allBundles["en"]?[pluralKey] ?? bundle[key] ?? allBundles["en"]?[key] ?? key
        return format.replacingOccurrences(of: "{count}", with: "\(count)")
    }

    private func loadAll() {
        for lang in ["en", "de", "fr", "it", "ja", "zh"] {
            guard let url = Bundle.main.url(forResource: lang, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else {
                allBundles[lang] = [:]
                continue
            }
            allBundles[lang] = dict
        }
    }

    private func loadCurrentBundle() {
        bundle = allBundles[currentLanguage] ?? allBundles["en"] ?? [:]
        objectWillChange.send()
    }
}

@MainActor
func loc(_ key: String) -> String {
    LocalizationManager.shared.localized(key)
}
