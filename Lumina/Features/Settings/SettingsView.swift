import SwiftUI

/// Settings — Claude API key management (Keychain), default model, and about.
@MainActor
struct SettingsView: View {
    @State private var apiKeyInput = ""
    @State private var hasKey = KeychainStore.shared.hasAPIKey
    @State private var defaultModel: ClaudeModel = .opus48
    @State private var savedFlash = false
    @AppStorage(ItemEnrichmentService.enabledDefaultsKey) private var enrichNewItems = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Settings").luminaText(LuminaFont.largeTitle())

                claudeSection
                aboutSection
            }
            .padding(Space.md)
            .padding(.bottom, Space.xxl)
        }
        .background(AuroraBackground(accent: .ocean, animated: false).ignoresSafeArea())
        .scrollContentBackground(.hidden)
    }

    private var claudeSection: some View {
        GlassCard(accent: .ocean) {
            VStack(alignment: .leading, spacing: Space.md) {
                Label("Claude", systemImage: "sparkles").luminaText(LuminaFont.title2())

                Text(hasKey ? "An API key is stored securely in your Keychain."
                            : "Add your Anthropic API key to enable research chat. It's stored only in the iOS Keychain — never in the app's data or iCloud.")
                    .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)

                SecureField(hasKey ? "•••• stored — enter to replace" : "sk-ant-…", text: $apiKeyInput)
                    .textFieldStyle(.plain).luminaText(LuminaFont.mono())
                    .padding(Space.md).glass(cornerRadius: Radius.md, accent: .ocean)

                HStack {
                    GlassButton(savedFlash ? "Saved ✓" : "Save key", systemImage: "key.fill",
                                accent: .ocean, weight: .primary) {
                        let k = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        KeychainStore.shared.saveAPIKey(k)
                        apiKeyInput = ""; hasKey = true; flash()
                    }
                    if hasKey {
                        GlassButton("Remove", systemImage: "trash", accent: .ocean, weight: .ghost) {
                            KeychainStore.shared.deleteAPIKey(); hasKey = false
                        }
                    }
                }

                Divider().overlay(LuminaColors.separator)

                Text("Default model").luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
                Picker("Model", selection: $defaultModel) {
                    ForEach(ClaudeModel.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(defaultModel.blurb).luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)

                Divider().overlay(LuminaColors.separator)

                Toggle(isOn: $enrichNewItems) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-enhance new items").luminaText(LuminaFont.headline())
                        Text("Claude evaluates each capture and adds a summary, related context, and suggested tags. Uses Haiku (~fractions of a cent per item).")
                            .luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                    }
                }
                .tint(LuminaGradients.accentColor(.ocean))
            }
        }
    }

    private var aboutSection: some View {
        GlassCard(accent: .ocean) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Label("About", systemImage: "info.circle").luminaText(LuminaFont.title2())
                Text("Lumina — a personal research & knowledge vault. Local-first with iCloud sync.")
                    .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                Text("Version 0.1.0").luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
            }
        }
    }

    private func flash() {
        withAnimation { savedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { savedFlash = false } }
    }
}
