import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_vivid = '''    private TonemapCurve createVividCurve() {
        // Apple Vivid: High contrast, deep blacks, punchy highlights
        float[] rgb = new float[] { 0.0f,0.0f, 0.05f,0.03f, 0.1f,0.08f, 0.2f,0.18f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.92f, 1.0f,1.0f };
        return new TonemapCurve(rgb, rgb, rgb);
    }'''

new_vivid = '''    private TonemapCurve createVividCurve() {
        // iPhone Vivid Aesthetic (Smart HDR / Deep Fusion emulation):
        // 1. Deep, rich blacks without completely crushing micro-details.
        // 2. Aggressive midtone contrast for that famous Apple "pop".
        // 3. Warm skin tones (Red/Green pushed slightly above Blue in mids).
        // 4. Vibrant blue skies (Blue pushed slightly higher in the upper highlights).
        // 5. Extreme highlight retention (smooth roll-off at the top).
        
        float[] r = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.08f, 0.2f,0.18f, 0.3f,0.32f, 0.5f,0.58f, 0.7f,0.80f, 0.85f,0.91f, 0.95f,0.96f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.00f, 0.05f,0.02f, 0.1f,0.07f, 0.2f,0.17f, 0.3f,0.30f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.90f, 0.95f,0.95f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.00f, 0.05f,0.03f, 0.1f,0.07f, 0.2f,0.15f, 0.3f,0.27f, 0.5f,0.52f, 0.7f,0.76f, 0.85f,0.93f, 0.95f,0.97f, 1.0f,1.0f };
        return new TonemapCurve(r, g, b);
    }'''

content = content.replace(old_vivid, new_vivid)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
