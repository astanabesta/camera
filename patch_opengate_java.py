import re

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'r') as f:
    content = f.read()

# Add 4:3 Open Gate support (4000x3000 or similar full sensor readout)
# The Xiaomi 200MP sensor usually bins down to 12.5MP natively, which is 4080x3060.
# We will add support for width==4080 && height==3060

old_config = '''        boolean supportedSize =
                (width == 3840 && height == 2160) ||
                (width == 1920 && height == 1080) ||
                (width == 1920 && height == 1440);'''

new_config = '''        boolean supportedSize =
                (width == 4080 && height == 3060) || // OPEN GATE 4:3 Full Sensor
                (width == 3840 && height == 2160) || // 16:9 UHD
                (width == 1920 && height == 1080) || // 16:9 FHD
                (width == 1920 && height == 1440);   // 4:3 FHD'''

content = content.replace(old_config, new_config)

with open('android/app/src/main/java/ai/arena/zirconcinema/ui/CameraEngine.java', 'w') as f:
    f.write(content)
