import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Add dump flag
if 'private volatile boolean requestP010Dump = false;' not in content:
    content = content.replace('private volatile boolean recording;', 'private volatile boolean recording;\n    private volatile boolean requestP010Dump = false;')

# 2. Add Method to trigger dump
dump_method = '''
    public void dumpP010Frame(MethodChannel.Result result) {
        requestP010Dump = true;
        replySuccess(result, "P010 raw dump armed for next frame");
    }
'''
if 'dumpP010Frame' not in content:
    content = content.replace('public void startRecording', dump_method + '\n    public void startRecording')

# 3. Add Raw File Writer
writer_method = '''
    private void dumpRawP010ToDisk(Image image) {
        try {
            java.io.File dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
            java.io.File file = new java.io.File(dir, "ZIRCON_RAW_" + image.getWidth() + "x" + image.getHeight() + "_" + System.currentTimeMillis() + ".yuv");
            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(file)) {
                ByteBuffer y = image.getPlanes()[0].getBuffer();
                ByteBuffer uv = image.getPlanes()[1].getBuffer();
                y.position(0); uv.position(0);
                byte[] yBytes = new byte[y.remaining()];
                y.get(yBytes);
                fos.write(yBytes);
                byte[] uvBytes = new byte[uv.remaining()];
                uv.get(uvBytes);
                fos.write(uvBytes);
            }
            emitState("p010_dump_complete", file.getAbsolutePath());
        } catch (Exception e) {
            emitError("DUMP_FAILED", "Failed to dump raw P010 frame", e);
        }
    }
'''
if 'dumpRawP010ToDisk' not in content:
    content = content.replace('private void prepareRecorder() throws IOException {', writer_method + '\n    private void prepareRecorder() throws IOException {')

# 4. Intercept frame in the reader
intercept_logic = '''
                                if (requestP010Dump) {
                                    requestP010Dump = false;
                                    dumpRawP010ToDisk(image);
                                }
'''
pattern = r'(long syntheticTimestampNs = baseTimeNs\[0\] \+ \(frameCount\[0\] \* 1_000_000_000L / requestedRecordFps\);\s*image\.setTimestamp\(syntheticTimestampNs\);)'
content = re.sub(pattern, r'\1' + intercept_logic, content)

# 5. Add Extended Telemetry
telemetry = '''
                    putNumber(event, "tonemapMode", result.get(CaptureResult.TONEMAP_MODE));
                    putNumber(event, "colorCorrectionMode", result.get(CaptureResult.COLOR_CORRECTION_MODE));
                    putNumber(event, "shadingMode", result.get(CaptureResult.SHADING_MODE));
                    putNumber(event, "controlMode", result.get(CaptureResult.CONTROL_MODE));
'''
if 'tonemapMode' not in content:
    content = content.replace('putNumber(event, "videoStabilizationMode",', telemetry + '\n                    putNumber(event, "videoStabilizationMode",')

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
