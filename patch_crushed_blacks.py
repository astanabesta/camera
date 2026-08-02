import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's adjust the Zircon Log curve to lift shadows much, much higher
old_curve = '''        // Aggressively flat pseudo-log curve to maximize dynamic range
        float[] curve = new float[] {
            0.0000f, 0.0000f, // MUST anchor at 0.0 to prevent black level corruption
            0.0200f, 0.1000f, // Quickly lift the deepest shadows
            0.0500f, 0.2000f, // Lift shadows
            0.1000f, 0.3200f, 
            0.2000f, 0.4800f, // Mid-gray sits much higher
            0.3000f, 0.5800f, 
            0.4000f, 0.6600f,
            0.6000f, 0.8000f, // Long, smooth shoulder for highlight roll-off
            0.8000f, 0.9200f,
            1.0000f, 1.0000f  // MUST anchor at 1.0 to prevent highlight solarization/artifacts
        };'''

new_curve = '''        // Aggressively flat pseudo-log curve to maximize dynamic range
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
        };'''

content = content.replace(old_curve, new_curve)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
