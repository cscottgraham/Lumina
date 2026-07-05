import SwiftUI

/// Settings — AI provider selection (Claude / Grok), per-provider API keys
/// (Keychain), enrichment toggle, and about.
@MainActor
struct SettingsView: View {
    @AppStorage(LLMProviderFactory.providerDefaultsKey)
    private var providerRaw = AIProviderKind.claude.rawValue

    @State private var apiKeyInput = ""
    @State private var keyStatus: [AIProviderKind: Bool] = [:]
    @State private var savedFlash = false
    @AppStorage(ItemEnrichmentService.enabledDefaultsKey) private var enrichNewItems = true

    private var provider: AIProviderKind {
        AIProviderKind(rawValue: providerRaw) ?? .claude
    }
    private var hasKey: Bool { keyStatus[provider] ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Settings").luminaText(LuminaFont.largeTitle())

                aiSection
                aboutSection
            }
            .padding(Space.md)
            .padding(.bottom, Space.xxl)
        }
        .background(AuroraBackground(accent: .ocean, animated: false).ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .onAppear(perform: refreshKeyStatus)
    }

    // MARK: AI provider

    private var aiSection: some View {
        GlassCard(accent: .ocean) {
            VStack(alignment: .leading, spacing: Space.md) {
                Label("AI Provider", systemImage: "sparkles").luminaText(LuminaFont.title2())

                Text("Powers research chat and item enrichment. Each provider keeps its own API key, stored only in the iOS Keychain.")
                    .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)

                Picker("Provider", selection: $providerRaw) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: providerRaw) { _, _ in apiKeyInput = "" }

                // Key state per provider
                HStack(spacing: Space.xs) {
                    Image(systemName: hasKey ? "checkmark.seal.fill" : "exclamationmark.triangle")
                        .foregroundStyle(hasKey ? LuminaColors.success : LuminaColors.warning)
                    Text(hasKey
                         ? "\(provider.displayName) key stored in Keychain."
                         : "No \(provider.displayName) key yet — research chat and enrichment need one.")
                        .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                }

                SecureField(hasKey ? "•••• stored — enter to replace" : provider.keyHint,
                            text: $apiKeyInput)
                    .textFieldStyle(.plain).luminaText(LuminaFont.mono())
                    .padding(Space.md).glass(cornerRadius: Radius.md, accent: .ocean)

                HStack {
                    GlassButton(savedFlash ? "Saved ✓" : "Save key", systemImage: "key.fill",
                                accent: .ocean, weight: .primary) {
                        let k = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !k.isEmpty else { return }
                        KeychainStore.shared.saveAPIKey(k, account: provider.keychainAccount)
                        apiKeyInput = ""
                        refreshKeyStatus()
                        flash()
                    }
                    if hasKey {
                        GlassButton("Remove", systemImage: "trash", accent: .ocean, weight: .ghost) {
                            KeychainStore.shared.deleteAPIKey(account: provider.keychainAccount)
                            refreshKeyStatus()
                        }
                    }
                }

                Divider().overlay(LuminaColors.separator)

                Text("New research threads start on \(ModelCatalog.displayName(for: LLMProviderFactory.defaultChatModelID())); change the model per-thread from the chat's slider menu. Enrichment uses \(ModelCatalog.displayName(for: LLMProviderFactory.enrichmentModelID())).")
                    .luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)

                Divider().overlay(LuminaColors.separator)

                Toggle(isOn: $enrichNewItems) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-enhance new items").luminaText(LuminaFont.headline())
                        Text("The active provider evaluates each capture and adds a summary, related context, and suggested tags (~fractions of a cent per item).")
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

    // MARK: Helpers

    private func refreshKeyStatus() {
        for kind in AIProviderKind.allCases {
            keyStatus[kind] = KeychainStore.shared.hasKey(account: kind.keychainAccount)
        }
    }

    private func flash() {
        withAnimation { savedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { savedFlash = false } }
    }
}
