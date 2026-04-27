import Testing
import KeyboardShortcuts
@testable import SPRECHKRAFT

@Suite("KeyboardShortcuts Integration (SET-02)")
struct HotkeyTests {
    @Test("toggleRecording ist als Name registriert")
    func nameIsDeclared() {
        let name = KeyboardShortcuts.Name.toggleRecording
        #expect(name.rawValue == "toggleRecording")
    }

    @Test("toggleRecording hat initial-Shortcut ⌥⌘R")
    func initialShortcut() {
        let name = KeyboardShortcuts.Name.toggleRecording
        // initialShortcut ist der von KeyboardShortcuts bereitgestellte Getter
        let initial = name.defaultShortcut
        #expect(initial != nil)
        #expect(initial?.key == .r)
        #expect(initial?.modifiers.contains(.option) == true)
        #expect(initial?.modifiers.contains(.command) == true)
    }
}
