import re
import math

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Zircon Log V3: The Ultimate Dynamic Range curve.
# We are pushing the logarithmic base (c) to 100 to maximize extreme shadow retention.
# Because the user explicitly verified they are capturing with color_range=tv (Limited Range, 64-940),
# we must compress the entire signal slightly tighter in the mid-tones so that when the encoder maps it to Limited Range,
# the visual contrast doesn't get artificially stretched and broken in DaVinci.
# 
# Formula: y = log10(x * 100 + 1) / log10(101)

def get_zircon_v3_y(x):
    return math.log10(x * 100.0 + 1.0) / math.log10(101.0)

points = []
for i in [0.0, 0.01, 0.03, 0.05, 0.1, 0.18, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0]:
    y = get_zircon_v3_y(i)
    points.append(f"{i:.4f}f, {y:.4f}f")

points_str = ",\n            ".join(points)

new_zircon = f'''    private TonemapCurve createZirconLogCurve() {{
        // Zircon Log V3: Maximum Dynamic Range (Optimized for Limited Range TV encoding)
        // Formula: y = log10(x * 100 + 1) / log10(101)
        // This is an extremely aggressive logarithmic curve. 
        // 18% middle gray is pushed all the way to 64% IRE, reserving the bottom 64% 
        // of the 10-bit code values entirely for shadow retention and noise floor micro-details.
        float[] curve = new float[] {{
            {points_str}
        }};
        return new TonemapCurve(curve, curve, curve);
    }}'''

pattern = r'private TonemapCurve createZirconLogCurve\(\)\s*\{.*?\n    \}'
content = re.sub(pattern, new_zircon, content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

