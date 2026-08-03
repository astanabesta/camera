import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# If the artifacts are STILL happening even with the 1.0 anchor, it means the Xiaomi ISP
# absolutely refuses to allow a curve that stays that flat for that long.
# The MediaTek ISP's internal tonemap spline math is violently overshooting between 0.18 and 0.90
# because the slope is too flat, causing the YUV values to exceed the 10-bit color boundaries.

# The ONLY way to fix this on Android Camera2 without using OpenGL is to use a smoother, more distributed curve
# that mathematically approximates S-Log3 without creating sharp "corners" in the array.

new_slog3 = '''    private TonemapCurve createSLog3Curve() {
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

pattern = r'private TonemapCurve createSLog3Curve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern, new_slog3.strip(), content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
