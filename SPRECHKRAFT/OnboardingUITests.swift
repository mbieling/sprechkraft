import XCTest

final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Reset UserDefaults for a clean onboarding experience
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        
        // Ensure the app is in a state where onboarding would show
        // This might involve clearing specific UserDefaults keys if not handled by launchArguments
        // For now, assuming -ApplePersistenceIgnoreState is sufficient for .hasCompletedOnboarding
    }

    func testOnboardingFlow() throws {
        let app = XCUIApplication()
        
        // 1. Verify Onboarding Window is present
        let onboardingWindow = app.windows["Willkommen bei SPRECHKRAFT"]
        XCTAssertTrue(onboardingWindow.waitForExistence(timeout: 5), "Onboarding window did not appear.")
        
        // 2. Verify Header elements
        XCTAssertTrue(onboardingWindow.staticTexts["Willkommen bei SPRECHKRAFT"].exists)
        XCTAssertTrue(onboardingWindow.staticTexts["Transkribiere deine Stimme in Sekunden – überall dort, wo du schreiben kannst."].exists)
        
        // 3. Verify Step 1: Hotkey
        let hotkeyStep = onboardingWindow.staticTexts["Der Hotkey"]
        XCTAssertTrue(hotkeyStep.exists)
        XCTAssertTrue(onboardingWindow.staticTexts["Halte ⌥⌘R gedrückt, um die Aufnahme zu starten. SPRECHKRAFT hört zu, solange du sprichst (oder die Tasten hältst)."].exists)
        XCTAssertTrue(onboardingWindow.staticTexts["⌥⌘R"].exists)
        
        // 4. Verify Step 2: API Key
        let apiKeyStep = onboardingWindow.staticTexts["Groq API-Schlüssel"]
        XCTAssertTrue(apiKeyStep.exists)
        XCTAssertTrue(onboardingWindow.staticTexts["Für die KI-Verarbeitung (LLM) wird ein kostenloser Groq-Key benötigt."].exists)
        
        let apiKeySecureField = onboardingWindow.secureTextFields["gsk_..."]
        XCTAssertTrue(apiKeySecureField.exists)
        apiKeySecureField.tap()
        apiKeySecureField.typeText("dummy_gsk_api_key_12345")
        
        let groqConsoleButton = onboardingWindow.buttons["Schlüssel bei Groq erstellen..."]
        XCTAssertTrue(groqConsoleButton.exists)
        // We don't need to click this as it opens an external URL
        
        // 5. Verify Step 3: Accessibility
        let accessibilityStep = onboardingWindow.staticTexts["Bedienungshilfen"]
        XCTAssertTrue(accessibilityStep.exists)
        XCTAssertTrue(onboardingWindow.staticTexts["Damit SPRECHKRAFT Text direkt in andere Apps einfügen kann, wird eine Berechtigung benötigt."].exists)
        
        let accessibilityButton = onboardingWindow.buttons["Systemeinstellungen öffnen"]
        XCTAssertTrue(accessibilityButton.exists)
        // We can tap it to ensure it's interactive, but it won't grant permission in UI tests
        accessibilityButton.tap()
        
        // 6. Complete Onboarding
        let startButton = onboardingWindow.buttons["Mit SPRECHKRAFT starten"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()
        
        // 7. Verify Onboarding Window disappears
        XCTAssertFalse(onboardingWindow.exists, "Onboarding window did not disappear after completing.")
        
        // Optional: Verify that the main app is now in an idle state or accessible
        // This would depend on what the app does after onboarding.
        // For example, check for the status bar icon.
        let statusBarApp = XCUIApplication(bundleIdentifier: "com.apple.systemuiserver")
        statusBarApp.launch()
        let voiceScribeStatusBarIcon = statusBarApp.statusItems["SPRECHKRAFT — Bereit"]
        XCTAssertTrue(voiceScribeStatusBarIcon.waitForExistence(timeout: 5), "SPRECHKRAFT status bar icon not found after onboarding.")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}