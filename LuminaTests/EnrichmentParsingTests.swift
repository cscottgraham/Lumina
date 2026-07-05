import XCTest
@testable import Lumina

/// The enrichment service must survive chatty / imperfect model output — it
/// extracts the first JSON object rather than trusting the whole response.
@MainActor
final class EnrichmentParsingTests: XCTestCase {

    func testStrictJSONParses() {
        let json = ItemEnrichmentService.firstJSONObject(
            in: #"{"summary":"A note about surface codes.","tags":["quantum","paper"],"related":""}"#
        )
        XCTAssertEqual(json?["summary"] as? String, "A note about surface codes.")
        XCTAssertEqual((json?["tags"] as? [String])?.count, 2)
    }

    func testChattyResponseWithCodeFenceStillParses() {
        let text = """
        Here is the evaluation you asked for:
        ```json
        {"summary":"Willow demonstrated below-threshold QEC.","tags":["hardware"],"related":"Connects to the threshold theorem note."}
        ```
        Let me know if you need anything else!
        """
        let json = ItemEnrichmentService.firstJSONObject(in: text)
        XCTAssertEqual(json?["summary"] as? String, "Willow demonstrated below-threshold QEC.")
        XCTAssertEqual(json?["related"] as? String, "Connects to the threshold theorem note.")
    }

    func testGarbageReturnsNilInsteadOfCrashing() {
        XCTAssertNil(ItemEnrichmentService.firstJSONObject(in: "I couldn't evaluate this item."))
        XCTAssertNil(ItemEnrichmentService.firstJSONObject(in: ""))
        XCTAssertNil(ItemEnrichmentService.firstJSONObject(in: "{not json}"))
    }
}
