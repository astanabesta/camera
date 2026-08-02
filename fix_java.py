import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

methods_to_add = '''
    private TonemapCurve createSafeRec709Curve() {
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
    }

    private TonemapCurve createCinematicCurve() {
        float[] r = new float[] { 0.0f,0.0f, 0.05f,0.04f, 0.1f,0.09f, 0.2f,0.19f, 0.3f,0.30f, 0.5f,0.52f, 0.7f,0.74f, 0.85f,0.88f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.0f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.51f, 0.7f,0.72f, 0.85f,0.86f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.02f, 0.05f,0.08f, 0.1f,0.14f, 0.2f,0.24f, 0.3f,0.34f, 0.5f,0.50f, 0.7f,0.68f, 0.85f,0.82f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createFujiCurve() {
        float[] r = new float[] { 0.0f,0.03f, 0.05f,0.05f, 0.1f,0.10f, 0.2f,0.20f, 0.3f,0.31f, 0.5f,0.53f, 0.7f,0.73f, 0.85f,0.86f, 0.95f,0.93f, 1.0f,0.96f };
        float[] g = new float[] { 0.0f,0.03f, 0.05f,0.07f, 0.1f,0.13f, 0.2f,0.25f, 0.3f,0.36f, 0.5f,0.56f, 0.7f,0.75f, 0.85f,0.88f, 0.95f,0.94f, 1.0f,0.97f };
        float[] b = new float[] { 0.0f,0.06f, 0.05f,0.09f, 0.1f,0.12f, 0.2f,0.19f, 0.3f,0.29f, 0.5f,0.50f, 0.7f,0.70f, 0.85f,0.84f, 0.95f,0.91f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createVividCurve() {
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.08f, 0.2f,0.18f, 0.3f,0.32f, 0.5f,0.58f, 0.7f,0.80f, 0.85f,0.91f, 0.95f,0.96f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.07f, 0.2f,0.17f, 0.3f,0.30f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.90f, 0.95f,0.95f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.00f, 0.05f,0.03f, 0.1f,0.07f, 0.2f,0.15f, 0.3f,0.27f, 0.5f,0.52f, 0.7f,0.76f, 0.85f,0.93f, 0.95f,0.97f, 1.0f,1.0f };
        return new TonemapCurve(r, g, b);
    }
'''

# Make sure we don't accidentally add it twice
if 'createCinematicCurve()' not in content or 'private TonemapCurve createCinematicCurve()' not in content:
    # Append the methods right before the final brace of the class
    content = content.rsplit('}', 1)[0] + methods_to_add + '\n}'

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
