# Zircon Cinema — UI/UX Specification v0.2

**Target:** Xiaomi `23090RA98I` only  
**Physical display:** 2712×1220 landscape  
**Implementation:** Flutter, Android SDK 36  
**Scope:** Camera2 functional beta with real preview, manual controls, and UHD HEVC/AAC recording; advanced pipelines remain gated

## 1. Design intent

The interface should feel like a dedicated cinema instrument rather than a consumer camera. The operator must be able to read exposure state, recording state, validation status, remaining media, and thermal state without opening a menu.

Professional camera applications, including Blackmagic Camera, inform the workflow model: persistent exposure parameters, direct manipulation, landscape operation, monitoring scopes, and clear media/settings destinations. Zircon Cinema uses an original information hierarchy and visual identity rather than reproducing another product's UI.

## 2. Primary landscape hierarchy

1. **Preview field** — full-bleed behind all controls.
2. **Top status line** — application identity, functional-beta warning, timecode, actual ISO/exposure, and active recorder bitrate.
3. **Parameter strip** — lens, FPS, shutter angle, ISO, WB, tint, focus.
4. **Candidate-pipeline badge** — makes unqualified bit depth/profile impossible to mistake for proven operation.
5. **Monitoring bar** — guides, grid, zebra, false color, peaking, waveform, histogram.
6. **Scopes** — waveform and audio meters in the lower-right monitoring zone.
7. **Right navigation rail** — Camera, Media, Record, Settings.
8. **Context sheet** — one control family at a time, replacing lower monitoring controls while open.

The v0.2 ergonomics target is **right-handed, balanced density**: the record/navigation rail remains on the right, core exposure values stay visible, and secondary controls live in context panels rather than permanently covering the image.

## 3. Interaction rules

- A tap on a parameter opens its context sheet; a second tap or close button dismisses it.
- Values have large discrete hit areas. Fine sliders are avoided for values with meaningful calibrated steps.
- The record target is visually isolated and at least 58 logical pixels across.
- The real recorder state changes circle-to-square, color emphasis, and timecode state only after native recording starts successfully.
- Exposure/focus controls and Media/Settings navigation lock during recording; Stop remains immediately reachable.
- Unqualified frame rates are visible but disabled, so the information architecture can be tested without falsely presenting support.
- Monitoring overlays never change the recorded signal unless an explicitly named bake-in option is added later.
- Zebra and false color are mutually exclusive; waveform and histogram are mutually exclusive to preserve a balanced preview area.
- Clean feed hides the complete HUD and right rail; tapping the preview restores controls.
- Every destructive or clip-affecting action requires a distinct state, not color alone.

## 4. Visual tokens

| Role | Value |
|---|---|
| Canvas | `#05070A` |
| Strong panel | `#0B0E13` at high opacity |
| Border | `#303A45` |
| Primary text | `#F3F6F8` |
| Muted text | `#96A3AE` |
| Operational accent | `#3DD6CF` |
| Record | `#FF4454` |
| Warning / unqualified | `#FFB648` |
| Accepted | `#73D68B` |

The turquoise accent is reserved for selections and enabled monitoring tools. Red is reserved for record/critical states. Amber always means provisional, locked, or unqualified.

## 5. Device-specific UX decisions

- Camera selection exposes only `MAIN` because current public evidence shows camera IDs 0 and 1 and only rear camera 0 is the cinema candidate.
- ISO presets emphasize 50 and 400; values above 800 will eventually carry a digital-gain indication.
- Shutter is presented primarily as angle because the product is cinema-focused.
- A 2.39:1 frame guide can sit inside the natural centered UHD crop.
- Thermal and real free-storage instrumentation will become persistent once connected; the current functional beta shows actual Camera2 sensor metadata instead of invented values.
- The UI does not show a generic multi-lens carousel or unsupported ultrawide/macro choices.

## 6. Evidence language

The final interface will use four explicit evidence labels:

- **ADVERTISED** — exposed by Camera2/codec metadata only;
- **CONFIGURED** — session or codec configured and started;
- **BITSTREAM PROVEN** — actual pixels encoded/decoded with verified format;
- **SUSTAINED** — long recording passed frame, file, and thermal checks.

A candidate mode cannot lose its warning label until the corresponding evidence exists.

## 7. Accessibility and field operation

- minimum primary target: 44×44 logical pixels;
- critical state uses icon/shape/text in addition to color;
- tabular numerals for timecode and measured values;
- high contrast over both bright and dark previews;
- panels use stable dark backing rather than blur alone;
- no gesture-only control for exposure or recording;
- left/right landscape orientations are both allowed;
- system bars use immersive sticky mode, with Android gesture edges left unobstructed.

## 8. Screens ready for evaluation

### Camera

Evaluate one-handed reach, parameter readability, context-sheet speed, scope obstruction, and accidental record risk.

### Media

Evaluate clip selection, playback hierarchy, metadata readability, clip protection, and integrity-warning placement.

### Settings / Validation

Evaluate whether advertised/configured/proven status is understandable without reading the research reports.

## 9. Functional beta boundary and deferred work

Implemented in v0.3: Camera2 preview texture, camera/microphone permissions, auto/manual sensor controls, UHD30 HEVC Main 8-bit + AAC, and MediaStore clip writing.

Still deferred or unqualified:

- on-device qualification of the implemented direct recorder;
- exact 24/25/30 cadence and encoder PTS validation;
- actual storage, battery, and thermal instrumentation;
- MediaCodec-based 10-bit/P010 integrity pipeline;
- RAW video and final ZirconLog exposure/index tools;
- calibrated WB gains, tint, matrices, and LUT import/export;
- scopes computed from actual frames and meters computed from real audio;
- in-app video decoding, clip database, thumbnails, and protection;
- recording haptics;
- portrait layout (not planned for this device-focused cinema workflow).
