import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

old_curve_pattern = r'float\[\] curve = new float\[\] \{.*?\};'

new_curve = '''float[] curve = new float[] {
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

content = re.sub(old_curve_pattern, new_curve, content, flags=re.DOTALL)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
