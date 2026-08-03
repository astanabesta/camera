import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# The problem is that the ImageReader is ONLY created when createRecordingSession() is called (which happens when you press the big red RECORD button).
# If the user presses "DUMP RAW" from the Settings menu while just previewing, p010Reader doesn't exist, so there is no image stream to intercept!
# 
# We need to make sure the P010 ImageReader is created during the PREVIEW session as well if we want to dump frames at any time,
# OR we simply instruct the user to press "DUMP RAW" while recording.

# Actually, the simplest fix is to just spawn the P010 reader during createPreviewSession so the stream is constantly running.

