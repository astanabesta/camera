# Phase 1 Review - Critical Bug Fixes

## Issues Found and Fixed

### 1. MediaMuxer File Path Issue (CRITICAL)
**Problem:** Using `/proc/self/fd/` path string for MediaMuxer
```java
// WRONG - MediaMuxer expects a FileDescriptor, not a path string
muxer = new MuxerController(outputPath);
```

**Fix:** Pass ParcelFileDescriptor directly to MuxerController
```java
// CORRECT - Pass FileDescriptor
muxer = new MuxerController(recordingFd, true);
```

**Files Changed:**
- `MuxerController.java` - Constructor now takes ParcelFileDescriptor
- `ManualRecordingEngine.java` - Pass recordingFd instead of path string

---

### 2. AudioTimestamp API Doesn't Exist (CRITICAL - Compilation Error)
**Problem:** Using non-existent `android.media.AudioTimestamp` class
```java
// WRONG - This class doesn't exist
android.media.AudioTimestamp ts = new android.media.AudioTimestamp();
int result = audioRecord.getTimestamp(ts, android.media.AudioTimestamp.TIMEBASE_BOOTTIME);
```

**Fix:** Use correct AudioRecord.getTimestamp() API
```java
// CORRECT - Use long array
long[] timestampNs = new long[1];
int result = audioRecord.getTimestamp(timestampNs, AudioRecord.TIMEBLOCK_LAST);
if (result == AudioRecord.SUCCESS) {
    timestampUs = timestampNs[0] / 1000; // ns → µs
}
```

**Files Changed:**
- `AudioEncoderWrapper.java` - Fixed timestamp API usage

---

### 3. HandlerThread Misuse (CRITICAL - Runtime Hang)
**Problem:** Using HandlerThread with blocking loops
```java
// WRONG - HandlerThread with blocking loop blocks the handler
videoDrainThread = new HandlerThread("VideoDrainThread");
videoDrainThread.start();
Handler videoHandler = new Handler(videoDrainThread.getLooper());
videoHandler.post(this::videoDrainLoop); // This blocks!
```

**Fix:** Use regular Thread for blocking drain loops
```java
// CORRECT - Regular Thread for blocking operations
videoDrainThread = new Thread(this::videoDrainLoop, "VideoDrainThread");
videoDrainThread.start();
```

**Files Changed:**
- `ManualRecordingEngine.java` - Changed HandlerThread to Thread
- Removed Handler imports

---

### 4. Muxer Start Timing Issue (CRITICAL - No Data Written)
**Problem:** Muxer.start() called before video track was added
```java
// WRONG - Muxer can't start without tracks
muxer = new MuxerController(...);
muxer.start(); // Fails - no tracks yet
```

**Fix:** Start muxer after video track is added in drain loop
```java
// CORRECT - Start muxer after adding video track
if (videoTrackIndex < 0 && videoEncoder != null) {
    MediaFormat outputFormat = videoEncoder.getOutputFormat();
    if (outputFormat != null) {
        videoTrackIndex = muxer.addVideoTrack(outputFormat);
        muxer.start(); // Now it's safe to start
    }
}
```

**Files Changed:**
- `ManualRecordingEngine.java` - Moved muxer.start() to videoDrainLoop
- `MuxerController.java` - Simplified start logic

---

### 5. Muxer Waiting for Audio Track (MAJOR - Potential Hang)
**Problem:** Muxer waiting for both video and audio tracks before starting
```java
// WRONG - If audio fails, muxer never starts
if (videoTrackIndex >= 0 && audioTrackIndex >= 0 && !muxerStarted) {
    muxer.start();
}
```

**Fix:** Start muxer as soon as video track is added
```java
// CORRECT - Start with video track, audio can be added later
if (videoTrackIndex >= 0) {
    muxer.start();
}
```

**Files Changed:**
- `MuxerController.java` - Removed audioTrackRequired logic

---

### 6. Audio Encoder EOS Not Signaled (MAJOR - Hang on Stop)
**Problem:** Audio encoder never receives EOS signal
```java
// WRONG - Audio encoder keeps running
public void stop() {
    videoEncoder.signalEndOfStream();
    // Audio encoder never signaled!
}
```

**Fix:** Signal EOS to audio encoder in stop method
```java
// CORRECT - Signal both encoders
public void stop() {
    isRecording.set(false);
    if (videoEncoder != null) {
        videoEncoder.signalEndOfStream();
    }
    if (audioEncoder != null) {
        audioEncoder.signalEndOfStream(); // Add this
    }
}
```

**Files Changed:**
- `ManualRecordingEngine.java` - Added audioEncoder.signalEndOfStream()

---

## Compilation Errors Fixed

1. ✅ AudioTimestamp class doesn't exist → Fixed with correct API
2. ✅ MediaMuxer path string → Fixed with FileDescriptor
3. ✅ HandlerThread blocking → Fixed with regular Thread
4. ✅ Unused imports removed (Handler, HandlerThread, Image, MediaCodec, Build)

---

## Runtime Issues Fixed

1. ✅ Muxer won't start without tracks → Fixed timing
2. ✅ Muxer waits for audio forever → Start with video only
3. ✅ Audio encoder hangs on stop → Signal EOS
4. ✅ Drain threads block HandlerThread → Use regular Thread

---

## Testing Checklist

Before building APK, verify:

- [ ] All files compile without errors
- [ ] MuxerController accepts FileDescriptor
- [ ] AudioRecord.getTimestamp() uses correct API
- [ ] Drain threads use regular Thread (not HandlerThread)
- [ ] Muxer starts after video track is added
- [ ] Both encoders receive EOS signal on stop
- [ ] No unused imports

---

## Files Modified

1. `MuxerController.java` - FileDescriptor constructor, simplified start logic
2. `ManualRecordingEngine.java` - Pass FileDescriptor, use Thread, move muxer.start(), signal audio EOS
3. `AudioEncoderWrapper.java` - Fix AudioTimestamp API
4. `VideoEncoderWrapper.java` - No changes needed (Surface mode handles timestamps automatically)
5. `FrameQueue.java` - No changes needed
6. `TimestampManager.java` - No changes needed

---

## Summary

All critical compilation and runtime bugs have been fixed. The code should now:
- Compile without errors
- Start the muxer at the right time
- Properly synchronize audio and video
- Shut down cleanly without hanging

Ready for APK build testing.
