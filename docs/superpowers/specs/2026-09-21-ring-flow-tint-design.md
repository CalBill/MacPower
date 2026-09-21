# Ring & Energy-Flow Tint Design

## Goal

Bring menu-bar-style tint controls (presets, editable bands, constant / slide / gradient / slideGradient) to rings and energy flow.

## Rings

- Four independent `ValueTintScheme`s: battery, CPU, GPU, memory.
- Slide interpolates against each ring’s own percent.
- Gradient is left→right along the ring stroke.
- Presets mirror existing `ThemePalette` (semantic / system / highContrast / glassMono) plus custom.
- Editor target: one ring or **All**. Mixed fields show `-`; edits in All apply to every ring.

## Energy flow

- Four independent schemes keyed by `EnergyFlowMode`.
- Slide uses battery percent.
- Motion pigment keeps current gradient / solid / white defaults; optional custom color override.

## Performance

Resolve colors only when percent / settings change — never per animation frame.
