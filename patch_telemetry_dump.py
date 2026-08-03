import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# We need to capture the exact TONEMAP_CURVE array from the actual hardware CaptureResult
# and save it to a text file for mathematical analysis.

old_telemetry = '''                    putNumber(event, "tonemapMode", result.get(CaptureResult.TONEMAP_MODE));
                    putNumber(event, "colorCorrectionMode", result.get(CaptureResult.COLOR_CORRECTION_MODE));
                    putNumber(event, "shadingMode", result.get(CaptureResult.SHADING_MODE));
                    putNumber(event, "controlMode", result.get(CaptureResult.CONTROL_MODE));'''

new_telemetry = '''                    Integer tonemapMode = result.get(CaptureResult.TONEMAP_MODE);
                    putNumber(event, "tonemapMode", tonemapMode);
                    putNumber(event, "colorCorrectionMode", result.get(CaptureResult.COLOR_CORRECTION_MODE));
                    putNumber(event, "shadingMode", result.get(CaptureResult.SHADING_MODE));
                    putNumber(event, "controlMode", result.get(CaptureResult.CONTROL_MODE));
                    
                    // IF a dump was just completed, let's also dump the exact hardware curve that generated it
                    if (requestTonemapDump) {
                        requestTonemapDump = false;
                        dumpHardwareCurve(result);
                    }'''

content = content.replace(old_telemetry, new_telemetry)

# Add the dump flag and method
new_methods = '''
    private volatile boolean requestTonemapDump = false;
    
    private void dumpHardwareCurve(TotalCaptureResult result) {
        try {
            TonemapCurve curve = result.get(CaptureResult.TONEMAP_CURVE);
            Integer mode = result.get(CaptureResult.TONEMAP_MODE);
            
            String filename = "ZIRCON_CURVE_" + System.currentTimeMillis() + ".txt";
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, filename);
            values.put(MediaStore.MediaColumns.MIME_TYPE, "text/plain");
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
            
            Uri uri = activity.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri != null) {
                try (java.io.OutputStream out = activity.getContentResolver().openOutputStream(uri)) {
                    out.write(("TONEMAP_MODE: " + mode + "\\n").getBytes());
                    if (curve != null) {
                        out.write(("Red Curve: " + curve.getPointCount(TonemapCurve.CHANNEL_RED) + " points\\n").getBytes());
                        for (int i = 0; i < curve.getPointCount(TonemapCurve.CHANNEL_RED); i++) {
                            out.write((curve.getPoint(TonemapCurve.CHANNEL_RED, i).toString() + "\\n").getBytes());
                        }
                        out.write(("Green Curve: " + curve.getPointCount(TonemapCurve.CHANNEL_GREEN) + " points\\n").getBytes());
                        for (int i = 0; i < curve.getPointCount(TonemapCurve.CHANNEL_GREEN); i++) {
                            out.write((curve.getPoint(TonemapCurve.CHANNEL_GREEN, i).toString() + "\\n").getBytes());
                        }
                        out.write(("Blue Curve: " + curve.getPointCount(TonemapCurve.CHANNEL_BLUE) + " points\\n").getBytes());
                        for (int i = 0; i < curve.getPointCount(TonemapCurve.CHANNEL_BLUE); i++) {
                            out.write((curve.getPoint(TonemapCurve.CHANNEL_BLUE, i).toString() + "\\n").getBytes());
                        }
                    } else {
                        out.write("TONEMAP_CURVE is NULL (ISP overriding or hidden)\\n".getBytes());
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
'''

content = content.replace('private volatile boolean requestP010Dump = false;', 'private volatile boolean requestP010Dump = false;\n' + new_methods)

# Link the two flags
content = content.replace('requestP010Dump = true;', 'requestP010Dump = true;\n        requestTonemapDump = true;')


with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
