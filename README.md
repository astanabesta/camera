# Zircon Cinema — Native Focus and Portrait Beta

Device-specific Flutter cinema-camera application for Xiaomi Redmi Note 13 Pro+ `23090RA98I` (`zircon`), Android 16 / API 36.

## Current build

### Source on `main`

- Source version: `0.15.2+17`
- Source revision: latest commit on the `main` branch
- Package: `ai.arena.zirconcinema.ui`
- Target ABI: `arm64-v8a`
- Target device: Xiaomi Redmi Note 13 Pro+ 5G, model `23090RA98I` / codename `zircon`
- Android target: API 36

The current `main` branch contains the latest UI, focus-feedback, storage-safety, and preference-persistence changes. It is source code, not a prebuilt release archive. Build a fresh APK from this branch using the commands in [Build locally](#build-locally).

### Archived release

- Archived release archive: `ZirconCinema-0.14.0-EXTRACT-FIRST.zip`
- Archived release version: `0.14.0+16`
- Archived APK SHA-256: `7fbbcdf62cbc9db1a32896da8b4eed6020762b590984884790d0ff9a79b6e997`

The package and personal-test certificate remain unchanged, so a newly built APK can update earlier personal-test installs. The app is release-optimized but uses an Android debug certificate; replace it with a production signing key before public distribution.

### Latest `main` branch updates — UI, reliability, and workflow

The current `main` branch includes changes after the archived v0.14 release notes below. Build from source to receive these updates.

#### Liquid Glass camera UI

- Shared frosted-glass material with backdrop blur, transparent neutral tint, luminous rim, highlight, and soft shadow.
- Landscape top HUD, bottom dashboard cards, left tool rail, and right navigation/record rail use the same glass direction.
- Portrait header and bottom Media / Record / Settings dock use matching inset rounded glass panels.
- Portrait Focus / AE-AF / Zoom / MON controls are separated from the header.
- Settings uses matching glass cards in portrait and landscape.

#### Layout and navigation

- Landscape direct camera tools remain on the **left**: Focus, AE/AF, Zoom, MON.
- Landscape navigation/record controls remain on the **right**: Camera, Record, Media, Settings, More.
- Settings has a visible back-to-camera action within its heading instead of a floating button that overlaps content.
- Portrait Settings uses flexible card space rather than a fixed minimum-height panel, reducing clipping risk on shorter displays.
- Portrait manual parameter strip has a visible scrollbar to indicate that additional controls can be reached horizontally.
- Landscape right-rail spacing is capped so tall screens do not create excessive blank space between Camera, Record, and Media.

#### Camera interaction and reliability

- Recording timecode updates through a dedicated notifier, avoiding a complete camera-screen rebuild every 33 ms during recording.
- A 256 MiB storage reserve prevents starting a recording when there is not enough room for safe recorder finalization.
- The controller estimates remaining recording time from free storage and selected bitrate.
- Camera preferences persist between launches: recording mode, bitrate, stabilization, zoom speed, sharpness, noise reduction, guide ratio, monitor tools, control lock, and haptic preference.
- Tap focus feedback now appears at the actual tap point, transitions through scanning/success/failure states, and dismisses after a short delay unless AE/AF is locked. Old continuous-AF results cannot restore a stale marker after reframing.

#### Feature-status clarity

- Audio settings state that the current recorder uses the fixed device microphone source.
- Live Stream and LUT pages are labelled as planned/GPU-pipeline work rather than being presented as active features.
- Histogram, waveform, zebra, false colour, and focus-peaking controls remain UI/overlay demonstrations until the planned Camera2 analysis pipeline is implemented.

### v0.14 zoom pacing and exposure milestone

Zoom requests now advance from lower-latency capture-start timing, submit at most once per frame and suppress duplicate ratios. Medium/Fast are 2.25×/3.5× Slow, portrait telemetry is moved to the bottom panel, and manual ISO extends to 3200 with digital-gain labeling above 800.

### v0.13 adjustable zoom-speed milestone

Smooth zoom now offers Slow, Medium and Fast presets. Slow preserves the existing cinematic move; Medium and Fast increase both rate and acceleration while retaining native capture-timed interpolation and smooth braking.

### v0.12 launcher specification milestone

The supplied full-square dark lens artwork is now packaged as a 108 dp adaptive icon with a 72 dp safe composition, all legacy density buckets, and a 512×512 Play Store asset. Camera behavior remains identical to v0.11.

### v0.11 launcher icon milestone

The Android launcher now uses the supplied dark camera-lens artwork with a red recording indicator. The adaptive version is scaled into Android's mask-safe region. Camera behavior remains identical to v0.10.

### v0.10 launcher icon milestone

The Android launcher now uses the user-supplied blue camera artwork across legacy, round and adaptive icon formats. Camera and recording behavior remain identical to v0.9.

### v0.9 recording and field-control milestone

Added UHD30, FHD30 and 4:3 1440p30 direct modes; requested 20/50/80/100 Mb/s bitrates; Off/OIS/EIS selection; fixed orientation refresh; minimal AUTO HUD; and volume-key zoom with tap steps, hold-to-drive and smooth release.

### v0.8 smooth zoom milestone

The main camera now supports capture-result-timed 1×–10× smooth crop zoom during preview and recording. Pinch, presets and the zoom ruler update only the latest target; a native log₂-space controller advances once per actual camera frame with acceleration and braking, while reporting actual zoom, measured preview FPS and frame gaps.

### v0.7 processing, Settings and telemetry milestone

Settings now closely follows the supplied professional reference structure. The new Processing page exposes Sharpness Off/Fast/High Quality and Noise Reduction Off/Minimal/High Quality, with actual Camera2 capture-result reporting. The camera also adds icon-only portrait/landscape switching, real storage and battery status, horizon level, and recording microphone dBFS.

### v0.6 native focus and portrait milestone

The camera now supports real Camera2 tap AF/AE regions, AF-state reticle feedback, long-press AE/AF lock, a master AUTO/MANUAL mode, individual ISO/focus/WB overrides, and full portrait camera operation. The complete native source is compiled in a normal Gradle arm64 release package; the v0.4 recorder remains the recording foundation.

The user-supplied `myLog` equation was reviewed but is not connected to recording because its current black mapping, negative discontinuity, input color space and 8-bit code allocation are not production-safe. See `cinema_camera_research/19_custom_log_formula_review_20260730.md` in the workspace research package.

### v0.4 professional control milestone

The existing Camera, Media and Settings pages remain intact. Tap a parameter tile to open an original cinema ruler with horizontal swipe, quick presets, +/- nudges, COARSE/FINE precision and optional haptic detents. ISO uses a logarithmic stop scale; shutter uses angle snapping; focus uses native diopters; EV is a real Camera2 auto-exposure request. Controls may be adjusted during recording by default, while the existing Settings lock remains available.

The v0.3.2 SurfaceProducer startup fix remains included. Any startup failure names the exact phase and native exception; use **COPY** and send the complete text.

## What is now real

### Native Camera2 engine

- hard-locked to model `23090RA98I` / device `zircon`;
- rear camera ID `0` only;
- Flutter external texture backed by the recommended native `SurfaceProducer`;
- real 1920×1080 Camera2 preview;
- Camera2 capture-result metadata returned to Flutter;
- actual ISO, exposure, frame duration, rolling-shutter skew, focus distance, and frame number sampled during preview/recording;
- lifecycle-aware camera close/reopen.

### Camera controls

- auto exposure at startup;
- logarithmic ISO 50–800 ruler with 1/3-stop coarse and 1/12-stop fine adjustment;
- shutter-angle ruler from 11.25° to 345.6° with 0.1° fine mode and cinema-angle snapping;
- auto continuous-video focus at startup;
- continuous manual focus from infinity to 10 diopters with coarse/fine control;
- real Camera2 exposure compensation from -4 to +4 EV while AE is active;
- auto WB at startup and swipeable Camera2 vendor WB presets;
- OIS requested on, EIS requested off;
- live changes while recording enabled by default; optional safety lock in Settings;
- fast UI changes coalesced into bounded 40 ms native request updates.

The labeled WB values are vendor Camera2 presets, not chart-calibrated exact Kelvin gains. Tint remains disabled until calibrated per-channel gains exist.

### Internal LOG foundation

`lib/src/color/internal_log.dart` contains the original, invertible Internal LOG v1 draft transfer and 10-bit limited-range mapping. Anchor, round-trip and monotonicity tests pass. It is **not connected to the current direct-ISP 8-bit recorder**, so the app does not claim that Internal LOG is currently recording.

### Real UHD recorder

- Camera2 preview + recorder surfaces in one session;
- 3840×2160 at requested 30 fps;
- HEVC Main 8-bit;
- 80 Mb/s requested video bitrate;
- AAC audio, 48 kHz, stereo request, 192 kb/s;
- MP4 output through MediaStore;
- clips stored under `Movies/ZirconCinema`;
- MediaStore pending/finalize flow so incomplete files are not exposed as complete;
- last completed clip can be opened in an Android system video player.

## What is still simulated or unproven

- waveform, histogram, zebra, false color, peaking, and audio-meter data are visual demonstrations rather than analysis of actual pixels/audio;
- Media screen does not yet decode/play video inside Flutter; it opens the real last clip in a system player;
- free-storage, battery, and thermal instrumentation are not yet connected;
- exact 30 fps cadence is not device-proven;
- UHD audio/video synchronization is not device-proven;
- sustained recording, heat, frame drops, and file-integrity behavior are not device-proven;
- HEVC 10-bit, P010, ZirconLog, RAW video, and custom color science remain gated;
- WB preset labels are not calibrated Kelvin values;
- tint is intentionally disabled.

Therefore v0.3 is a **functional beta**, not a qualified production camera. Existing Milestone 0 research remains preserved and `DeviceProfile v1` remains unfrozen.

## Permissions

The APK requests only:

- `android.permission.CAMERA`
- `android.permission.RECORD_AUDIO`

It does not request location or broad media/storage permission. The app writes its own clips through MediaStore.

## Architecture

```text
Flutter UI
  ├─ MethodChannel: initialize, controls, start/stop, open clip
  ├─ EventChannel: engine state + Camera2 metadata
  └─ Texture: real Camera2 preview
        │
Native Android CameraEngine (Java)
  ├─ Camera2 camera ID 0
  ├─ 1080p preview SurfaceTexture
  ├─ 4K MediaRecorder input Surface
  ├─ HEVC Main + AAC
  └─ MediaStore MP4 finalization
```

CameraX was deliberately not used because it would restrict the Camera2 LEVEL_3/manual/RAW/P010 experimentation required by this exact-device project.

MotionCam's GPL repository was reviewed only for high-level architecture. No MotionCam source or assets were copied. See [third-party research](docs/third_party_research.md).

## Verification completed off-device

- Flutter 3.44.8 / Dart 3.12.2;
- `flutter analyze`: passed with no issues;
- Flutter controller/interaction/responsive tests: passed;
- Android Java compilation: passed;
- Android `lintRelease`: passed (warnings only);
- release APK assembly: passed;
- APK v2 signature: verified;
- API 36 / arm64-v8a / version 0.3.0: verified;
- manifest camera/microphone permissions and required hardware features: verified.

No Redmi phone was attached to the build workspace. Real preview orientation, Camera2 session creation, HEVC/AAC recording, MediaStore finalization, cadence, controls, and thermal behavior must now be tested on the target phone.

## Build locally

```bash
# Run from the repository root after cloning/downloading it.
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Install or update:

```bash
# Extract the GitHub Release ZIP first, then:
adb install -r ZirconCinema-0.14.0-zoom-pacing-iso3200-arm64.apk
```

See the [UI/UX specification](docs/ui_ux_spec.md), [concept mockup](docs/zircon_camera_ui_mockup.png), [third-party research](docs/third_party_research.md), and [changelog](CHANGELOG.md).
