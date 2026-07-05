import Foundation

/// Which LLM backend powers research chat + enrichment. User-selectable in
/// Settings; each provider keeps its own API key in the Keychain.
enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case grok

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .grok:   return "Grok"
        }
    }
    var keyHint: String {
        switch self {
        case .claude: return "sk-ant-…"
        case .grok:   return "xai-…"
        }
    }
    var keychainAccount: KeychainStore.KeyAccount {
        switch self {
        case .claude: return .claude
        case .grok:   return .grok
        }
    }
}

/// xAI Grok models (OpenAI-compatible API). Raw value is the exact model id.
/// Prices are USD per 1M tokens as published at the time of writing — verify
/// at console.x.ai; treat the cost meter as an estimate for Grok.
enum GrokModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case grok41FastReasoning = "grok-4-1-fast-reasoning"
    case grok41FastNonReasoning = "grok-4-1-fast-non-reasoning"
    case grok4 = "grok-4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grok41FastReasoning:    return "Grok 4.1 Fast (Reasoning)"
        case .grok41FastNonReasoning: return "Grok 4.1 Fast"
        case .grok4:                  return "Grok 4"
        }
    }

    var blurb: String {
        switch self {
        case .grok41FastReasoning:    return "Fast with visible reasoning."
        case .grok41FastNonReasoning: return "Fastest & cheapest."
        case .grok4:                  return "Most capable Grok."
        }
    }

    var inputPricePerMTok: Double {
        switch self {
        case .grok41FastReasoning, .grok41FastNonReasoning: return 0.20
        case .grok4: return 3.00
        }
    }
    var outputPricePerMTok: Double {
        switch self {
        case .grok41FastReasoning, .grok41FastNonReasoning: return 0.50
        case .grok4: return 15.00
        }
    }
}

/// Provider-agnostic model lookup: pricing, names, and per-provider pickers,
/// keyed by the raw model-id string that `ChatThread.modelRaw` stores.
enum ModelCatalog {
    struct Pricing {
        var inputPerMTok: Double = 0
        var outputPerMTok: Double = 0
        var cachedInputPerMTok: Double = 0
        var cacheWritePerMTok: Double = 0
    }

    static func pricing(for modelID: String) -> Pricing {
        if let m = ClaudeModel(rawValue: modelID) {
            return Pricing(inputPerMTok: m.inputPricePerMTok,
                           outputPerMTok: m.outputPricePerMTok,
                           cachedInputPerMTok: m.cachedInputPricePerMTok,
                           cacheWritePerMTok: m.cacheWritePricePerMTok)
        }
        if let m = GrokModel(rawValue: modelID) {
            // xAI bills cached prompt tokens at a discount; approximate 0.1×,
            // no write premium (their caching is automatic).
            return Pricing(inputPerMTok: m.inputPricePerMTok,
                           outputPerMTok: m.outputPricePerMTok,
                           cachedInputPerMTok: m.inputPricePerMTok * 0.10,
                           cacheWritePerMTok: m.inputPricePerMTok)
        }
        return Pricing()
    }

    static func displayName(for modelID: String) -> String {
        ClaudeModel(rawValue: modelID)?.displayName
            ?? GrokModel(rawValue: modelID)?.displayName
            ?? modelID
    }

    static func provider(for modelID: String) -> AIProviderKind {
        GrokModel(rawValue: modelID) != nil ? .grok : .claude
    }

    /// (id, name, blurb) options for the chat model picker.
    static func chatModels(for kind: AIProviderKind) -> [(id: String, name: String, blurb: String)] {
        switch kind {
        case .claude: return ClaudeModel.allCases.map { ($0.rawValue, $0.displayName, $0.blurb) }
        case .grok:   return GrokModel.allCases.map { ($0.rawValue, $0.displayName, $0.blurb) }
        }
    }
}

/// Resolves the active provider + defaults. Plain UserDefaults-backed statics
/// so services and views share one source of truth.
enum LLMProviderFactory {
    static let providerDefaultsKey = "aiProviderKind"

    static var activeKind: AIProviderKind {
        get {
            AIProviderKind(rawValue: UserDefaults.standard.string(forKey: providerDefaultsKey) ?? "")
                ?? .claude
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerDefaultsKey) }
    }

    /// A ready client for the active provider.
    static func current() -> any LLMProvider {
        switch activeKind {
        case .claude: return ClaudeClient()
        case .grok:   return GrokClient()
        }
    }

    /// Default model for NEW research threads on the active provider.
    static func defaultChatModelID() -> String {
        switch activeKind {
        case .claude: return ClaudeModel.opus48.rawValue
        case .grok:   return GrokModel.grok41FastReasoning.rawValue
        }
    }

    /// Cheap model for background item enrichment on the active provider.
    static func enrichmentModelID() -> String {
        switch activeKind {
        case .claude: return ClaudeModel.haiku45.rawValue
        case .grok:   return GrokModel.grok41FastNonReasoning.rawValue
        }
    }

    static var hasKeyForActiveProvider: Bool {
        KeychainStore.shared.apiKey(account: activeKind.keychainAccount) != nil
    }
}
