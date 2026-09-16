import Foundation

/// Immutable presentation settings for library-owned text and numeric formatting.
///
/// `languageIdentifier` selects a message table (`en`, `ru`, or a regional tag
/// that resolves to one of those). `localeIdentifier` affects numbers only.
/// Existing `ConnectionMonitor` initializers use ``english``.
public struct ReportLocalization: Equatable, Sendable {
    /// BCP-47 language tag used to choose message tables.
    public var languageIdentifier: String
    /// Locale identifier used only for decimal and unit formatting.
    public var localeIdentifier: String

    /// Creates a configuration. An omitted format locale uses the documented
    /// default for the resolved language (`en_US_POSIX` or `ru_RU`).
    public init(languageIdentifier: String, localeIdentifier: String? = nil) {
        self.languageIdentifier = languageIdentifier
        let resolved = MessageCatalog.resolveLanguage(languageIdentifier)
        self.localeIdentifier = localeIdentifier ?? Self.defaultLocaleIdentifier(for: resolved)
    }

    /// Deterministic English labels and POSIX numeric formatting.
    public static let english = ReportLocalization(languageIdentifier: "en", localeIdentifier: "en_US_POSIX")

    /// Russian labels and `ru_RU` numeric formatting.
    public static let russian = ReportLocalization(languageIdentifier: "ru", localeIdentifier: "ru_RU")

    /// Snapshots preferred languages once. Unsupported tags fall back to English.
    /// Tests inject `preferredLanguages` instead of reading the host OS.
    public static func system(
        preferredLanguages: [String] = Locale.preferredLanguages,
        localeIdentifier: String? = nil
    ) -> ReportLocalization {
        let language = MessageCatalog.pickLanguage(from: preferredLanguages)
        return ReportLocalization(languageIdentifier: language, localeIdentifier: localeIdentifier)
    }

    public static func defaultLocaleIdentifier(for language: String) -> String {
        MessageCatalog.resolveLanguage(language) == "ru" ? "ru_RU" : "en_US_POSIX"
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }
}

struct MessageCatalog: Sendable {
    var tables: [String: [String: String]]

    static let bundled: MessageCatalog = MessageCatalog(tables: MessageCatalog.loadBundledTables())

    private static let lock = NSLock()
    private static var override: MessageCatalog?

    static var current: MessageCatalog {
        lock.lock()
        defer { lock.unlock() }
        return override ?? bundled
    }

    static func withOverride<T>(_ catalog: MessageCatalog?, _ body: () throws -> T) rethrows -> T {
        lock.lock()
        let previous = override
        override = catalog
        lock.unlock()
        defer {
            lock.lock()
            override = previous
            lock.unlock()
        }
        return try body()
    }

    static let supportedLanguages: Set<String> = ["en", "ru"]
    static let missingEnglishFallback = "An error occurred."

