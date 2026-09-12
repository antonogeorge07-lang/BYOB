import XCTest
@testable import SimpleBrowser

final class PageContextExtractorTests: XCTestCase {
    func testParsesPageContextFromJavaScriptValue() throws {
        let context = try XCTUnwrap(PageContextExtractor.parse([
            "url": "https://example.com/page",
            "title": "Example page",
            "visibleText": "Visible content",
            "interactiveElements": [[
                "tag": "button",
                "label": "Save",
                "type": "submit"
            ]]
        ], fallbackURL: URL(string: "https://fallback.example")!))

        XCTAssertEqual(context.url.absoluteString, "https://example.com/page")
        XCTAssertEqual(context.title, "Example page")
        XCTAssertEqual(context.visibleText, "Visible content")
        XCTAssertEqual(context.interactiveElements, [
            InteractiveElement(tag: "button", label: "Save", href: nil, type: "submit")
        ])
    }
}
