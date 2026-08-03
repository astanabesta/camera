import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

new_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Reverted to original S-Log3 mapping (Middle Gray at 41%, White at 61%).
        // Added high-density anchor points near 1.0 to prevent ISP spline interpolation overshoot,
        // which causes flickering/artifacts in clipped white regions due to 10-bit quantization overflow.
        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            0.9500f, 0.6250f, // High-density roll-off to prevent spline overshoot
            0.9800f, 0.6340f,
            0.9900f, 0.6370f,
            1.0000f, 0.6400f  // Peak sensor white rolls off softly at 64% IRE
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

pattern = r'private TonemapCurve createSLog3Curve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern, new_slog3.strip(), content, flags=re.DOTALL)

old_color_range = '''                format.setInteger(MediaFormat.KEY_COLOR_RANGE,
                        MediaFormat.COLOR_RANGE_LIMITED);'''
new_color_range = '''                // Use Full Range for Log profiles to preserve 10-bit quantization precision, Limited for standard Rec.709
                int colorRange = ("S-Log3".equals(requestedLogCurve) || "Xiaomi".equals(requestedLogCurve)) ? 
                                 MediaFormat.COLOR_RANGE_FULL : MediaFormat.COLOR_RANGE_LIMITED;
                format.setInteger(MediaFormat.KEY_COLOR_RANGE, colorRange);'''

if old_color_range in content:
    content = content.replace(old_color_range, new_color_range)
else:
    # fallback
    content = re.sub(r'format\.setInteger\(MediaFormat\.KEY_COLOR_RANGE,\s*MediaFormat\.COLOR_RANGE_LIMITED\);', new_color_range, content)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
