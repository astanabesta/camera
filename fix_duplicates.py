import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# We need to find and remove the duplicate definitions of createFujiCurve and createVividCurve.
# Let's use a simple approach: find the first block of these methods and keep the properly formatted ones.
# Actually, the safest way is to find the duplicate block and delete it.

fuji_pattern = r'private TonemapCurve createFujiCurve\(\).*?return new TonemapCurve\(r, g, b\);\n    \}'
fuji_matches = list(re.finditer(fuji_pattern, content, flags=re.DOTALL))

if len(fuji_matches) > 1:
    # Remove the second match
    content = content[:fuji_matches[1].start()] + content[fuji_matches[1].end():]

vivid_pattern = r'private TonemapCurve createVividCurve\(\).*?return new TonemapCurve\(.*?;\n    \}'
vivid_matches = list(re.finditer(vivid_pattern, content, flags=re.DOTALL))

if len(vivid_matches) > 1:
    # Remove the second match
    content = content[:vivid_matches[1].start()] + content[vivid_matches[1].end():]

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
