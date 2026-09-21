# Preset Save / Save As Design

## Goal

Split the single “Save” action into **Save** (overwrite current custom preset) and **Save As** (create a new named preset). Apply the same rules to **tint** and **icon** preset editors (menu bar tint, ring tint, flow tint, ring icons, flow icons).

## Button rules

Shared by all five editors:

| Selection | Controls |
|---|---|
| Built-in preset | **Save As** only (name dialog → new entry selected) |
| Saved custom preset | **Save** (silent overwrite) + **Save As** + **Delete** |
| Dirty built-in edit with no saved ID | Same as built-in: **Save As** only |

Built-in payloads are never overwritten. When only Save As is available, keep the existing caption that editing a built-in must be saved as a new preset.

## Tint presets

- Keep `SavedTintLibrary` and `*ActiveSavedID`.
- Add update helpers (e.g. `updatingMenuBar/Ring/Flow(id:payload:)`) that replace payload in place and keep `id` / `name`.
- **Save**: if `*ActiveSavedID` is set, update that entry’s payload from the live editor state; stay on the same ID.
- **Save As**: existing name dialog; append capped entry (max 20); select the new ID.
- Editing a live tint while a saved ID is active may clear the ID when the payload diverges from a built-in apply path — preserve current dirty-tracking behavior; Save remains enabled only while an active saved ID is present.

## Icon presets (new library, mirror tint)

- Add `SavedIconLibrary` with `ring: [SavedTintPreset<RingIconSettings>]` and `flow: [SavedTintPreset<FlowIconSettings>]` (reuse the generic saved-preset record; max 20 each).
- Persist separately (e.g. `savedIconLibrary` UserDefaults key).
- Add `ringActiveSavedIconID` / `flowActiveSavedIconID`.
- Icon pickers: built-in `RingIconPreset` / `FlowIconPreset` cases (excluding ephemeral `.custom` as a picker row if it is only a marker) + divider + saved custom names.
- Applying a built-in clears the active saved icon ID; applying a saved entry sets the ID and loads payload.
- Slot / zoom / upload edits mark settings `.custom` and follow the same dirty rules as tint (Save only when an active saved icon ID exists).
- Editor toolbar uses the same Save / Save As / Delete control cluster as tint.

## Localization

- Keep `settings.tint.save` as **Save** (overwrite).
- Add `settings.tint.saveAs` as **Save As**.
- Retarget dialog title / message strings to Save As semantics (or add `settings.tint.saveAs.*` keys and point the dialog at them).
- Cover all existing app languages in `Localizable.xcstrings`.

## Non-goals

- Menu bar glyph pack presets (no such editor today).
- Merging tint and icon libraries into one store.
- Import / export of preset files.
- Renaming a saved preset in place (name is chosen only at Save As).

## Acceptance

1. On a built-in tint or icon preset, the editor shows Save As (and not Save); confirming creates a selectable custom entry.
2. On a saved custom preset, Save updates that entry without a dialog; Save As creates another; Delete removes it.
3. After relaunch, saved icon presets still appear in the pickers and restore correctly.
4. Built-in presets remain unchanged after Save As from an edited copy.
