import Foundation

/// The kind of a `ContentItem`. Stored as its `String` raw value so it is
/// CloudKit-safe and query-friendly.
enum ContentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case note          // typed text
    case voiceNote     // audio recording + transcript
    case audio         // imported/attached audio
    case photo
    case video
    case webSnippet    // saved web page excerpt + metadata
    case document      // pdf / file

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .note:       return "text.alignleft"
        case .voiceNote:  return "waveform"
        case .audio:      return "music.note"
        case .photo:      return "photo"
        case .video:      return "video"
        case .webSnippet: return "safari"
        case .document:   return "doc.richtext"
        }
    }

    var title: String {
        switch self {
        case .note:       return "Note"
        case .voiceNote:  return "Voice Note"
        case .audio:      return "Audio"
        case .photo:      return "Photo"
        case .video:      return "Video"
        case .webSnippet: return "Web Snippet"
        case .document:   return "Document"
        }
    }

    /// Whether this kind carries an on-disk media file (vs. pure text).
    var hasMediaFile: Bool {
        switch self {
        case .note, .webSnippet: return false
        default: return true
        }
    }
}

/// Author of a chat message.
enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Which Claude model a thread/message used. Raw value is the exact API model id.
/// Pricing is USD per 1M tokens (see docs/CLAUDE_INTEGRATION.md).
enum ClaudeModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case opus48   = "claude-opus-4-8"
    case sonnet5  = "claude-sonnet-5"
    case haiku45  = "claude-haiku-4-5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus48:  return "Claude Opus 4.8"
        case .sonnet5: return "Claude Sonnet 5"
        case .haiku45: return "Claude Haiku 4.5"
        }
    }

    var blurb: String {
        switch self {
        case .opus48:  return "Most capable — deepest research."
        case .sonnet5: return "Balanced speed & quality."
        case .haiku45: return "Fastest & cheapest."
        }
    }

    /// USD per 1M input / output tokens (standard tier).
    var inputPricePerMTok: Double {
        switch self {
        case .opus48:  return 5.00
        case .sonnet5: return 3.00
        case .haiku45: return 1.00
        }
    }
    var outputPricePerMTok: Double {
        switch self {
        case .opus48:  return 25.00
        case .sonnet5: return 15.00
        case .haiku45: return 5.00
        }
    }
    /// Cached-read input is ~0.1×; cache-write is ~1.25× (5-minute TTL).
    var cachedInputPricePerMTok: Double { inputPricePerMTok * 0.10 }
    var cacheWritePricePerMTok: Double { inputPricePerMTok * 1.25 }
}

/// An accent theme the user can pick per subject (drives the glass tint).
enum AccentTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case aurora   // teal → violet (default)
    case sunset   // amber → magenta
    case ocean    // blue → cyan
    case forest   // green → lime
    case rose     // pink → orange
    case mono     // neutral graphite

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
