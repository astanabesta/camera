# Changelog

## 0.8.0+10 — Capture-timed smooth single-lens zoom

- Added native 1×–10× Camera2 `CONTROL_ZOOM_RATIO` zoom during preview and recording without session recreation.
- Added a log₂-space zoom controller driven once per actual capture result rather than by touch-event frequency or a generic timer.
- Added acceleration-limited starts, braking-distance deceleration, target clamping and latest-target-wins command coalescing.
- Added pinch zoom, quick presets and a continuous logarithmic zoom ruler in landscape and portrait.
- Preserved AF/AE regions, focus mode, exposure, WB and stabilization requests throughout zoom updates.
- Added returned zoom ratio, measured preview FPS, zoom velocity and frame-gap telemetry.
- Avoided per-frame Flutter method calls; only the native Camera2 thread advances the ramp.
- This is main-camera digital crop zoom, not optical or multi-lens switching.

## 0.7.0+9 — Reference Settings, processing and live telemetry

- Added a close professional Settings layout based on the supplied references.
- Added a Processing page with Sharpness Off/Fast/High Quality and Noise Reduction Off/Minimal/High Quality.
- Sharpness maps internally to Camera2 `EDGE_MODE`, the only public standard sharpness request; the UI shows the returned capture-result mode.
- Added icon-only portrait/landscape controls, real storage and battery telemetry, horizon level, and recording microphone dBFS.
- Added the SIL OFL Inter font as a close distributable typography match.
- Preserved native tap AF/AE, portrait camera UI and UHD30 HEVC/AAC recording.

## 0.6.0+8 — Native tap focus, camera modes and portrait

- Added real Camera2 tap-to-focus with orientation-aware AF metering regions.
- Added tap exposure metering when the HAL advertises AE-region support.
- Added AF-state feedback with scanning, focused, failed and locked reticles.
- Added long-press AE/AF lock and explicit unlock control.
- Added a master AUTO/MANUAL mode that restores saved manual ISO, focus and WB preset values.
- Added individual AUTO/MANUAL overrides inside ISO, focus and WB panels; mixed state is shown honestly.
- Added a complete portrait camera layout with portrait preview rotation, parameter deck, tools, recording and navigation.
- Changed Android orientation from landscape-only to full-sensor operation; portrait recordings use Camera2/MediaRecorder orientation metadata.
- Preserved UHD30 HEVC Main 8-bit at requested 80 Mb/s and the complete Media/Settings architecture.
- Restored and compiled the complete native source; produced a normal Gradle-packaged arm64 APK rather than Flutter-only injection.
- Reviewed the user-supplied custom Log equation; it is not connected because its current black mapping, negative discontinuity, input color space and 8-bit quantization policy are not production-safe.

## 0.5.0+7 — Cinema HUD and vertical control deck

- Rebuilt the Camera screen around the workflow in the user-supplied labeled references while preserving Zircon's original visual identity.
- Added a compact interactive top HUD for lens/zoom, FPS, shutter, iris, timecode, ISO, WB, tint, format and AE mode.
- Replaced bottom adjustment sheets with right-side vertical rulers for ISO, shutter, focus, EV, zoom, WB and FPS.
- Added a dedicated inner camera tool rail plus the existing outer Camera/Media/Settings rail.
- Added pinch zoom, double-tap 1×/2×, perceptual eased Camera2 zoom ramps and zoom result feedback.
- Added functional OFF/OPTICAL/EIS stabilization requests.
- Added an honest monitor-LUT panel: current Rec.709 pass-through works; Internal LOG preview remains locked until the GPU color pipeline exists.
- Added Blackmagic-style workflow structure without copying its graphics, code or assets.
- Added bottom histogram/storage/project/audio modules; simulated meters are explicitly marked UI.
- Raised direct HEVC recording request from 80 to 100 Mb/s.

## 0.4.0+6 — Professional control surface and color foundation

