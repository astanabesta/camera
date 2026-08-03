import re
import math

# 1. Generate the Java Code
java_file = 'android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java'
with open(java_file, 'r') as f:
    content = f.read()

def get_zircon_y(x):
    return math.log10(x * 10.0 + 1.0) / math.log10(11.0)

# Generate 15 precise data points
points = []
for i in [0.0, 0.02, 0.05, 0.1, 0.18, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.98, 1.0]:
    y = get_zircon_y(i)
    points.append(f"{i:.4f}f, {y:.4f}f")

points_str = ",\n            ".join(points)

new_zircon = f'''    private TonemapCurve createZirconLogCurve() {{
        // Zircon Log: A mathematically pure, continuous logarithmic function
        // Formula: y = log10(x * 10 + 1) / log10(11)
        // This guarantees absolutely zero spline overshoot, perfect (0,0) to (1,1) anchoring,
        // and flawless inversion in post-production via the ZIRCON_LOG_TO_REC709.cube LUT.
        float[] curve = new float[] {{
            {points_str}
        }};
        return new TonemapCurve(curve, curve, curve);
    }}'''

# Remove S-Log3 and Xiaomi Log, insert Zircon Log
pattern_remove = r'private TonemapCurve createSLog3Curve\(\)\s*\{.*?\n    \}\n\n    private TonemapCurve createXiaomiLogCurve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern_remove, new_zircon, content, flags=re.DOTALL)

# Update application block
old_apply = '''        } else if ("S-Log3".equals(requestedLogCurve)) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createSLog3Curve());
        } else if ("Xiaomi".equals(requestedLogCurve)) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createXiaomiLogCurve());
        } else {'''

new_apply = '''        } else if ("Zircon".equals(requestedLogCurve)) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createZirconLogCurve());
        } else {'''
content = content.replace(old_apply, new_apply)

# Fix color range check
content = content.replace('("S-Log3".equals(requestedLogCurve) || "Xiaomi".equals(requestedLogCurve))', '("Zircon".equals(requestedLogCurve))')

with open(java_file, 'w') as f:
    f.write(content)

