---
phase: 07-parakeet-backend
plan: "03"
subsystem: build-config
status: partial-checkpoint
tags: [spm, whisperkit, fluidaudio, pbxproj]
dependency_graph:
  requires: ["07-01"]
  provides: ["07-04", "07-05"]
  affects: ["VoiceScribe.xcodeproj/project.pbxproj"]
tech_stack:
  added: []
  patterns: ["SPM dependency management via pbxproj direct edit"]
key_files:
  modified:
    - VoiceScribe.xcodeproj/project.pbxproj
decisions:
  - "WhisperKit removed via direct pbxproj edit (5 locations); FluidAudio addition requires Xcode UI due to UUID generation complexity"
metrics:
  duration: "~5 min"
  completed_date: "2026-04-25"
  tasks_completed: 1
  tasks_total: 2
---

# Phase 7 Plan 03: Xcode Package Dependencies Summary

**One-liner:** WhisperKit SPM dependency removed from all 5 pbxproj locations; FluidAudio addition awaits Xcode UI interaction.

## Status: PAUSED AT CHECKPOINT

Task 1 is complete and committed. Task 2 requires human Xcode UI interaction and cannot be automated.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove WhisperKit from project.pbxproj | bb46951 | VoiceScribe.xcodeproj/project.pbxproj |

## Pending Tasks

| Task | Name | Type | Blocker |
|------|------|------|---------|
| 2 | Add FluidAudio via Xcode UI | checkpoint:human-action | Requires Xcode File > Add Package Dependencies |

## What Was Done

Task 1 removed WhisperKit from `VoiceScribe.xcodeproj/project.pbxproj` at exactly 5 locations:

1. **PBXBuildFile entry** (line 41): `CAFE0028 /* WhisperKit in Frameworks */` — single-line entry removed
2. **PBXFrameworksBuildPhase reference** (line 89): `CAFE0028 /* WhisperKit in Frameworks */,` — removed
3. **packageProductDependencies entry** (line 250): `BEEF0028 /* WhisperKit */,` — removed
4. **packageReferences entry** (line 308): `DEAD0103 /* XCRemoteSwiftPackageReference "argmax-oss-swift" */,` — removed
5. **Object definition blocks** (lines 641-648 and 683-687): Both `XCRemoteSwiftPackageReference` (DEAD0103) and `XCSwiftPackageProductDependency` (BEEF0028) blocks removed

Verification: `grep -c "WhisperKit|argmax-oss-swift|CAFE0028|BEEF0028|DEAD0103"` returns `0`.
Other SPM dependencies (GRDB, KeyboardShortcuts, KeychainAccess, LaunchAtLogin, Defaults) remain untouched.

## Checkpoint: human-action

**Awaiting:** User must add FluidAudio 0.12.4 via Xcode UI.

**Why manual:** Adding an SPM package via Xcode automatically generates correct UUIDs for all required pbxproj sections (PBXBuildFile, PBXFrameworksBuildPhase, XCRemoteSwiftPackageReference, XCSwiftPackageProductDependency) and updates `Package.resolved` with the checksum. Manual pbxproj editing for SPM addition is error-prone and fragile.

**Steps for user:**
1. Open Xcode: `open /Users/mbieling/claude/voice/VoiceScribe.xcodeproj`
2. Wait for Xcode to finish loading (it may show a warning about missing WhisperKit — expected)
3. Go to: File > Add Package Dependencies...
4. Paste URL: `https://github.com/FluidInference/FluidAudio.git`
5. Press Enter, wait for metadata fetch
6. Select version: "Exact Version" = `0.12.4` (or "Up to Next Minor Version" from `0.12.4`)
7. Click "Add Package"
8. In the "Add to Target" dialog: check `VoiceScribe` (not VoiceScribeTests)
9. Click "Add Package" to confirm

**Verify success:**
```bash
grep "FluidAudio\|FluidInference" VoiceScribe.xcodeproj/project.pbxproj | head -5
# Expected: at least 4 lines

grep "FluidInference" VoiceScribe.xcodeproj/Package.resolved
# Expected: entry with "FluidInference/FluidAudio" and version 0.12.4
```

**Resume signal:** Type "FluidAudio added" when Xcode shows FluidAudio in Package Dependencies and the grep commands above return results.

## Deviations from Plan

None — plan executed exactly as written. Task 1 was auto-type and completed. Task 2 is checkpoint:human-action, correctly paused.

## Self-Check: PASSED

- [x] `VoiceScribe.xcodeproj/project.pbxproj` modified (17 lines deleted)
- [x] Commit `bb46951` exists: `chore(07-03): remove WhisperKit SPM dependency from project.pbxproj`
- [x] No unexpected file deletions
- [x] Other SPM dependencies untouched
- [x] SUMMARY.md created at correct path
