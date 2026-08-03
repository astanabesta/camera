import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Revert to the original washed out Rec.709 version that was specifically asked for previously (the 0.1500f lift one)
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

# Wait, the user specifically states: "did i tell u to fix the rec709, stay the rec709 how it was"
# They want the Rec.709 exactly as it was originally BEFORE I started messing with it.
# The original, pure untouched Rec.709 is simply letting the ISP do its job: TONEMAP_MODE_HIGH_QUALITY

new_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        // Return null to let the camera hardware use its native, untouched Rec.709 High Quality mode
        return null;
    }'''

content = content.replace(old_rec709, new_rec709)

old_apply = '''                default:
                    builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
                    break;'''
                    
new_apply = '''                default:
                    builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY);
                    break;'''
                    
content = content.replace(old_apply, new_apply)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
