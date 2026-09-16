import XCTest
@testable import SwiftNetPulse

final class LocalizationTests: XCTestCase {
    func testDefaultEnglishWhenOSPrefersRussian() {
        let localization = ReportLocalization.system(preferredLanguages: ["ru-RU", "ru"])
        XCTAssertEqual(ReportLocalization.english.languageIdentifier, "en")
        let catalog = MessageCatalog.current
        XCTAssertEqual(
            catalog.string(key: "report.title", language: ReportLocalization.english.languageIdentifier),
            "NETWORK DIAGNOSIS"
        )
        XCTAssertEqual(localization.languageIdentifier, "ru")
        XCTAssertEqual(
            catalog.string(key: "report.title", language: "en"),
            "NETWORK DIAGNOSIS"
        )
    }

    func testExplicitEnglishAndRussianTables() {
        XCTAssertEqual(L10n.text("report.title", .english), "NETWORK DIAGNOSIS")
        XCTAssertEqual(L10n.text("report.title", .russian), "СЕТЕВАЯ ДИАГНОСТИКА")
        XCTAssertEqual(L10n.text("error.empty_endpoints", .english), "ConnectionMonitor requires at least one endpoint")
        XCTAssertEqual(L10n.text("error.empty_endpoints", .russian), "ConnectionMonitor требует хотя бы один эндпоинт")
    }

    func testRegionalTagsResolveToSupportedBase() {
        XCTAssertEqual(MessageCatalog.resolveLanguage("ru-RU"), "ru")
        XCTAssertEqual(MessageCatalog.resolveLanguage("en-GB"), "en")
        XCTAssertEqual(L10n.text("report.finished", ReportLocalization(languageIdentifier: "ru-RU")), "ДИАГНОСТИКА ЗАВЕРШЕНА")
        XCTAssertEqual(L10n.text("report.finished", ReportLocalization(languageIdentifier: "en-GB")), "DIAGNOSIS FINISHED")
    }

    func testUnsupportedOrEmptyIdentifierFallsBackToEnglish() {
        XCTAssertEqual(MessageCatalog.resolveLanguage("de"), "en")
        XCTAssertEqual(MessageCatalog.resolveLanguage(""), "en")
        XCTAssertEqual(L10n.text("report.title", ReportLocalization(languageIdentifier: "zz")), "NETWORK DIAGNOSIS")
        XCTAssertEqual(L10n.text("report.title", ReportLocalization(languageIdentifier: "  ")), "NETWORK DIAGNOSIS")
    }

    func testSystemPreferencesSkipUnsupportedThenSelectRussian() {
        let localization = ReportLocalization.system(preferredLanguages: ["zz-XX", "ru-RU"])
        XCTAssertEqual(localization.languageIdentifier, "ru")
        XCTAssertEqual(L10n.text("report.title", localization), "СЕТЕВАЯ ДИАГНОСТИКА")
    }

    func testMissingRussianKeyFallsBackToEnglishWithoutExposingKey() {
        let catalog = MessageCatalog(tables: [
            "en": ["only.en": "English only"],
            "ru": [:],
        ])
        MessageCatalog.withOverride(catalog) {
            XCTAssertEqual(
                MessageCatalog.current.string(key: "only.en", language: "ru"),
                "English only"
            )
            XCTAssertFalse(MessageCatalog.current.string(key: "only.en", language: "ru").contains("only.en"))
        }
    }

    func testMissingEnglishKeyReturnsSafeFallback() {
        let catalog = MessageCatalog(tables: [
            "en": [:],
            "ru": ["ghost": "%1$@ %2$@"],
        ])
        MessageCatalog.withOverride(catalog) {
            let value = MessageCatalog.current.string(key: "ghost", language: "en", arguments: ["a", "b"])
            XCTAssertEqual(value, MessageCatalog.missingEnglishFallback)
            XCTAssertFalse(value.contains("%"))
            XCTAssertFalse(value.contains("ghost"))
        }
    }

    func testConcurrentEnglishAndRussianContextsDoNotLeak() {
        let english = ReportLocalization.english
        let russian = ReportLocalization.russian
        let lock = NSLock()
        var englishTitles: [String] = []
        var russianTitles: [String] = []
        DispatchQueue.concurrentPerform(iterations: 40) { index in
            let value: String
            if index.isMultiple(of: 2) {
                value = L10n.text("report.title", english)
                lock.lock()
                englishTitles.append(value)
                lock.unlock()
            } else {
                value = L10n.text("report.title", russian)
                lock.lock()
                russianTitles.append(value)
                lock.unlock()
            }
        }
        XCTAssertFalse(englishTitles.isEmpty)
        XCTAssertFalse(russianTitles.isEmpty)
        XCTAssertTrue(englishTitles.allSatisfy { $0 == "NETWORK DIAGNOSIS" })
        XCTAssertTrue(russianTitles.allSatisfy { $0 == "СЕТЕВАЯ ДИАГНОСТИКА" })
    }

    func testNumberedPlaceholdersCanBeReordered() {
        let catalog = MessageCatalog(tables: [
            "en": ["pair": "%1$@-%2$@"],
            "ru": ["pair": "%2$@/%1$@"],
        ])
        MessageCatalog.withOverride(catalog) {
            XCTAssertEqual(MessageCatalog.current.string(key: "pair", language: "en", arguments: ["A", "B"]), "A-B")
            XCTAssertEqual(MessageCatalog.current.string(key: "pair", language: "ru", arguments: ["A", "B"]), "B/A")
        }
    }

    func testConnectionMonitorErrorStaysEnglishByDefault() {
        XCTAssertEqual(
            ConnectionMonitorError.emptyEndpointList.errorDescription,
            "ConnectionMonitor requires at least one endpoint"
        )
        XCTAssertEqual(
            ConnectionMonitorError.emptyEndpointList.localizedDescription(using: .russian),
            "ConnectionMonitor требует хотя бы один эндпоинт"
        )
        XCTAssertEqual(
            ConnectionMonitorError.invalidMonitoringInterval.localizedDescription(using: .english),
            "Monitoring interval must be greater than zero"
        )
    }
}