    static func resolveLanguage(_ requested: String) -> String {
        let trimmed = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "en" }
        let normalized = trimmed.replacingOccurrences(of: "_", with: "-").lowercased()
        if supportedLanguages.contains(normalized) { return normalized }
        let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if supportedLanguages.contains(base) { return base }
        return "en"
    }

    static func pickLanguage(from preferred: [String]) -> String {
        for tag in preferred {
            let resolved = resolveLanguage(tag)
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            if normalized.isEmpty { continue }
            let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
            if supportedLanguages.contains(normalized) || supportedLanguages.contains(base) {
                return resolved
            }
        }
        return "en"
    }

    func string(key: String, language requested: String, arguments: [String] = []) -> String {
        let template = lookup(key: key, language: requested)
        return Self.applyPlaceholders(template, arguments: arguments)
    }

    func lookup(key: String, language requested: String) -> String {
        let language = Self.resolveLanguage(requested)
        if let value = tables[language]?[key], !value.isEmpty {
            return value
        }
        if language != "en", let value = tables["en"]?[key], !value.isEmpty {
            return value
        }
        return Self.missingEnglishFallback
    }

    func hasKey(_ key: String, language: String) -> Bool {
        let resolved = Self.resolveLanguage(language)
        if let value = tables[resolved]?[key], !value.isEmpty { return true }
        return false
    }

    static func applyPlaceholders(_ template: String, arguments: [String]) -> String {
        var result = ""
        var index = template.startIndex
        var sequential = 0
        while index < template.endIndex {
            if template[index] == "%" {
                let fromPercent = template[index...]
                if fromPercent.hasPrefix("%%") {
                    result.append("%")
                    index = template.index(index, offsetBy: 2)
                    continue
                }
                if let parsed = parsePlaceholder(template, from: index) {
                    let argumentIndex = parsed.explicitIndex ?? sequential
                    if parsed.explicitIndex == nil {
                        sequential += 1
                    }
                    if argumentIndex < arguments.count {
                        result.append(arguments[argumentIndex])
                    } else {
                        result.append(String(template[index..<parsed.end]))
                    }
                    index = parsed.end
                    continue
                }
            }
            result.append(template[index])
            index = template.index(after: index)
        }
        return result
    }

    private struct ParsedPlaceholder {
        var explicitIndex: Int?
        var end: String.Index
    }

    private static func parsePlaceholder(_ template: String, from start: String.Index) -> ParsedPlaceholder? {
        let cursor = template.index(after: start)
        guard cursor < template.endIndex else { return nil }
        var digits = ""
        var scan = cursor
        while scan < template.endIndex, template[scan].isNumber {
            digits.append(template[scan])
            scan = template.index(after: scan)
        }
        if !digits.isEmpty, scan < template.endIndex, template[scan] == "$" {
            scan = template.index(after: scan)
            guard scan < template.endIndex, template[scan] == "@" else { return nil }
            let end = template.index(after: scan)
            guard let value = Int(digits), value >= 1 else { return nil }
            return ParsedPlaceholder(explicitIndex: value - 1, end: end)
        }
        if template[cursor] == "@" {
            return ParsedPlaceholder(explicitIndex: nil, end: template.index(after: cursor))
        }
        return nil
    }

    private static func loadBundledTables() -> [String: [String: String]] {
        var tables: [String: [String: String]] = [:]
        for language in supportedLanguages {
            tables[language] = loadTable(language: language)
        }
        return tables
    }

    private static func loadTable(language: String) -> [String: String] {
        if let url = Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(language).lproj"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
            return dictionary
        }
        if let lproj = Bundle.module.url(forResource: language, withExtension: "lproj"),
           let bundle = Bundle(url: lproj),
           let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
            return dictionary
        }
        if let lprojPath = Bundle.module.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: lprojPath) {
            let stringsPath = bundle.path(forResource: "Localizable", ofType: "strings")
            if let stringsPath,
               let dictionary = NSDictionary(contentsOfFile: stringsPath) as? [String: String] {
                return dictionary
            }
        }
        return [:]
    }
}

enum L10n {
    static func text(_ key: String, _ localization: ReportLocalization, _ arguments: String...) -> String {
        MessageCatalog.current.string(key: key, language: localization.languageIdentifier, arguments: arguments)
    }

    static func milliseconds(_ seconds: TimeInterval, digits: Int, localization: ReportLocalization) -> String {
        let number = decimal(seconds * 1000, digits: digits, localization: localization)
        let unit = text("unit.milliseconds", localization)
        return "\(number) \(unit)"
    }

    static func decimal(_ value: Double, digits: Int, localization: ReportLocalization) -> String {
        let formatter = NumberFormatter()
        formatter.locale = localization.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }

    static func pathType(_ raw: String, localization: ReportLocalization) -> String {
        let key = "path.\(raw)"
        let catalog = MessageCatalog.current
        if catalog.hasKey(key, language: localization.languageIdentifier)
            || catalog.hasKey(key, language: "en") {
            return catalog.string(key: key, language: localization.languageIdentifier)
        }
        return raw
    }

    static func failureSummary(_ metadata: ProbeFailureMetadata, localization: ReportLocalization) -> String {
        let key: String
        if metadata.stage == .traceroute {
            key = "trace.\(metadata.reasonCode)"
        } else {
            key = "failure.\(metadata.reasonCode)"
        }
        return MessageCatalog.current.string(
            key: key,
            language: localization.languageIdentifier,
            arguments: metadata.arguments
        )
    }

    static func englishCompatibilityMessage(_ metadata: ProbeFailureMetadata) -> String {
        failureSummary(metadata, localization: .english)
    }
}

enum ProbeReason {
    static let missingHost = "missing_host"
    static let dnsFailed = "dns_failed"
    static let timeoutBeforeTCP = "timeout_before_tcp"
    static let timeoutBeforeHTTP = "timeout_before_http"
    static let tcpFailed = "tcp_failed"
    static let noHTTPStatus = "no_http_status"
    static let nonHTTPResponse = "non_http_response"
    static let urlTimeout = "url_timeout"
    static let urlDNS = "url_dns"
    static let urlConnect = "url_connect"
    static let urlOffline = "url_offline"
    static let urlCancelled = "url_cancelled"
    static let urlTLS = "url_tls"
    static let urlGeneric = "url_generic"
    static let socket = "socket"
    static let tracerouteDNS = "dns"
    static let ipv4Only = "ipv4_only"
}
