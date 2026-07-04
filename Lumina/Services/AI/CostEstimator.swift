import Foundation

/// Turns token usage into human-readable cost, and provides a rough
/// pre-request estimate so the UI can warn before an expensive call.
enum CostEstimator {

    static func usd(for usage: ClaudeUsage, model: ClaudeModel) -> Double {
        (Double(usage.inputTokens) / 1_000_000) * model.inputPricePerMTok
      + (Double(usage.outputTokens) / 1_000_000) * model.outputPricePerMTok
      + (Double(usage.cacheReadInputTokens) / 1_000_000) * model.cachedInputPricePerMTok
      + (Double(usage.cacheCreationInputTokens) / 1_000_000) * model.cacheWritePricePerMTok
    }

    /// ~4 chars per token is a serviceable heuristic for a cost preview. For an
    /// exact count you'd call the `/v1/messages/count_tokens` endpoint.
    static func estimateInputTokens(chars: Int) -> Int { max(1, chars / 4) }

    static func format(_ usd: Double) -> String {
        if usd < 0.01 { return String(format: "$%.4f", usd) }
        return String(format: "$%.2f", usd)
    }
}
