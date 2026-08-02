import re

with open('lib/src/screens/camera_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("RecordingMode.openGate => 'OPEN GATE',\n    ", "")

with open('lib/src/screens/camera_screen.dart', 'w') as f:
    f.write(content)