- Preserved the complete Camera, Media, and Settings architecture.
- Replaced tap-only ISO, shutter-angle, focus and exposure-bias adjustment with original swipe rulers.
- Added coarse and fine precision modes, +/- nudges, quick presets, bounded ranges, snapping, and optional haptic detents.
- Added logarithmic 1/3-stop ISO control with 1/12-stop fine adjustment.
- Added 0.1° fine shutter-angle control and common cinema-angle snaps.
- Added continuous native 0–10 diopter focus control with distance readout.
- Added Camera2 auto-exposure compensation from -4 to +4 EV.
- Kept vendor WB presets in a swipe ruler; exact Kelvin/tint remains calibration-gated.
- Live exposure/focus adjustment while recording now defaults on; the existing recording lock remains optional in Settings.
- Coalesced fast control changes into 40 ms native Camera2 updates.
- Added the original, invertible Internal LOG v1 draft math and tests without falsely enabling it in the current 8-bit recorder.
- Added extensive Blackmagic Camera feature-gap, MotionCam engineering, and Log/color-science research reports.

## 0.3.2+5 — SurfaceProducer startup fix

- Replaced Flutter's legacy `SurfaceTextureEntry` bridge with the recommended `SurfaceProducer` API.
- Moved Flutter texture/surface creation onto Android's platform thread instead of the Camera2 worker thread.
- Added SurfaceProducer cleanup/availability lifecycle handling.
- Removed all remaining preview stream-table probing from initialization; the known 1920×1080 private preview is tested by actual session creation.
- Added phase-specific native errors for Flutter surface creation, Camera2 characteristics, camera open, session creation, and repeating requests.
- Added Camera2 callback error names such as `CAMERA_IN_USE` and `CAMERA_DEVICE`.

## 0.3.1+4 — Camera startup recovery and diagnostics

- Stopped rejecting preview startup based on Xiaomi's potentially incomplete class-based MediaRecorder size table.
- Deferred UHD recorder validation to actual recording-session creation.
- Fixed the camera-error overlay that expanded into a tall central strip.
- Added full readable/selectable camera error text.
- Added COPY ERROR and RETRY controls.
- Improved native retry behavior when a camera device opens but preview-session configuration fails.

## 0.3.0+3 — Camera2 functional beta

- Added a native, exact-device Camera2 engine for camera ID 0.
- Replaced the concept image with a real Flutter external-texture preview after permission/session setup.
- Added camera and microphone runtime permission handling.
- Added auto startup for exposure, continuous-video focus, and WB.
- Added real manual ISO 50–800, shutter-angle, and focus-distance requests.
- Added Camera2 vendor WB presets; disabled uncalibrated tint honestly.
- Added capture-result events for actual ISO, exposure, frame duration, rolling-shutter skew, focus, and frame number.
- Added real 3840×2160/30 HEVC Main 8-bit recording at requested 80 Mb/s.
- Added AAC 48 kHz audio at requested 192 kb/s.
- Added MediaStore MP4 output under `Movies/ZirconCinema` with pending/finalize handling.
- Added opening of the last completed clip in an Android video player.
- Added lifecycle close/reopen and safe recording-stop handling.
- Added an exact device/model guard.
- Reviewed MotionCam's GPL repository for high-level architecture only; copied no source or assets.

## 0.2.0+2 — Balanced professional workflow

- Kept the record/navigation rail on the right for right-handed landscape operation.
- Added recording-safe control locking and prevented leaving Camera while the simulated take is active.
- Added project and next-clip status to the camera HUD.
- Added clean-feed mode with tap-to-restore controls.
- Added selectable 2.39:1, 1.85:1, 16:9, and 4:3 frame guides.
- Added mutually exclusive false-color/zebra behavior.
- Added mutually exclusive waveform/histogram scope behavior.
- Added simulated false-color visualization and histogram rendering.
- Expanded Settings into functional Validation, Recording, Monitoring, Audio, Storage, and About pages.
- Added explicit advertised/configured/unproven wording to recording-mode cards.
- Connected Media metadata to the current project, clip name, format, and profile state.
- Expanded responsive and interaction tests at 904×407 logical pixels.

## 0.1.0+1 — Initial UI prototype

- Added original Zircon Cinema graphite/turquoise landscape design.
- Added simulated camera preview, parameter tiles, control sheets, record state, and timecode.
- Added monitoring toggles, frame guides, grid, focus reticle, waveform, and audio meters.
- Added simulated Media review and clip-metadata screen.
- Added Settings/Validation screen tied to current device evidence.
- Locked 24/25 fps choices while cadence qualification remains incomplete.
- Marked HEVC 10-bit and ZirconLog as candidate/unqualified.
- Added original adaptive launcher icon and generated mock preview asset.
- Added Android API 36 arm64 release build.
