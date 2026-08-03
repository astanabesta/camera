import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Revert S-Log3 curve to the EXACT first implementation, but just anchor 1.0 to prevent the highlight clipping
old_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Sony S-Log3 mapping (Middle Gray at 41%, White at 61%).
        // CRITICAL FIX: The Xiaomi ISP splines break and artifact if the points are too sparse 
        // in the flat regions. We must distribute the curve points evenly across the input range 
        // to prevent spline overshoot and highlight solarization.
        float[] curve = new float[] {
            0.0000f, 0.0350f,
            0.1000f, 0.2800f,
            0.2000f, 0.4300f, // ~18% Gray near 41%
            0.3000f, 0.4700f,
            0.4000f, 0.5000f,
            0.5000f, 0.5250f,
            0.6000f, 0.5500f,
            0.7000f, 0.5700f,
            0.8000f, 0.5900f,
            0.9000f, 0.6100f, // 90% White at 61%
            1.0000f, 1.0000f  // Anchor strictly at 1.0
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

new_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Reverted to the original accepted S-Log3 response
        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            0.9900f, 0.6400f, // Maintain the flat 64% IRE log curve as long as possible
            1.0000f, 1.0000f  // Hard clip anchor at absolute 1.0 to prevent 10-bit integer overflow/artifacts in clipped whites
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

content = content.replace(old_slog3, new_slog3)

# 2. Revert the Color Range to strictly Limited, as Android hardware encoders and ISP pipelines
# frequently corrupt YUV buffers when forced into Full Range dynamically, which causes the neon glitching.
old_color_range = '''                // Use Full Range for Log profiles to preserve 10-bit quantization precision, Limited for standard Rec.709
                int colorRange = ("S-Log3".equals(requestedLogCurve) || "Xiaomi".equals(requestedLogCurve)) ? 
                                 MediaFormat.COLOR_RANGE_FULL : MediaFormat.COLOR_RANGE_LIMITED;
                format.setInteger(MediaFormat.KEY_COLOR_RANGE, colorRange);'''

new_color_range = '''                format.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED);'''

content = content.replace(old_color_range, new_color_range)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
