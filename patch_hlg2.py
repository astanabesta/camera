import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's revert and do a clean replace
with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    pass

import os
os.system("git checkout android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java")
