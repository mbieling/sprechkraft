// VoiceScribe/Audio/AudioDeviceManager.swift
// Zweck: Geraete-Enumeration (AVCaptureDevice) + Core-Audio-Bridge fuer Geraetewechsel.
// RECORD-03: Mikrofon-Eingabegeraet waehlbar
// SET-04: selectedMicUID wird beim naechsten startRecording() angewendet (lazy)
//
// Pitfall 7 (RESEARCH.md): setInputDevice muss vor engine.start() aufgerufen werden.
// Strategie: Lazy-Anwendung — Geraetewechsel wirkt erst bei naechster Aufnahme.
//
// T-02-02 (Threat Register): Guard gegen nil-Return von uniqueIDToAudioObjectID;
// bei unbekanntem Geraet graceful return ohne crash.

import AVFoundation
import CoreAudio

enum AudioDeviceManager {

    // MARK: - Geraete-Enumeration

    /// Gibt alle verfuegbaren Mikrofon-Eingabegeraete zurueck.
    /// Verwendet AVCaptureDevice.DiscoverySession (ersetzt deprecated devices(for:)).
    /// - Returns: Liste der verfuegbaren Mikrofone (leer wenn keine vorhanden/genehmigt)
    static func availableMicrophones() -> [AVCaptureDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices
    }

    // MARK: - Core-Audio-Bridge

    /// Konvertiert eine AVCaptureDevice.uniqueID (String) in eine AudioObjectID (UInt32).
    /// Benoetigt fuer inputNode.auAudioUnit.setDeviceID() — macOS hat kein AVAudioSession.
    /// - Parameter uid: uniqueID eines AVCaptureDevice
    /// - Returns: AudioObjectID oder nil wenn Geraet nicht gefunden
    static func uniqueIDToAudioObjectID(_ uid: String) -> AudioObjectID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        // CFString als qualifier via withUnsafeMutablePointer uebergeben (vermeidet UnsafeRawPointer-Warning)
        let cfUID = uid as CFString
        let qualifierSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafePointer(to: cfUID) { cfUIDPtr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                qualifierSize,
                cfUIDPtr,
                &size,
                &deviceID
            )
        }
        return status == noErr ? deviceID : nil
    }

    /// Setzt das Eingabegeraet der AVAudioEngine auf das Geraet mit der gegebenen uniqueID.
    /// Muss vor engine.prepare() / engine.start() aufgerufen werden (Pitfall 7).
    /// Bei unbekannter UID: graceful return ohne Fehler (T-02-02).
    /// - Parameters:
    ///   - uid: uniqueID des gewuenschten Mikrofons
    ///   - engine: Die AVAudioEngine deren inputNode konfiguriert werden soll
    /// - throws: Wenn setDeviceID fehlschlaegt (z.B. Geraet nicht mehr verfuegbar)
    static func setInputDevice(uid: String, engine: AVAudioEngine) throws {
        guard let deviceID = uniqueIDToAudioObjectID(uid) else {
            // Geraet nicht gefunden — System-Standard bleibt aktiv (graceful fallback)
            return
        }
        try engine.inputNode.auAudioUnit.setDeviceID(deviceID)
        // Hinweis (Pitfall 2): outputFormat(forBus:) danach in AudioController neu abfragen
    }
}
