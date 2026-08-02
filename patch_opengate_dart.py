import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

old_enum = '''enum RecordingMode {
  uhd30('4K', 3840, 2160, 30, 'UHD'),
  fhd30('1080p', 1920, 1080, 30, 'FHD'),
  fourThree30('4:3 1440p', 1920, 1440, 30, '4:3 1440p');'''

new_enum = '''enum RecordingMode {
  openGate('Open Gate (Full Sensor)', 4080, 3060, 30, 'OPEN GATE'),
  uhd30('4K', 3840, 2160, 30, 'UHD'),
  fhd30('1080p', 1920, 1080, 30, 'FHD'),
  fourThree30('4:3 1440p', 1920, 1440, 30, '4:3 1440p');'''

content = content.replace(old_enum, new_enum)

# We need to make sure the openGate mode triggers a 4:3 preview overlay guide automatically or just let the user decide.
# Actually, the user can just use the GuideRatio dropdown.

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
