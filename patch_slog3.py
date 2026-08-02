import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's add the S-Log3 curve math based on Sony's official whitepaper.
# Sony S-Log3 maps 18% middle gray to exactly 41% IRE (0.410),
# and 90% white to 61% IRE (0.610).
# The absolute black level sits at 3.5% (0.035).

slog3_curve = '''
    private TonemapCurve createSLog3Curve() {
        // Sony S-Log3 emulation based on official Sony whitepaper math:
        // - Absolute black (0%) sits at 3.5% IRE
        // - Middle Gray (18%) sits at 41% IRE
        // - 90% White sits at 61% IRE
        // This is an extremely flat curve designed for massive dynamic range and standard S-Log3 CST workflows.
        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            1.0000f, 0.6400f  // Peak sensor white rolls off softly
        };
        return new TonemapCurve(curve, curve, curve);
    }
'''

if 'createSLog3Curve' not in content:
    content = content.replace('    private TonemapCurve createXiaomiLogCurve() {', slog3_curve + '\n    private TonemapCurve createXiaomiLogCurve() {')

# Let's add this to the FilmStyle selector instead of replacing Xiaomi Log, 
# so the user has standard Rec709, Cinematic, Fuji, Vivid, AND S-Log3.
# Wait, "Film Style" is applied when Log is OFF. 
# It would be better to add S-Log3 as an option inside the "Tone Curve" (Log) selector, 
# but Flutter SegmentedButton only has 2 options right now. Let's change FilmStyle to include S-Log3.

old_apply = '''            switch (requestedFilmStyle) {
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
            }'''

new_apply = '''            switch (requestedFilmStyle) {
                case "Cinematic":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createCinematicCurve());
                    break;
                case "Fuji":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createFujiCurve());
                    break;
                case "Vivid":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createVividCurve());
                    break;
                case "S-Log3":
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSLog3Curve());
                    break;
                default:
                    // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;
            }'''

content = content.replace(old_apply, new_apply)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

