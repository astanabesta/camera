import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        // Reverted the "washed out" look. This is a punchy, true-to-life standard Rec.709 
        // with deep blacks that don't crush artificially, but aren't gray/faded.
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0500f, 0.0300f, 
            0.1000f, 0.0900f,
            0.2000f, 0.2200f,
            0.3000f, 0.3500f, 
            0.5000f, 0.5800f,
            0.7000f, 0.7800f,
            0.8500f, 0.9000f,
            1.0000f, 1.0000f
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
