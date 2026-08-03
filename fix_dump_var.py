import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The script clearly failed to find `private volatile boolean recording;` because
# the variable was declared as `private boolean recording;` in the file.

if 'private volatile boolean requestP010Dump = false;' not in content:
    # Inject it right at the top of the class definition to be absolutely certain
    insert_point = 'public final class CameraEngine implements SensorEventListener {'
    new_vars = 'public final class CameraEngine implements SensorEventListener {\n    private volatile boolean requestP010Dump = false;'
    content = content.replace(insert_point, new_vars)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
