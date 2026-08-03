import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The clipping issue in near-white regions is a known hardware defect on many Android ISPs 
# when they encounter a Tonemap curve that doesn't terminate at exactly 1.0 on the output axis.
# The previous fix (high density anchors) wasn't aggressive enough because the output still ended at 0.64.
# The Android hardware literally wraps around mathematically if output is not 1.0.

new_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Sony S-Log3 mapping (Middle Gray at 41%, White at 61%).
        // CRITICAL FIX: The Xiaomi ISP throws a fatal quantization error (highlight solarization/clipping) 
        // if the output curve does not terminate precisely at 1.0000f. 
        // We MUST map the absolute peak sensor value to 1.0, even though this technically deviates 
        // from the 64% S-Log3 spec at the very top. This prevents the white-screen artifacting.
        float[] curve = new float[] {
            0.0000f, 0.0350f, 
            0.0200f, 0.1200f, 
            0.0500f, 0.2200f, 
            0.1800f, 0.4100f, // 18% Middle Gray
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White
            0.9500f, 0.7500f, // Start ramping up sharply AFTER 90% white
            1.0000f, 1.0000f  // MUST anchor at 1.0 to prevent ISP integer overflow
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

pattern = r'private TonemapCurve createSLog3Curve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern, new_slog3.strip(), content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
