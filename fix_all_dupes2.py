import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

content = content.replace('private TonemapCurve createCinematicCurve() {\n        float[] r = new float[] { 0.0f,0.0f, 0.05f,0.04f, 0.1f,0.09f, 0.2f,0.19f, 0.3f,0.30f, 0.5f,0.52f, 0.7f,0.74f, 0.85f,0.88f, 1.0f,1.0f };\n        float[] g = new float[] { 0.0f,0.0f, 0.05f,0.05f, 0.1f,0.11f, 0.2f,0.21f, 0.3f,0.32f, 0.5f,0.51f, 0.7f,0.72f, 0.85f,0.86f, 1.0f,1.0f };\n        float[] b = new float[] { 0.0f,0.02f, 0.05f,0.08f, 0.1f,0.14f, 0.2f,0.24f, 0.3f,0.34f, 0.5f,0.50f, 0.7f,0.68f, 0.85f,0.82f, 1.0f,0.95f };\n        return new TonemapCurve(r, g, b);\n    }', '', 1)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
