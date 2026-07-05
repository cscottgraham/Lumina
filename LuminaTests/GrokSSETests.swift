import XCTest
@testable import Lumina

/// Wire-level tests for the Grok (xAI, OpenAI-compatible) SSE parsing —
/// the provider-swap must distill to the same event stream Claude does.
final class GrokSSETests: XCTestCase {

    private func decode(_ json: String) -> [ClaudeStreamEvent] {
        GrokClient.decodeChunk(Data(json.utf8))
    }

    func testContentDelta() {
        let events = decode(#"{"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}"#)
        guard case .textDelta(let text)? = events.first else {
            return XCTFail("Expected .textDelta, got \(events)")
        }
        XCTAssertEqual(text, "Hello")
    }

    func testReasoningDelta() {
        let events = decode(#"{"choices":[{"delta":{"reasoning_content":"thinking…"},"finish_reason":null}]}"#)
        guard case .reasoningDelta(let r)? = events.first else {
            return XCTFail("Expected .reasoningDelta, got \(events)")
        }
        XCTAssertEqual(r, "thinking…")
    }

    func testFinishReasonEmitsDone() {
        let events = decode(#"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#)
        XCTAssertTrue(events.contains { if case .done(let reason) = $0 { return reason == "stop" } ; return false })
    }

    func testUsageChunkMapsTokensAndCacheReads() {
        // Final include_usage chunk: prompt 1200 of which 900 cached.
        let events = decode("""
        {"choices":[],"usage":{"prompt_tokens":1200,"completion_tokens":350,
         "prompt_tokens_details":{"cached_tokens":900}}}
        """)
        guard case .usage(let u)? = events.first else {
            return XCTFail("Expected .usage, got \(events)")
        }
        XCTAssertEqual(u.inputTokens, 300, "inputTokens must EXCLUDE cached reads")
        XCTAssertEqual(u.cacheReadInputTokens, 900)
        XCTAssertEqual(u.outputTokens, 350)
    }

    func testGarbageChunkIsIgnored() {
        XCTAssertTrue(decode("not json").isEmpty)
    }

    func testEncodeBodyMergesSystemAndMessages() throws {
        let prompt = LLMPrompt(cacheableContext: "STABLE CONTEXT",
                               volatileInstructions: "Current date: today.",
                               messages: [.init(role: "user", content: "hi")])
        let data = try GrokClient.encodeBody(prompt, LLMOptions(modelID: GrokModel.grok41FastReasoning.rawValue))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(obj["model"] as? String, "grok-4-1-fast-reasoning")
        XCTAssertEqual(obj["stream"] as? Bool, true)
        let messages = try XCTUnwrap(obj["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        let sys = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(sys.contains("STABLE CONTEXT"))
        XCTAssertTrue(sys.contains("Current date"))
        XCTAssertEqual(messages.last?["role"] as? String, "user")
    }

    func testModelCatalogPricesBothProviders() {
        XCTAssertGreaterThan(ModelCatalog.pricing(for: "claude-opus-4-8").inputPerMTok, 0)
        XCTAssertGreaterThan(ModelCatalog.pricing(for: "grok-4-1-fast-reasoning").inputPerMTok, 0)
        XCTAssertEqual(ModelCatalog.pricing(for: "unknown-model").inputPerMTok, 0)
        XCTAssertEqual(ModelCatalog.provider(for: "grok-4"), .grok)
        XCTAssertEqual(ModelCatalog.provider(for: "claude-haiku-4-5"), .claude)
    }
}
