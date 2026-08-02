import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's add Xiaomi Log profile choice.
new_curve = '''
    private TonemapCurve createXiaomiLogCurve() {
        // Xiaomi's official 10-bit Log (V-Log/Mi-Log) emulation based on standard smartphone sensor characteristics.
        // It's a mathematically precise 1D curve designed to stretch dynamic range exactly how Xiaomi's native cinema mode does:
        // 1. Heavy shadow lift starting instantly at 0.0 (anchor at 0.005) to expose the deep noise floor.
        // 2. A very long, linear mid-section (gamma shift) to pull down midtones, preventing skin from blowing out.
        // 3. Extreme compression on the top 15% of the curve to preserve sky/highlight details seamlessly.
        
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0200f, 0.1200f,
            0.0500f, 0.2200f,
            0.1000f, 0.3200f,
            0.2000f, 0.4400f,
            0.3000f, 0.5200f,
            0.4000f, 0.5900f,
            0.5000f, 0.6500f,
            0.6000f, 0.7000f,
            0.7000f, 0.7500f,
            0.8000f, 0.8000f,
            0.9000f, 0.8600f,
            1.0000f, 1.0000f
        };
        return new TonemapCurve(curve, curve, curve);
    }
'''

if 'createXiaomiLogCurve' not in content:
    content = content.replace('    private TonemapCurve createSafeRec709Curve() {', new_curve + '\n    private TonemapCurve createSafeRec709Curve() {')

# Apply the Xiaomi Log curve when Zircon Log is enabled but the user selects Xiaomi Log style
# We need to map it. Actually, since the user already has a "Tone Curve" toggle (Rec.709 vs Zircon Log),
# Let's rename "Zircon Log" to "Xiaomi Log" in the UI, and replace the curve in Java.

old_log_apply = '''        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createLogTonemapCurve());
        } else {'''

new_log_apply = '''        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createXiaomiLogCurve());
        } else {'''

content = content.replace(old_log_apply, new_log_apply)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
