import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The crazy glowing glitch in the image is caused by the ISP mathematically breaking down
# when asked to apply a Tonemap curve that has an extreme vertical jump at the end (from 0.64 to 1.0).
# The only way to fix this safely on Android is to use a smoother roll-off so the spline interpolation
# doesn't glitch the colors out into cyan/green artifacts.

old_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Reverted to the original accepted S-Log3 response
        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.9000f, 0.6100f, // 90% White EXACTLY at 61% IRE
            0.9900f, 0.6400f, // Maintain the flat 64% IRE log curve as long as possible
            1.0000f, 1.0000f  // Hard clip anchor at absolute 1.0 to prevent 10-bit integer overflow/artifacts in clipped whites
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

new_slog3 = '''    private TonemapCurve createSLog3Curve() {
        // Safe S-Log3 mapping
        // We MUST smooth out the top end of the curve. The extreme jump from 0.64 to 1.0 
        // in the previous version caused the ISP's cubic spline to break, leading to extreme 
        // cyan/magenta glitching in the clipped white areas.
        float[] curve = new float[] {
            0.0000f, 0.0350f, // Black level
            0.0200f, 0.1200f, // Deep shadows
            0.0500f, 0.2200f, // Shadows
            0.1800f, 0.4100f, // 18% Middle Gray EXACTLY at 41% IRE
            0.3000f, 0.4600f, 
            0.5000f, 0.5200f, 
            0.7000f, 0.5700f,
            0.8000f, 0.6100f, // White
            0.9000f, 0.7500f, // Smooth transition
            1.0000f, 1.0000f  // Safe anchor
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

content = content.replace(old_slog3, new_slog3)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
