import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_fuji = '''    private TonemapCurve createFujiCurve() {
        // Classic Film: Faded blacks, slightly green/magenta shifts, vintage highlights
        float[] r = new float[] { 0.0f,0.01f, 0.05f,0.06f, 0.1f,0.13f, 0.2f,0.23f, 0.3f,0.33f, 0.5f,0.52f, 0.7f,0.71f, 0.85f,0.85f, 1.0f,0.98f };
        float[] g = new float[] { 0.0f,0.01f, 0.05f,0.07f, 0.1f,0.15f, 0.2f,0.25f, 0.3f,0.35f, 0.5f,0.54f, 0.7f,0.73f, 0.85f,0.86f, 1.0f,0.98f };
        float[] b = new float[] { 0.0f,0.01f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.20f, 0.3f,0.30f, 0.5f,0.48f, 0.7f,0.68f, 0.85f,0.83f, 1.0f,0.96f };
        return new TonemapCurve(r, g, b);
    }'''

new_fuji = '''    private TonemapCurve createFujiCurve() {
        // Classic Chrome / Fuji Aesthetic emulation:
        // 1. Noticeably faded, lifted blacks (grayish shadows).
        // 2. High contrast in the midtones to give that "hard" analog film look.
        // 3. Very specific color separation:
        //    - Red is pulled back in the shadows to prevent ruddy skin.
        //    - Green is pushed slightly across the board for that classic Fujifilm film-stock tint.
        //    - Blue is lifted heavily in the shadows (faded blue film base) but rolled off early.
        // 4. Highlights are compressed very softly, imitating analog film roll-off.
        
        float[] r = new float[] { 0.0f,0.03f, 0.05f,0.05f, 0.1f,0.10f, 0.2f,0.20f, 0.3f,0.31f, 0.5f,0.53f, 0.7f,0.73f, 0.85f,0.86f, 0.95f,0.93f, 1.0f,0.96f };
        float[] g = new float[] { 0.0f,0.03f, 0.05f,0.07f, 0.1f,0.13f, 0.2f,0.25f, 0.3f,0.36f, 0.5f,0.56f, 0.7f,0.75f, 0.85f,0.88f, 0.95f,0.94f, 1.0f,0.97f };
        float[] b = new float[] { 0.0f,0.06f, 0.05f,0.09f, 0.1f,0.12f, 0.2f,0.19f, 0.3f,0.29f, 0.5f,0.50f, 0.7f,0.70f, 0.85f,0.84f, 0.95f,0.91f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }'''

content = content.replace(old_fuji, new_fuji)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
