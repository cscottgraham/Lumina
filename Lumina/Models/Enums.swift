import Foundation

// Plain Codable enums stored as String raw values on the models — CloudKit-safe
// and query-friendly. These are NOT versioned with the schema: add cases
// freely, never remove/rename a shipped raw value (decode falls back safely).

/// The kind of a `ContentItem`.
enum ContentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo         // image; Attachment carries original + thumbnail
    case video         // Attachment carries original + poster-frame thumbnail
    case audio         // recording (voice memo, interview…); `text` = transcript
    case note          // text note — typed or dictated (see CaptureMethod)
    case webSnippet    // URL + title + selected text (+ screenshot attachment)
    case document      // pdf / file import

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .photo:      return "photo"
        case .video:      return "video"
        case .audio:      return "waveform"
        case .note:       return "text.alignleft"
        case .webSnippet: return "safari"
        case .document:   return "doc.richtext"
        }
    }

    var title: String {
        switch self {
        case .photo:      return "Photo"
        case .video:      return "Video"
        case .audio:      return "Audio"
        case .note:       return "Note"
        case .webSnippet: return "Web Snippet"
        case .document:   return "Document"
        }
    }

    /// Whether this kind's *primary* payload is an on-disk media file.
    /// (A webSnippet may still carry a screenshot as a `.screenshot` attachment.)
    var hasMediaFile: Bool {
        switch self {
        case .note, .webSnippet: return false
        case .photo, .video, .audio, .document: return true
        }
    }
}

/// HOW an item entered the vault — dictation vs typing is provenance, not a
/// separate content kind.
enum CaptureMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case typed        // keyboard entry
    case dictated     // live speech-to-text (or transcribed recording)
    case imported     // photo library / files picker
    case shared       // arrived via the share extension (web snippets)
    case captured     // in-app camera/microphone capture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typed: return "Typed"
        case .dictated: return "Dictated"
        case .imported: return "Imported"
        case .shared: return "Shared in"
        case .captured: return "Captured"
        }
    }
}

/// What an `Attachment` is, relative to its item.
enum AttachmentRole: String, Codable, CaseIterable, Sendable {
    case original     // the primary media file (photo/video/audio/document)
    case screenshot   // e.g. a webSnippet's page screenshot
    case supplement   // any extra file attached alongside the primary
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
