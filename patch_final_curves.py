import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

new_methods = '''
    private TonemapCurve createSafeRec709Curve() {
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
    }

    private TonemapCurve createCinematicCurve() {
        // Teal & Orange: Blue shadows, warm highlights
        float[] r = new float[] { 0.0f,0.0f, 0.05f,0.04f, 0.1f,0.09f, 0.2f,0.19f, 0.3f,0.30f, 0.5f,0.52f, 0.7f,0.74f, 0.85f,0.88f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.0f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.51f, 0.7f,0.72f, 0.85f,0.86f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.02f, 0.05f,0.08f, 0.1f,0.14f, 0.2f,0.24f, 0.3f,0.34f, 0.5f,0.50f, 0.7f,0.68f, 0.85f,0.82f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createFujiCurve() {
        // True Fujifilm Classic Warm emulation using 1D curves:
        // 1. Red channel is pushed up in midtones/highlights for warm, glowing skin tones.
        // 2. Blue channel is pulled down in the mids (adding yellow/warmth) but lifted at 0.0 for faded vintage shadows.
        // 3. Overall contrast is "hard" in the middle, soft at the edges.
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.04f, 0.1f,0.12f, 0.2f,0.24f, 0.3f,0.36f, 0.5f,0.58f, 0.7f,0.78f, 0.85f,0.88f, 0.95f,0.96f, 1.0f,1.00f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.03f, 0.1f,0.09f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.52f, 0.7f,0.73f, 0.85f,0.86f, 0.95f,0.94f, 1.0f,1.00f };
        float[] b = new float[] { 0.0f,0.03f, 0.05f,0.05f, 0.1f,0.08f, 0.2f,0.17f, 0.3f,0.26f, 0.5f,0.45f, 0.7f,0.66f, 0.85f,0.81f, 0.95f,0.92f, 1.0f,0.98f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createVividCurve() {
        // iPhone Vivid: Deep, rich contrast.
        // Shadows are slightly crushed for impact, mids are pushed hard.
        // Blue channel is boosted in highlights for crisp skies.
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.06f, 0.2f,0.16f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.89f, 0.95f,0.96f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.06f, 0.2f,0.16f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.89f, 0.95f,0.96f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.07f, 0.2f,0.18f, 0.3f,0.30f, 0.5f,0.58f, 0.7f,0.82f, 0.85f,0.92f, 0.95f,0.97f, 1.0f,1.0f };
        return new TonemapCurve(r, g, b);
    }
'''

# Find everything from createSafeRec709Curve to the end of createVividCurve and replace it
pattern = r'private TonemapCurve createSafeRec709Curve\(\).*?return new TonemapCurve\(r, g, b\);\n    \}'
content = re.sub(pattern, new_methods.strip(), content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
