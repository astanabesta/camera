import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

def remove_second_occurrence(pattern_str, text):
    matches = list(re.finditer(pattern_str, text, flags=re.DOTALL))
    if len(matches) > 1:
        return text[:matches[1].start()] + text[matches[1].end():]
    return text

content = remove_second_occurrence(r'private TonemapCurve createFujiCurve\(\).*?return new TonemapCurve\(r, g, b\);\n    \}', content)
content = remove_second_occurrence(r'private TonemapCurve createVividCurve\(\).*?return new TonemapCurve\(.*?;\n    \}', content)
content = remove_second_occurrence(r'private TonemapCurve createCinematicCurve\(\).*?return new TonemapCurve\(r, g, b\);\n    \}', content)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
