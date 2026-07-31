# Third-party architecture research

## MotionCam

Repository reviewed: <https://github.com/f0enix/motioncam>  
License reported by the repository: GNU GPL v3  
Repository snapshot reviewed: public `main` branch, 2021 codebase

MotionCam was reviewed for high-level architectural lessons only:

- keep camera-session state separate from UI state;
- treat capture metadata as first-class data;
- use explicit native camera lifecycle transitions;
- separate RAW buffer ownership from processing;
- generate RAW preview through a dedicated GPU pipeline when that milestone begins.

No MotionCam Java/C++ source, UI layouts, drawables, color processing, RAW container code, algorithms, or assets are copied into Zircon Cinema. The current `CameraEngine.java` is an original Camera2/MediaRecorder implementation based on public Android APIs. This separation avoids accidentally importing GPL-covered implementation code into a project whose final distribution/license has not yet been selected.

The reviewed MotionCam repository is an older still/RAW architecture and is not treated as proof of current MotionCam video behavior, 10-bit retention, or Redmi-specific implementation details.

## Android API architecture selected

The functional beta uses:

- Camera2 camera ID `0`;
- a Flutter external texture backed by `SurfaceTexture`;
- a 1920×1080 preview stream;
- Camera2 request/result metadata;
- Camera2 manual sensor/focus controls;
- a 3840×2160 MediaRecorder input surface;
- HEVC Main 8-bit at 80 Mb/s;
- AAC at 48 kHz / 192 kb/s;
- MediaStore output under `Movies/ZirconCinema`.

This is the first reliable direct-ISP recorder, not the final RAW/ZirconLog or proven 10-bit pipeline.
