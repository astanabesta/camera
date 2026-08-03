import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Replace Environment.getExternalStoragePublicDirectory (which throws security exceptions on Android 10+)
# with activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) which requires zero extra permissions.

old_dir = 'java.io.File dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);'
new_dir = 'java.io.File dir = activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);'

content = content.replace(old_dir, new_dir)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)

