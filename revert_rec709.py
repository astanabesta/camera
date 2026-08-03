import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Revert to the 2% lifted shadow Rec.709 version.
# Let's find the current createSafeRec709Curve and replace it.

old_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        float baseShadow = 0.0500f + shadowLift;
        float deepShadow = 0.1200f + (shadowLift * 0.8f);
        float midShadow = 0.2000f + (shadowLift * 0.5f);
        
        float peakHigh = 1.0000f + highlightRollOff;
        float midHigh = 0.9200f + (highlightRollOff * 0.8f);
        float lowHigh = 0.8200f + (highlightRollOff * 0.5f);

        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0100f, Math.max(0.0f, Math.min(1.0f, baseShadow)), 
            0.0500f, Math.max(0.0f, Math.min(1.0f, deepShadow)), 
            0.1000f, Math.max(0.0f, Math.min(1.0f, midShadow)),
            0.2000f, 0.3500f,
            0.3000f, 0.4500f, 
            0.5000f, 0.6500f,
            0.7000f, Math.max(0.0f, Math.min(1.0f, lowHigh)),
            0.8500f, Math.max(0.0f, Math.min(1.0f, midHigh)),
            1.0000f, Math.max(0.0f, Math.min(1.0f, peakHigh))
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

new_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        // Standard Rec.709 but with a slight 2% lift in the deep shadows 
        // to prevent hair and micro-details from crushing to pure black.
        // It remains firmly anchored at 0.0 to maintain pure contrast.
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0200f, 0.0400f, // 2% lift strictly in the deep shadows
            0.0500f, 0.0600f,
            0.1000f, 0.1200f,
            0.2000f, 0.2400f,
            0.3000f, 0.3600f, 
            0.5000f, 0.5800f,
            0.7000f, 0.7800f,
            0.8500f, 0.9000f,
            1.0000f, 1.0000f
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

content = content.replace(old_rec709, new_rec709)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
