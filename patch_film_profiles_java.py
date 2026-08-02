import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# 1. Add requestedFilmStyle
if 'private String requestedFilmStyle =' not in content:
    content = content.replace('private boolean requestedHlgProfile = false;', 'private boolean requestedHlgProfile = false;\n    private String requestedFilmStyle = "Standard";')

# 2. Update updateControls
old_controls = 'requestedHlgProfile = booleanValue(values.get("hlgProfile"), requestedHlgProfile);'
new_controls = 'requestedHlgProfile = booleanValue(values.get("hlgProfile"), requestedHlgProfile);\n                Object filmStyleObj = values.get("filmStyle");\n                if (filmStyleObj != null) requestedFilmStyle = String.valueOf(filmStyleObj);'
content = content.replace(old_controls, new_controls)

# 3. Inject new Tonemap curves
new_curves = '''
    private TonemapCurve createCinematicCurve() {
        // Teal & Orange: Blue shadows, warm highlights
        float[] r = new float[] { 0.0f,0.0f, 0.05f,0.04f, 0.1f,0.09f, 0.2f,0.19f, 0.3f,0.30f, 0.5f,0.52f, 0.7f,0.74f, 0.85f,0.88f, 1.0f,1.0f };
        float[] g = new float[] { 0.0f,0.0f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.51f, 0.7f,0.72f, 0.85f,0.86f, 1.0f,1.0f };
        float[] b = new float[] { 0.0f,0.02f, 0.05f,0.08f, 0.1f,0.14f, 0.2f,0.24f, 0.3f,0.34f, 0.5f,0.50f, 0.7f,0.68f, 0.85f,0.82f, 1.0f,0.95f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createFujiCurve() {
        // Classic Film: Faded blacks, slightly green/magenta shifts, vintage highlights
        float[] r = new float[] { 0.0f,0.01f, 0.05f,0.06f, 0.1f,0.13f, 0.2f,0.23f, 0.3f,0.33f, 0.5f,0.52f, 0.7f,0.71f, 0.85f,0.85f, 1.0f,0.98f };
        float[] g = new float[] { 0.0f,0.01f, 0.05f,0.07f, 0.1f,0.15f, 0.2f,0.25f, 0.3f,0.35f, 0.5f,0.54f, 0.7f,0.73f, 0.85f,0.86f, 1.0f,0.98f };
        float[] b = new float[] { 0.0f,0.01f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.20f, 0.3f,0.30f, 0.5f,0.48f, 0.7f,0.68f, 0.85f,0.83f, 1.0f,0.96f };
        return new TonemapCurve(r, g, b);
    }

    private TonemapCurve createVividCurve() {
        // Apple Vivid: High contrast, deep blacks, punchy highlights
        float[] rgb = new float[] { 0.0f,0.0f, 0.05f,0.03f, 0.1f,0.08f, 0.2f,0.18f, 0.3f,0.28f, 0.5f,0.55f, 0.7f,0.78f, 0.85f,0.92f, 1.0f,1.0f };
        return new TonemapCurve(rgb, rgb, rgb);
    }
'''

content = content.replace('    private TonemapCurve createSafeRec709Curve() {', new_curves + '\n    private TonemapCurve createSafeRec709Curve() {')

# 4. Apply the curves in applyControls
old_apply = '''        } else {
            // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
        }'''

new_apply = '''        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            switch (requestedFilmStyle) {
                case "Cinematic":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createCinematicCurve());
                    break;
                case "Fuji":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createFujiCurve());
                    break;
                case "Vivid":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createVividCurve());
                    break;
                default:
                    // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;
            }
        }'''

content = content.replace(old_apply, new_apply)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

