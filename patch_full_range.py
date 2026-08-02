import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# For MediaRecorder, we have to use setVideoEncodingProfileLevel. We can't directly set full range in Java MediaRecorder API without reflection,
# but we can try to force the Camera2 capture intent to ensure shadows aren't crushed on the sensor side, 
# or we can write a small fix to the tonemap curve lifting the bottom end even more.

# Wait, if shadows are crushed in gallery viewer too, it means the video is actually being encoded with crushed blacks, likely because the default MediaRecorder behavior for HEVC is limited range.

