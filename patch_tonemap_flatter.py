import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# We need to find the Tonemap curve and replace it with a truly flat version
old_curve = '''        float[] curve = new float[] {
            0.0000f, 0.0500f, // Lift blacks slightly to preserve noise floor
            0.0500f, 0.1500f, // Boost deep shadows
            0.1000f, 0.2500f, // Boost shadows
            0.2000f, 0.3500f,
            0.3000f, 0.4500f, // Midtones raised
            0.5000f, 0.6000f,
            0.7000f, 0.7000f, // Highlight compression starts
            0.8500f, 0.7800f, // Knee rolls off smoothly
            0.9500f, 0.8500f,
            1.0000f, 0.9000f  // Drop peak white to prevent hard clipping
        };'''

# Creating a much flatter, closer to S-Log curve
new_curve = '''        // Aggressively flat pseudo-log curve to maximize dynamic range
        float[] curve = new float[] {
            0.0000f, 0.1200f, // Strongly lift blacks
            0.0500f, 0.2200f, // Very bright shadows
            0.1000f, 0.3000f, 
            0.2000f, 0.4200f, // Mid-gray sits higher
            0.3000f, 0.5000f, 
            0.4000f, 0.5800f,
            0.5000f, 0.6400f,
            0.6000f, 0.7000f, // Extreme highlight compression starts early
            0.8000f, 0.8000f,
            1.0000f, 0.8500f  // Clip peak white heavily
        };'''

content = content.replace(old_curve, new_curve)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
