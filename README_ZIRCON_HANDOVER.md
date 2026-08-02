# Zircon Cinema Camera - Architecture & Features Handover

## What We Built
This app has been successfully upgraded from a standard 8-bit camera to a professional **10-bit zero-copy hardware cinema camera** specifically optimized for the Xiaomi 23090RA98I (Zircon).

### 1. 10-Bit Hardware Encoding Bridge
* Bypassed standard 8-bit limits by directly requesting `YCBCR_P010` frames from the Android `Camera2` API.
* Implemented a zero-copy bridge using `ImageWriter` to pass the 10-bit frames directly into the `MediaCodec` HEVC Main10 hardware encoder. 
* Fixed frame presentation timestamps (`System.nanoTime()`) so 10-bit recordings no longer read as "30 minutes long" in external editors like DaVinci Resolve.

### 2. Native HLG10 HDR Support
* Added a toggle for `10-bit HLG (HDR)`.
* Triggers Android 13's `DynamicRangeProfiles.HLG10` on both the preview and record surfaces.
* Outputs true BT.2020 HDR10+ metadata directly into the HEVC MP4 file natively.
* Added a safe try/catch fallback to SDR if the specific sensor string rejects the HDR10 request.

### 3. Zircon Log & Cinematic Profiles
* Because full 3D `.cube` LUT processing requires heavy, battery-draining GPU (OpenGL) pipelines, we opted for **Zero-Copy Hardware Tonemaps (1D Curves)**.
* We intercept `CaptureRequest.TONEMAP_CURVE` and inject custom RGB float arrays to emulate cinematic looks directly on the phone's ISP.
* **Profiles built:**
  * `Standard`: Safe Rec.709 with gently protected shadows to prevent black crushing on Xiaomi sensors.
  * `Zircon Log`: Super flat, lifted shadows, compressed highlights for maximum grading dynamic range.
  * `Cinematic`: Teal and Orange Hollywood emulation.
  * `Fuji`: Classic Chrome warm emulation (Lifted vintage blue shadows, warm pushed red highlights).
  * `Vivid`: iPhone Smart HDR emulation (Aggressive contrast, bright blue skies, deep rich shadows).

### 4. Dart/Flutter Integration
* `camera_ui_controller.dart` fully manages the state of Bit Depth (8-bit vs 10-bit vs HLG), Log toggles, and Film Styles.
* Config persists locally via JSON serialization.

## Next Steps / Known Limitations
1. **Live 3D LUTs & Grain**: The current engine is heavily optimized around hardware Camera2 callbacks. If the user requests true 3D `.cube` imports, grain, or vibrance sliders, you **must** abandon the current `ImageWriter` hardware path and build an OpenGL/Vulkan rendering pipeline using `SurfaceTexture`, `EGL14`, and custom fragment shaders to intercept the YUV frames before passing them to the encoder.
2. **Preview limitations**: The viewfinder uses a standard `Surface` which applies default ISP contrast. The user cannot see the Zircon Log or Fuji profiles live in the viewfinder; they are only baked into the final MP4 file. This is standard behavior for hardware-only paths on Android.

---
