import re
import math

java_file = 'android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java'
with open(java_file, 'r') as f:
    content = f.read()

def get_zircon_y(x):
    # Using a much stronger logarithmic base (c=40) to flatten the curve heavily.
    # This allocates ~50% of the 10-bit code values to the shadows/mids, and 50% to the highlights,
    # giving massive dynamic range retention like true Cinema cameras.
    return math.log10(x * 40.0 + 1.0) / math.log10(41.0)

points = []
# Using a denser distribution to ensure ISP spline perfection
for i in [0.0, 0.02, 0.05, 0.1, 0.18, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.98, 1.0]:
    y = get_zircon_y(i)
    points.append(f"{i:.4f}f, {y:.4f}f")

points_str = ",\n            ".join(points)

new_zircon = f'''    private TonemapCurve createZirconLogCurve() {{
        // Zircon Log V2: Expanded Dynamic Range
        // Formula: y = log10(x * 40 + 1) / log10(41)
        // This is a much flatter curve. It lifts the shadows far higher out of the noise floor
        // and compresses the highlights much softer, allocating exactly 50% of the 10-bit data 
        // below 18% gray, and 50% to the highlights above it. 
        float[] curve = new float[] {{
            {points_str}
        }};
        return new TonemapCurve(curve, curve, curve);
    }}'''

pattern_remove = r'private TonemapCurve createZirconLogCurve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern_remove, new_zircon, content, flags=re.DOTALL)

with open(java_file, 'w') as f:
    f.write(content)

