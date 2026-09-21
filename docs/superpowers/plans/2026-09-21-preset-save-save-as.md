# Preset Save / Save As Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split preset save into Save (overwrite custom) and Save As (new), for tint and icon editors.

**Architecture:** Extend `SavedTintLibrary` with in-place update; add `SavedIconLibrary` mirroring tint; Settings UI shows Save only when an active saved ID exists, Save As always for dirty/built-in/custom editors.

**Tech Stack:** Swift, SwiftUI, UserDefaults via AppSettings, XCTest.

## Global Constraints

- Built-in presets are never overwritten.
- Saved libraries capped at 20 entries each list.
- Cover all languages already present in `Localizable.xcstrings`.
- Spec: `docs/superpowers/specs/2026-09-21-preset-save-save-as-design.md`.

---

### Task 1: Tint library overwrite API

**Files:**
- Modify: `MacPower/Models/SavedTintLibrary.swift`
- Modify: `MacPower/Models/AppSettings.swift`
- Test: `MacPowerTests/EnergyFlowModeTests.swift` (or adjacent tint tests)

- [x] Failing tests for `updatingMenuBar/Ring/Flow` and `update*TintPreset` keeping id/name
- [x] Implement update helpers + AppSettings `updateMenuBarTintPreset()` etc.
- [x] Commit

### Task 2: Saved icon library + AppSettings wiring

**Files:**
- Create/Modify: `MacPower/Models/SavedTintLibrary.swift` (or `SavedIconLibrary.swift`)
- Modify: `MacPower/Models/AppSettings.swift`
- Test: icon save/load/update/delete tests

- [x] Failing tests for ring/flow icon save as, overwrite, delete, persistence
- [x] Implement library + active IDs + apply/save/update/delete
- [x] Commit

### Task 3: Settings UI Save / Save As

**Files:**
- Modify: `MacPower/Views/SettingsView.swift`
- Modify: `MacPower/Localizable.xcstrings`

- [x] Split controls: Save (if saved ID), Save As (always in editor), Delete (if saved ID)
- [x] Icon pickers include saved entries
- [x] i18n for saveAs keys
- [x] Build + smoke settings; commit
