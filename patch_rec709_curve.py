import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# When the user is NOT using Log, let's inject a custom "Rec709-Safe" tonemap
# that mimics standard contrast but forces the shadows to stay lifted so they don't crush.

tonemap_method = '''
    private TonemapCurve createLogTonemapCurve() {
        // Aggressively flat pseudo-log curve to maximize dynamic range
        float[] curve = new float[] {
            0.0000f, 0.0000f, // MUST anchor at 0.0 to prevent black level corruption
            0.0100f, 0.1500f, // Extreme lift on the absolute black floor
            0.0200f, 0.2200f, 
            0.0500f, 0.3200f, // Push shadows out of the crushed zone
            0.1000f, 0.4200f, 
            0.2000f, 0.5200f, // Mid-gray sits much higher
            0.3000f, 0.6000f, 
            0.4000f, 0.6800f,
            0.6000f, 0.8200f, // Long, smooth shoulder for highlight roll-off
            0.8000f, 0.9400f,
            1.0000f, 1.0000f  // MUST anchor at 1.0 to prevent highlight solarization/artifacts
        };
        return new TonemapCurve(curve, curve, curve);
    }
'''

new_tonemap_methods = '''
    private TonemapCurve createLogTonemapCurve() {
        float[] curve = new float[] {
            0.0000f, 0.0000f,
            0.0100f, 0.1500f,
            0.0200f, 0.2200f, 
            0.0500f, 0.3200f,
            0.1000f, 0.4200f, 
            0.2000f, 0.5200f,
            0.3000f, 0.6000f, 
            0.4000f, 0.6800f,
            0.6000f, 0.8200f,
            0.8000f, 0.9400f,
            1.0000f, 1.0000f
        };
        return new TonemapCurve(curve, curve, curve);
    }

    private TonemapCurve createSafeRec709Curve() {
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
    }
'''

content = content.replace(tonemap_method, new_tonemap_methods)

old_apply = '''        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createLogTonemapCurve());
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY);
        }'''

new_apply = '''        } else if (requestedLogProfile) {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createLogTonemapCurve());
        } else {
            // Apply a "Safe" Rec.709 curve that prevents shadows from crushing in 10-bit SDR
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE);
            builder.set(CaptureRequest.TONEMAP_CURVE, createSafeRec709Curve());
        }'''

content = content.replace(old_apply, new_apply)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
