import re

with open('lib/src/screens/camera_screen.dart', 'r') as f:
    content = f.read()

old_switch = '''  String get _format => switch (controller.recordingMode) {
    RecordingMode.uhd30 => 'UHD 16:9',
    RecordingMode.fhd30 => 'FHD 16:9',
    RecordingMode.fourThree30 => '1440p 4:3',
  };'''

new_switch = '''  String get _format => switch (controller.recordingMode) {
    RecordingMode.openGate => 'OPEN GATE',
    RecordingMode.uhd30 => 'UHD 16:9',
    RecordingMode.fhd30 => 'FHD 16:9',
    RecordingMode.fourThree30 => '1440p 4:3',
  };'''

content = content.replace(old_switch, new_switch)

with open('lib/src/screens/camera_screen.dart', 'w') as f:
    f.write(content)
