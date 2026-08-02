import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Let's search for how the camera sizes are queried and set.
pattern = r'StreamConfigurationMap streams = characteristics\.get\(.*?SCALER_STREAM_CONFIGURATION_MAP\);'
matches = re.findall(pattern, content)
print("Found StreamConfigurationMap:", len(matches))

# Actually, the requested sizes are hardcoded:
# private static final int DEFAULT_RECORD_WIDTH = 3840;
# private static final int DEFAULT_RECORD_HEIGHT = 2160;

