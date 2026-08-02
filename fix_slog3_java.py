import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Update S-Log3 curve to anchor at 1.0
old_slog3 = '''        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            1.0000f, 0.6400f  // Peak sensor white rolls off softly
        };'''

new_slog3 = '''        float[] curve = new float[] {
            0.0000f, 0.0350f, 
            0.0200f, 0.1200f, 
            0.0500f, 0.2200f, 
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            0.9800f, 0.6500f,
            1.0000f, 1.0000f  // MUST anchor at 1.0 to prevent highlight flickering/solarization
        };'''

content = content.replace(old_slog3, new_slog3)

# 2. Add requestedLogCurve variable
content = content.replace('private boolean requestedLogProfile = false;', 'private String requestedLogCurve = "Rec709";')

# 3. Update updateControls
old_controls = 'requestedLogProfile = booleanValue(values.get("logProfile"), requestedLogProfile);'
new_controls = 'Object logObj = values.get("logCurve");\n                if (logObj != null) requestedLogCurve = String.valueOf(logObj);'
content = content.replace(old_controls, new_controls)

# 4. Fix Tonemap Application
old_tonemap = '''        if (requestedHlgProfile && Build.VERSION.SDK_INT >= 33) {
            // HLG handles its own tonemapping via the DynamicRangeProfile
            // Do not override TONEMAP_MODE
        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createXiaomiLogCurve());
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            switch (requestedFilmStyle) {
                case "Cinematic":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createCinematicCurve());
                    break;
                case "Fuji":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createFujiCurve());
                    break;
                case "Vivid":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createVividCurve());
                    break;
                case "S-Log3":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSLog3Curve());
                    break;
                default:
                    // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;
            }
        }'''

new_tonemap = '''        if (requestedHlgProfile && Build.VERSION.SDK_INT >= 33) {
            // HLG handles its own tonemapping via the DynamicRangeProfile
        } else if ("S-Log3".equals(requestedLogCurve)) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createSLog3Curve());
        } else if ("Xiaomi".equals(requestedLogCurve)) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createXiaomiLogCurve());
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            switch (requestedFilmStyle) {
                case "Cinematic":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createCinematicCurve());
                    break;
                case "Fuji":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createFujiCurve());
                    break;
                case "Vivid":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createVividCurve());
                    break;
                default:
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;
            }
        }'''

content = content.replace(old_tonemap, new_tonemap)

# 5. Remove Open Gate from Java config check to prevent encoder crashes
content = content.replace('(width == 4080 && height == 3060) || // OPEN GATE 4:3 Full Sensor\n                ', '')

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

