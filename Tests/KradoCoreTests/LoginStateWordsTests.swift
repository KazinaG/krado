import Foundation
import Testing
@testable import KradoCore

/// The menu shows the Launch at Login state as a word, so every state word
/// must be translated in both languages and On/Off must read differently.
@Suite("Launch at Login state words")
struct LoginStateWordsTests {
    private static func strings(_ language: String) -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }

    @Test(arguments: ["en", "ja"])
    func everyStateWordIsTranslated(language: String) {
        let table = Self.strings(language)
        for key in LoginRowPresentation.allStateTexts {
            #expect(!(table[key] ?? "").isEmpty, "\(language): missing \(key)")
        }
        #expect(table["On"] != table["Off"])
    }

    @Test func wording() {
        #expect(Self.strings("ja")["On"] == "オン")
        #expect(Self.strings("ja")["Off"] == "オフ")
        #expect(Self.strings("en")["On"] == "On")
        #expect(Self.strings("en")["Off"] == "Off")
    }
}
