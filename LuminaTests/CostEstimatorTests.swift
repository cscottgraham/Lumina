import XCTest
@testable import Lumina

/// Cost math — the live meter must never mislead about spend.
final class CostEstimatorTests: XCTestCase {

    func testOpusPricingMath() {
        var usage = ClaudeUsage()
        usage.inputTokens = 1_000_000
        usage.outputTokens = 1_000_000
        let usd = CostEstimator.usd(for: usage, model: .opus48)
        XCTAssertEqual(usd, 5.00 + 25.00, accuracy: 0.0001)
    }

    func testCachedReadsAreATenthOfInputPrice() {
        var usage = ClaudeUsage()
        usage.cacheReadInputTokens = 1_000_000
        XCTAssertEqual(CostEstimator.usd(for: usage, model: .opus48), 0.50, accuracy: 0.0001)
        XCTAssertEqual(CostEstimator.usd(for: usage, model: .haiku45), 0.10, accuracy: 0.0001)
    }

    func testCacheWritePremium() {
        var usage = ClaudeUsage()
        usage.cacheCreationInputTokens = 1_000_000
        XCTAssertEqual(CostEstimator.usd(for: usage, model: .sonnet5), 3.00 * 1.25, accuracy: 0.0001)
    }

    func testFormatting() {
        XCTAssertEqual(CostEstimator.format(0.0042), "$0.0042")   // sub-cent → 4 dp
        XCTAssertEqual(CostEstimator.format(1.5), "$1.50")        // normal → 2 dp
    }

    func testThreadAccumulation() {
        let thread = ChatThread(subject: nil, model: .haiku45)
        var usage = ClaudeUsage()
        usage.inputTokens = 2_000_000
        usage.outputTokens = 1_000_000
        thread.addUsage(usage)
        thread.addUsage(usage)
        // 2 × (2M × $1 + 1M × $5) = 2 × $7
        XCTAssertEqual(thread.estimatedCostUSD, 14.0, accuracy: 0.0001)
    }
}
