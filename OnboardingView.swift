import SwiftUI
import Defaults
import KeychainAccess
import ApplicationServices

struct OnboardingView: View {
    @Default(.hasCompletedOnboarding) var hasCompletedOnboarding
    @State private var groqApiKeyInput: String = ""
    @State private var axGranted: Bool = AXIsProcessTrusted()
    
    private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.voicescribe")
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "mic.fill.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Willkommen bei VoiceScribe")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Transkribiere deine Stimme in Sekunden – überall dort, wo du schreiben kannst.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.vertical, 40)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Step 1: Hotkey
                    OnboardingStep(
                        number: "1",
                        title: "Der Hotkey",
                        description: "Halte ⌥⌘R gedrückt, um die Aufnahme zu starten. VoiceScribe hört zu, solange du sprichst (oder die Tasten hältst)."
                    ) {
                        Text("⌥⌘R")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.windowBackgroundColor))
                            .cornerRadius(4)
                    }
                    
                    // Step 2: API Key
                    OnboardingStep(
                        number: "2",
                        title: "Groq API-Schlüssel",
                        description: "Für die KI-Verarbeitung (LLM) wird ein kostenloser Groq-Key benötigt."
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("gsk_...", text: $groqApiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: groqApiKeyInput) { _, newValue in
                                    keychain["groqApiKey"] = newValue.isEmpty ? nil : newValue
                                }
                            
                            Button("Schlüssel bei Groq erstellen...") {
                                if let url = URL(string: "https://console.groq.com/keys") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                        }
                    }
                    
                    // Step 3: Accessibility
                    OnboardingStep(
                        number: "3",
                        title: "Bedienungshilfen",
                        description: "Damit VoiceScribe Text direkt in andere Apps einfügen kann, wird eine Berechtigung benötigt."
                    ) {
                        HStack {
                            Image(systemName: axGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(axGranted ? .green : .orange)
                            
                            Button(axGranted ? "Berechtigung erteilt" : "Systemeinstellungen öffnen") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .disabled(axGranted)
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            
            // Footer
            VStack {
                Divider()
                Button("Mit VoiceScribe starten") {
                    hasCompletedOnboarding = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.vertical, 24)
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            groqApiKeyInput = keychain["groqApiKey"] ?? ""
            // Timer um AX-Status zu refreshen falls User zurückkehrt
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                axGranted = AXIsProcessTrusted()
            }
        }
    }
}

private struct OnboardingStep<Content: View>: View {
    let number: String
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                content()
                    .padding(.top, 4)
            }
        }
    }
}