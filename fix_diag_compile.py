import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The script `implement_diagnostics.py` failed to insert the `requestP010Dump` variable correctly.
# Let's cleanly inject it.

if 'private volatile boolean requestP010Dump = false;' not in content:
    # Find `private volatile boolean recording;` and insert after it.
    content = content.replace('private volatile boolean recording;', 'private volatile boolean recording;\n    private volatile boolean requestP010Dump = false;')

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

