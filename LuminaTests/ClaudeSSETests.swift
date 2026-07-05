import XCTest
@testable import Lumina

/// Wire-level tests for the Messages API SSE parsing — the part of the Claude
/// integration that can regress silently if Anthropic's event shapes drift or
/// our decoder changes.
final class ClaudeSSETests: XCTestCase {

    private func decode(_ json: String, running: inout ClaudeUsage) throws -> ClaudeStreamEvent? {
        try ClaudeClient.decodeEvent(Data(json.utf8), running: &running)
    }

    func testMessageStartCarriesInputAndCacheUsage() throws {
        var running = ClaudeUsage()
        let json = """
        {"type":"message_start","message":{"id":"msg_1","usage":{"input_tokens":1200,"output_tokens":0,"cache_read_input_tokens":900,"cache_creation_input_tokens":300}}}
        """
        let event = try decode(json, running: &running)
        guard case .usage(let usage)? = event else {
            return XCTFail("Expected .usage, got \(String(describing: event))")
        }
        XCTAssertEqual(usage.inputTokens, 1200)
        XCTAssertEqual(usage.cacheReadInputTokens, 900)
        XCTAssertEqual(usage.cacheCreationInputTokens, 300)
    }

    func testTextDelta() throws {
        var running = ClaudeUsage()
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#
        let event = try decode(json, running: &running)
        guard case .textDelta(let text)? = event else {
            return XCTFail("Expected .textDelta, got \(String(describing: event))")
        }
        XCTAssertEqual(text, "Hello")
    }

    func testThinkingDeltaRoutesToReasoning() throws {
        var running = ClaudeUsage()
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"considering…"}}"#
        let event = try decode(json, running: &running)
        guard case .reasoningDelta(let text)? = event else {
            return XCTFail("Expected .reasoningDelta, got \(String(describing: event))")
        }
        XCTAssertEqual(text, "considering…")
    }

    func testMessageDeltaMergesOutputTokensOntoRunningUsage() throws {
        var running = ClaudeUsage()
        // Establish input-side usage first (as message_start would).
        _ = try decode(
            """
            {"type":"message_start","message":{"usage":{"input_tokens":500,"cache_read_input_tokens":100}}}
            """, running: &running)
        running.inputTokens = 500; running.cacheReadInputTokens = 100

        let json = #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":842}}"#
        let event = try decode(json, running: &running)
        guard case .usage(let merged)? = event else {
            return XCTFail("Expected .usage, got \(String(describing: event))")
        }
        XCTAssertEqual(merged.outputTokens, 842)
        XCTAssertEqual(merged.inputTokens, 500, "input side must survive the merge")
        XCTAssertEqual(merged.cacheReadInputTokens, 100)
    }

    func testMessageStopEndsStream() throws {
        var running = ClaudeUsage()
        let event = try decode(#"{"type":"message_stop"}"#, running: &running)
        guard case .done? = event else {
            return XCTFail("Expected .done, got \(String(describing: event))")
        }
    }

    func testUnknownEventTypesAreIgnored() throws {
        var running = ClaudeUsage()
        let event = try decode(#"{"type":"content_block_start","content_block":{"type":"text"}}"#, running: &running)
        XCTAssertNil(event)
    }
}
