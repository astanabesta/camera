import re

with open('lib/src/model/camera_ui_controller.dart', 'r') as f:
    content = f.read()

# Modify Enum
old_enum = '''enum RecordBitDepth {
  eightBit('8-bit SDR', 8),
  tenBit('10-bit SDR', 10);'''
new_enum = '''enum RecordBitDepth {
  eightBit('8-bit SDR', 8),
  tenBit('10-bit SDR', 10),
  hlg10('10-bit HLG (HDR)', 10);'''
content = content.replace(old_enum, new_enum)

# Add JSON mapping for native controls
old_json = "'recordBitDepth': _recordBitDepth.depth,"
new_json = "'recordBitDepth': _recordBitDepth.depth,\n        'hlgProfile': _recordBitDepth == RecordBitDepth.hlg10,"
content = content.replace(old_json, new_json)

with open('lib/src/model/camera_ui_controller.dart', 'w') as f:
    f.write(content)
