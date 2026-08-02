import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's add the shadow and highlight control fields
if 'private float shadowLift = 0.0f;' not in content:
    content = content.replace('private String requestedFilmStyle = "Standard";', 'private String requestedFilmStyle = "Standard";\n    private float shadowLift = 0.0f;\n    private float highlightRollOff = 0.0f;')

# Update controls parsing
old_controls = '''                Object filmStyleObj = values.get("filmStyle");
                if (filmStyleObj != null) requestedFilmStyle = String.valueOf(filmStyleObj);'''
new_controls = '''                Object filmStyleObj = values.get("filmStyle");
                if (filmStyleObj != null) requestedFilmStyle = String.valueOf(filmStyleObj);
                shadowLift = floatValue(values.get("shadowLift"), shadowLift);
                highlightRollOff = floatValue(values.get("highlightRollOff"), highlightRollOff);'''
content = content.replace(old_controls, new_controls)

# Rewrite the createSafeRec709Curve to accept dynamic shadows and highlights
old_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        // A standard Rec.709 S-curve, but with lifted shadows to prevent crushing.
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0100f, 0.0500f, // Lift the absolute black floor slightly
            0.0500f, 0.1200f, // Keep shadows visible
            0.1000f, 0.2000f,
            0.2000f, 0.3500f,
            0.3000f, 0.4500f, // Standard mid-gray
            0.5000f, 0.6500f,
            0.7000f, 0.8200f,
            0.8500f, 0.9200f,
            1.0000f, 1.0000f
        };
        return new TonemapCurve(curve, curve, curve);
    }'''

new_rec709 = '''    private TonemapCurve createSafeRec709Curve() {
        // Dynamic Rec.709 curve altered by Shadow and Highlight UI sliders.
        // shadowLift ranges from -0.1 (crushed) to +0.2 (lifted/washed out)
        // highlightRollOff ranges from -0.2 (darker peaks) to +0.0 (normal)
        
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

content = content.replace(old_rec709, new_rec709)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
